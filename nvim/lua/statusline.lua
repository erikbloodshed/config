-- Optimized statusline for Neovim
--[[
Optimized statusline for Neovim with:
- Extreme performance focus with lazy loading
- Deferred initialization pattern
- Mode-based color changes
- Efficient diagnostic and LSP status displays
- Minimal memory footprint and CPU usage
- Stable timer usage
- Support for empty statusline when inactive
]]

local api = vim.api
local lsp = vim.lsp
local cmd = vim.cmd

-- Module with metatable for deferred initialization
local M = {}
local mt = {
    __index = function(_, key)
        -- Initialize on demand
        if key ~= "initialized" and not M.initialized then
            M.setup()
        end
        return rawget(M, key)
    end
}
setmetatable(M, mt)

M.initialized = false

-- Pre-define mode highlight groups
M.mode_highlights = {
    n = "StatusLineNormal",
    i = "StatusLineInsert",
    v = "StatusLineVisual",
    V = "StatusLineVisual",
    [""] = "StatusLineVisual",
    c = "StatusLineCommand",
    s = "StatusLineSelect",
    S = "StatusLineSelect",
    R = "StatusLineReplace",
    r = "StatusLineReplace",
    ["!"] = "StatusLineTerminal",
    t = "StatusLineTerminal",
}

M.highlight_groups = {
    "%#DiagnosticError#",
    "%#DiagnosticWarn#",
    "%#DiagnosticInfo#",
    "%#DiagnosticHint#"
}
M.severity_labels = { "E:", "W:", "I:", "H:" }

-- Return empty string from _G.statusline until initialized.  This is more robust.
_G.statusline = function()
    return ""
end

M.empty_filetypes = {
    ["neo-tree"] = true,
}

function M.define_mode_highlights()
    cmd("hi StatusLineNormal guibg=#2E3440 guifg=#8FBCBB gui=bold")
    cmd("hi StatusLineInsert guibg=#A3BE8C guifg=#2E3440 gui=bold")
    cmd("hi StatusLineVisual guibg=#B48EAD guifg=#2E3440 gui=bold")
    cmd("hi StatusLineCommand guibg=#EBCB8B guifg=#2E3440 gui=bold")
    cmd("hi StatusLineReplace guibg=#BF616A guifg=#2E3440 gui=bold")
    cmd("hi StatusLineTerminal guibg=#81A1C1 guifg=#2E3440 gui=bold")
    cmd("hi StatusLineSelect guibg=#D08770 guifg=#2E3440 gui=bold")
    cmd("hi StatusLineDefault guibg=#434C5E guifg=#E5E9F0 gui=bold")
end

function M.get_mode_highlight()
    local mode = api.nvim_get_mode().mode
    return "%#" .. (M.mode_highlights[mode] or "StatusLineDefault") .. "#"
end

function M.setup()
    if M.initialized then return end

    M.cache = {
        lsp = { result = "", last_updated = 0 },
        diagnostics = { result = "", last_updated = 0 },
        bufnr = nil,
        diagnostic_count = 0,
        lsp_client_count = 0,
        mode = "",
        mode_highlight = ""
    }

    M.components = {}
    M.diag_timer = nil
    M.bufchange_timer = nil
    M.is_active = true -- Add a flag to track activity

    _G.statusline = function()
        return M.statusline()
    end

    vim.o.statusline = "%{%v:lua._G.statusline()%}"
    M.register_events()
    M.define_mode_highlights()
    M.initialized = true
end

function M.register_events()
    local augroup = api.nvim_create_augroup("StatusLineRefresh", { clear = true })

    api.nvim_create_autocmd("ColorScheme", {
        group = augroup,
        callback = function()
            M.define_mode_highlights()
            cmd("redrawstatus")
        end,
    })

    -- Refactored DiagnosticChanged
    api.nvim_create_autocmd("DiagnosticChanged", {
        group = augroup,
        callback = function()
            if M.diag_timer then
                vim.uv.timer_stop(M.diag_timer)
                vim.uv.close(M.diag_timer)
                M.diag_timer = nil
            end
            M.diag_timer = vim.uv.new_timer()
            vim.uv.timer_start(M.diag_timer, 50, 0, function()
                vim.schedule(function()
                    M.cache.diagnostics = { result = "", last_updated = 0 }
                    cmd("redrawstatus")
                    if M.diag_timer then
                        vim.uv.timer_stop(M.diag_timer)
                        vim.uv.close(M.diag_timer)
                        M.diag_timer = nil
                    end
                end)
            end)
        end,
    })

    -- Refactored BufEnter
    api.nvim_create_autocmd({ "BufEnter" }, {
        group = augroup,
        callback = function()
            if M.bufchange_timer then
                vim.uv.timer_stop(M.bufchange_timer)
                vim.uv.close(M.bufchange_timer)
                M.bufchange_timer = nil;
            end
            M.bufchange_timer = vim.uv.new_timer()
            vim.uv.timer_start(M.bufchange_timer, 30, 0, function()
                vim.schedule(function()
                    M.cache.lsp = { result = "", last_updated = 0 }
                    M.cache.diagnostics = { result = "", last_updated = 0 }
                    M.cache.bufnr = nil
                    M.cache.diagnostic_count = 0
                    M.cache.lsp_client_count = 0
                    cmd("redrawstatus")
                    if M.bufchange_timer then
                        vim.uv.timer_stop(M.bufchange_timer)
                        vim.uv.close(M.bufchange_timer)
                        M.bufchange_timer = nil
                    end
                end)
            end)
        end
    })

    api.nvim_create_autocmd({ "LspAttach", "LspDetach" }, {
        group = augroup,
        callback = function()
            M.cache.lsp = { result = "", last_updated = 0 }
            cmd("redrawstatus")
        end,
    })

    api.nvim_create_autocmd("ModeChanged", {
        group = augroup,
        callback = function()
            cmd("redrawstatus")
        end,
    })

    -- Add WinLeave and WinEnter events to track window activity
    api.nvim_create_autocmd("WinLeave", {
        group = augroup,
        callback = function()
            M.is_active = false
            cmd("redrawstatus") -- Redraw to clear statusline
        end,
    })

    api.nvim_create_autocmd("WinEnter", {
        group = augroup,
        callback = function()
            M.is_active = true
            cmd("redrawstatus") -- Redraw to show statusline
        end,
    })
end

function M.lsp_status()
    if not M.cache then return "" end

    local bufnr = api.nvim_get_current_buf()
    local clients = lsp.get_clients({ bufnr = bufnr })
    local client_count = #clients

    if client_count == 0 then
        M.cache.lsp.result = ""
        M.cache.lsp.last_updated = vim.uv.now()
        M.cache.lsp_client_count = 0
        return ""
    end

    if M.cache.bufnr == bufnr and
        M.cache.lsp_client_count == client_count and
        M.cache.lsp.result ~= "" and
        (vim.uv.now() - M.cache.lsp.last_updated) < 5000 then
        return M.cache.lsp.result
    end

    M.cache.bufnr = bufnr
    M.cache.lsp_client_count = client_count

    local names = {}
    local name_replacements = {
        ["%-language%-server"] = "-ls",
        ["language_server"] = "ls"
    }

    for _, client in ipairs(clients) do
        local name = client.name
        for pattern, replacement in pairs(name_replacements) do
            name = name:gsub(pattern, replacement)
        end
        names[#names + 1] = name
    end

    M.cache.lsp.result = " " .. table.concat(names, ", ")
    M.cache.lsp.last_updated = vim.uv.now()

    return M.cache.lsp.result
end

function M.get_diagnostic_counts()
    if not M.cache then return "" end

    local bufnr = api.nvim_get_current_buf()
    local diagnostics = vim.diagnostic.get(bufnr)
    local diag_count = #diagnostics

    if diag_count == 0 then
        M.cache.diagnostics.result = ""
        M.cache.diagnostics.last_updated = vim.uv.now()
        M.cache.diagnostic_count = 0
        return ""
    end

    if M.cache.bufnr == bufnr and
        M.cache.diagnostic_count == diag_count and
        M.cache.diagnostics.result ~= "" and
        (vim.uv.now() - M.cache.diagnostics.last_updated) < 2000 then
        return M.cache.diagnostics.result
    end

    M.cache.bufnr = bufnr
    M.cache.diagnostic_count = diag_count

    local counts = { 0, 0, 0, 0 }
    for _, diag in ipairs(diagnostics) do
        local severity = diag.severity
        if severity and severity >= 1 and severity <= 4 then
            counts[severity] = counts[severity] + 1
        end
    end

    local result = {}
    for i = 1, 4 do
        if counts[i] > 0 then
            result[#result + 1] = M.highlight_groups[i] .. M.severity_labels[i] .. counts[i] .. "%*"
        end
    end

    if #result > 0 then
        M.cache.diagnostics.result = table.concat(result, " ")
    else
        M.cache.diagnostics.result = ""
    end
    M.cache.diagnostics.last_updated = vim.uv.now()

    return M.cache.diagnostics.result
end

function M.get_mode_display()
    local mode_map = {
        ['n'] = 'NORMAL',
        ['i'] = 'INSERT',
        ['v'] = 'VISUAL',
        ['V'] = 'V-LINE',
        [''] = 'V-BLOCK',
        ['c'] = 'COMMAND',
        ['s'] = 'SELECT',
        ['S'] = 'S-LINE',
        ['R'] = 'REPLACE',
        ['r'] = 'REPLACE',
        ['!'] = 'TERMINAL',
        ['t'] = 'TERMINAL',
    }

    local mode = api.nvim_get_mode().mode
    return mode_map[mode] or mode
end

function M.statusline()
    if not M.initialized then
        return ""
    end

    -- Check if the window is active
    if not M.is_active then
        return "" -- Return empty string if window is inactive
    end

    local ft = api.nvim_get_option_value("filetype", { buf = 0 })
    if M.empty_filetypes[ft] then
        return ""
    end

    for i = 1, #M.components do
        M.components[i] = nil
    end

    local mode_hl = M.get_mode_highlight()
    M.components[1] = mode_hl .. " " .. M.get_mode_display() .. " %*"
    M.components[2] = "%t"
    M.components[3] = "%h%w%m%r"

    local diag_info = M.get_diagnostic_counts()
    if diag_info ~= "" then
        M.components[#M.components + 1] = diag_info
    end

    M.components[#M.components + 1] = "%="

    local lsp_info = M.lsp_status()
    if lsp_info ~= "" then
        M.components[#M.components + 1] = "%-10(" .. lsp_info .. "%)"
    end
    M.components[#M.components + 1] = mode_hl .. " %-12(%l:%c%) %P %*"

    return table.concat(M.components, " ")
end

api.nvim_create_autocmd("VimEnter", {
    callback = function()
        vim.defer_fn(function()
            if not M.initialized then
                M.setup()
            end
        end, 100)
    end,
    once = true,
})

vim.o.statusline = ""
return M
