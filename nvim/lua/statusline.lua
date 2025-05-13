--[[
Improved statusline with diagnostic counts and LSP client information
]]

---Show attached LSP clients in `[name1, name2]` format.
---@return string
local function lsp_status()
    local clients = vim.lsp.get_clients({ bufnr = 0 })
    if #clients == 0 then
        return ""
    end

    local names = {}
    for _, client in ipairs(clients) do
        -- Simplify common LSP server names
        local name = client.name
        name = name:gsub("%-language%-server", "-ls")
        name = name:gsub("language_server", "ls")
        table.insert(names, name)
    end

    return "[" .. table.concat(names, ", ") .. "]"
end

---Get diagnostic counts for the current buffer
---@return string
local function get_diagnostic_counts()
    -- Get all diagnostics for current buffer
    local diagnostics = vim.diagnostic.get(0)
    if not diagnostics or #diagnostics == 0 then
        return ""
    end

    -- Count by severity
    local counts = { 0, 0, 0, 0 } -- Error, Warn, Info, Hint

    for _, diagnostic in ipairs(diagnostics) do
        local severity = diagnostic.severity
        if severity then
            counts[severity] = counts[severity] + 1
        end
    end

    -- Format the output
    local result = {}
    local severity_labels = { "E:", "W:", "I:", "H:" }

    for i = 1, 4 do
        if counts[i] > 0 then
            table.insert(result, severity_labels[i] .. counts[i])
        end
    end

    if #result > 0 then
        return table.concat(result, " ")
    else
        return ""
    end
end

function _G.statusline()
    local components = {
        "%f",       -- Relative file path
        "%h%w%m%r", -- Help, preview, modified, readonly flags
    }

    -- Add diagnostics if present (before the alignment)
    local diag_info = get_diagnostic_counts()
    if diag_info ~= "" then
        table.insert(components, diag_info)
    end

    table.insert(components, "%=") -- Right align the rest

    -- Add LSP status if present
    local lsp_info = lsp_status()
    if lsp_info ~= "" then
        table.insert(components, lsp_info)
    end

    -- Position information
    table.insert(components, "%-14(%l,%c%)")
    table.insert(components, "%P")

    return table.concat(components, " ")
end

-- Set the statusline
vim.o.statusline = "%{%v:lua._G.statusline()%}"

-- Create autocmd to refresh statusline when diagnostics change
vim.api.nvim_create_autocmd({ "DiagnosticChanged" }, {
    callback = function()
        -- Force statusline refresh by triggering a redraw
        vim.cmd("redrawstatus")
    end,
})
