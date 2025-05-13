--[[
Improved statusline with diagnostic counts and LSP client information
Optimized for performance with caching
]]

-- Cache storage
local cache = {
    lsp = { result = "", last_updated = 0 },
    diagnostics = { result = "", last_updated = 0 },
    last_bufnr = nil
}

-- Tracking variables for change detection
local last_diagnostic_count = 0
local last_lsp_client_count = 0

---Show attached LSP clients in `[name1, name2]` format with caching
---@return string
local function lsp_status()
    local bufnr = vim.api.nvim_get_current_buf()
    local clients = vim.lsp.get_clients({ bufnr = bufnr })
    local client_count = #clients

    -- Return early if no clients
    if client_count == 0 then
        cache.lsp.result = ""
        cache.lsp.last_updated = vim.loop.now()
        last_lsp_client_count = 0
        return ""
    end

    -- Use cached result if buffer hasn't changed and client count is the same
    if cache.last_bufnr == bufnr and
        last_lsp_client_count == client_count and
        cache.lsp.result ~= "" and
        (vim.loop.now() - cache.lsp.last_updated) < 5000 then -- Cache for 5 seconds
        return cache.lsp.result
    end

    -- Update cache variables
    cache.last_bufnr = bufnr
    last_lsp_client_count = client_count

    -- Build client names list more efficiently
    local names = {}
    for _, client in ipairs(clients) do
        local name = client.name
        -- Use string patterns for more efficient replacements
        name = name:gsub("%-language%-server", "-ls")
        name = name:gsub("language_server", "ls")
        names[#names + 1] = name
    end

    -- Store result in cache
    cache.lsp.result = " " .. table.concat(names, ", ")
    cache.lsp.last_updated = vim.loop.now()

    return cache.lsp.result
end

local function get_diagnostic_counts()
    local bufnr = vim.api.nvim_get_current_buf()
    local diagnostics = vim.diagnostic.get(bufnr)
    local diag_count = #diagnostics

    -- Return early if no diagnostics
    if diag_count == 0 then
        cache.diagnostics.result = ""
        cache.diagnostics.last_updated = vim.loop.now()
        last_diagnostic_count = 0
        return ""
    end

    -- Use cached result if buffer hasn't changed and diagnostic count is the same
    if cache.last_bufnr == bufnr and
        last_diagnostic_count == diag_count and
        cache.diagnostics.result ~= "" and
        (vim.loop.now() - cache.diagnostics.last_updated) < 1000 then -- Cache for 1 second
        return cache.diagnostics.result
    end

    -- Update cache tracking
    cache.last_bufnr = bufnr
    last_diagnostic_count = diag_count

    -- Count by severity - preallocate with zeroes
    local counts = { 0, 0, 0, 0 } -- Error, Warn, Info, Hint

    for _, diagnostic in ipairs(diagnostics) do
        local severity = diagnostic.severity
        if severity then
            counts[severity] = counts[severity] + 1
        end
    end

    -- Format the output with highlights - use table for string building
    local result = {}
    local highlight_groups = {
        "%#DiagnosticError#",
        "%#DiagnosticWarn#",
        "%#DiagnosticInfo#",
        "%#DiagnosticHint#"
    }
    local severity_labels = { "E:", "W:", "I:", "H:" }

    for i = 1, 4 do
        if counts[i] > 0 then
            result[#result + 1] = highlight_groups[i] .. severity_labels[i] .. counts[i] .. "%*"
        end
    end

    -- Store result in cache
    if #result > 0 then
        cache.diagnostics.result = table.concat(result, " ")
    else
        cache.diagnostics.result = ""
    end
    cache.diagnostics.last_updated = vim.loop.now()

    return cache.diagnostics.result
end

-- Memoized filetype check
local empty_statusline_filetypes = {
    ["neo-tree"] = true,
}

-- Reset cache when changing buffers
local function reset_cache()
    cache.lsp = { result = "", last_updated = 0 }
    cache.diagnostics = { result = "", last_updated = 0 }
    cache.last_bufnr = nil
    last_diagnostic_count = 0
    last_lsp_client_count = 0
end

function _G.statusline()
    -- Check if current buffer should have empty statusline
    local ft = vim.api.nvim_get_option_value("filetype", { buf = 0 })
    if empty_statusline_filetypes[ft] or false then
        return ""
    end

    -- Pre-allocate components table with estimated size
    local components = { "%t", "%h%w%m%r" }

    -- Add diagnostics if present (before the alignment)
    local diag_info = get_diagnostic_counts()
    if diag_info ~= "" then
        components[#components + 1] = diag_info
    end

    components[#components + 1] = "%=" -- Right align the rest

    -- Add LSP status if present
    local lsp_info = lsp_status()
    if lsp_info ~= "" then
        components[#components + 1] = "%-10(" .. (lsp_info) .. "%)"
    end

    -- Position information - combine these to reduce concat operations
    components[#components + 1] = "%-12(%l:%c%) %P"

    return table.concat(components, " ")
end

-- Set the statusline
vim.o.statusline = "%{%v:lua._G.statusline()%}"

-- Create autocmds to update statusline when needed
local statusline_augroup = vim.api.nvim_create_augroup("StatusLineRefresh", { clear = true })

-- Refresh on diagnostic changes
vim.api.nvim_create_autocmd("DiagnosticChanged", {
    group = statusline_augroup,
    callback = function()
        -- Reset diagnostic cache
        cache.diagnostics = { result = "", last_updated = 0 }
        -- Force statusline refresh
        vim.cmd("redrawstatus")
    end,
})

-- Reset cache on buffer change
vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
    group = statusline_augroup,
    callback = reset_cache,
})

-- Reset cache when LSP attaches/detaches
vim.api.nvim_create_autocmd("LspAttach", {
    group = statusline_augroup,
    callback = function()
        cache.lsp = { result = "", last_updated = 0 }
        vim.cmd("redrawstatus")
    end,
})

vim.api.nvim_create_autocmd("LspDetach", {
    group = statusline_augroup,
    callback = function()
        cache.lsp = { result = "", last_updated = 0 }
        vim.cmd("redrawstatus")
    end,
})
