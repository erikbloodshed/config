-- Setup pretty quickfix formatting
-- Note: Requires the 'custom_qf' plugin or equivalent setup
local diagnostic = vim.diagnostic
local keymap     = vim.keymap.set
local autocmd    = vim.api.nvim_create_autocmd
local cmd        = vim.cmd

local function open_loclist()
    local diagnostics_list = diagnostic.get()
    if vim.tbl_isempty(diagnostics_list) then
        vim.notify("No diagnostics in current buffer.", vim.log.levels.INFO) -- Use INFO for no diagnostics found
        return
    end

    -- Open the location list window
    diagnostic.setloclist({ open = false, title = "Diagnostics" })
    local height = math.min(math.max(#diagnostics_list, 3), 6) -- Determine optimal window height
    cmd("lopen " .. height)
end

-- Autocommand to handle changes in diagnostics
autocmd("DiagnosticChanged", {
    callback = function(args)
        local diagnostics = args.data.diagnostics

        if #diagnostics == 0 then
            vim.schedule(function()
                cmd.lclose()
            end)
        end

        diagnostic.setloclist({ open = false, title = "Diagnostics" })
    end,
})


-- Define keymap to toggle the diagnostics location list
keymap("n", "<leader>xx", open_loclist, { buffer = true, desc = "Toggle diagnostics location list" })

return {
    open_loclist = open_loclist,
}
