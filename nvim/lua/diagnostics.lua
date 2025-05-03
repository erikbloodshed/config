-- Setup pretty quickfix formatting
-- Note: Requires the 'custom_qf' plugin or equivalent setup
require("custom_qf").setup({
    show_multiple_lines = false,
    max_filename_length = 30,
})

local diagnostic = vim.diagnostic
local vim_fn     = vim.fn
local keymap     = vim.keymap.set
local autocmd    = vim.api.nvim_create_autocmd
local api        = vim.api
local cmd        = vim.cmd

--- Jumps from the current line in the location list to the corresponding diagnostic in the buffer.
--- Closes the location list after jumping.
local function jump_from_loclist()
    local idx = vim_fn.line(".")         -- Get the current line number in the location list
    local loclist = vim_fn.getloclist(0) -- Get the location list for the current window

    local item = loclist[idx]            -- Get the item at the current line
    if item and item.bufnr then
        local bufnr = item.bufnr
        local lnum = item.lnum or 1
        local col = item.col and math.max(0, item.col - 1) or 0 -- Adjust column to be 0-indexed

        cmd("lclose")                                           -- Close the location list window

        -- Use vim.schedule to ensure commands run after the current event loop
        vim.schedule(function()
            if api.nvim_buf_is_valid(bufnr) and api.nvim_buf_is_loaded(bufnr) then
                -- Clamp line number to avoid out-of-bounds errors
                local line_count = vim.api.nvim_buf_line_count(bufnr)
                local safe_line = math.max(1, math.min(lnum, line_count))

                api.nvim_set_current_buf(bufnr)                -- Switch to the buffer with the diagnostic
                api.nvim_win_set_cursor(0, { safe_line, col }) -- Move cursor to the diagnostic location
            end
        end)
    end
end

--- Opens the location list and populates it with current buffer diagnostics.
--- Sets up buffer-local keymaps for the location list window.
local function open_loclist()
    local diagnostics_list = diagnostic.get()
    if vim.tbl_isempty(diagnostics_list) then
        vim.notify("No diagnostics in current buffer.", vim.log.levels.INFO) -- Use INFO for no diagnostics found
        return
    end

    diagnostic.setloclist({ open = false, title = "Diagnostics" })
    -- Open the location list window
    local height = math.min(math.max(#diagnostics_list, 3), 10) -- Determine optimal window height
    cmd("lopen " .. height)

    -- Get info about the newly opened location list window
    local loclist_info = vim_fn.getloclist(0, { winid = 0 })

    -- Check if the location list window was successfully opened
    if loclist_info.winid ~= 0 then
        local loclist_bufnr = api.nvim_win_get_buf(loclist_info.winid)

        -- Set buffer-local keymaps for the location list buffer
        keymap("n", "<CR>", jump_from_loclist,
            { buffer = loclist_bufnr, nowait = true, desc = "Close diagnostics location list on jump" })
        keymap("n", "<Esc>", "<Cmd>lclose<CR>",
            { buffer = loclist_bufnr, nowait = true, desc = "Close diagnostics location list" })
    end
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
    jump_from_loclist = jump_from_loclist,
    open_loclist = open_loclist,
}
