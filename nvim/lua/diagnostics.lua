-- Setup pretty quickfix formatting
-- Note: Requires the 'custom_qf' plugin or equivalent setup
require("custom_qf").setup({
    show_multiple_lines = true,
    max_filename_length = 30,
})

local diagnostic = vim.diagnostic
local severity   = diagnostic.severity
local vim_fn     = vim.fn
local keymap     = vim.keymap.set
local autocmd    = vim.api.nvim_create_autocmd
local api        = vim.api
local cmd        = vim.cmd

-- Configure Neovim's built-in diagnostics
diagnostic.config({
    virtual_text = false,           -- Disable virtual text diagnostics
    severity_sort = true,           -- Sort diagnostics by severity
    float = { border = "rounded" }, -- Set rounded border for diagnostic float window
    signs = {                       -- Define custom text signs for different severity levels
        text = {
            [severity.ERROR] = "",
            [severity.WARN] = "󱈸",
            [severity.HINT] = "",
            [severity.INFO] = "",
        },
    },
})

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

--- Closes the location list if it's open.
local function close_loclist()
    local loclist_info = vim_fn.getloclist(0, { winid = 0 })
    if loclist_info.winid ~= 0 then
        cmd("lclose")
    end
end

--- Toggles the visibility of the location list populated with diagnostics.
local function toggle_loclist()
    local loclist_info = vim_fn.getloclist(0, { winid = 0 })
    local is_open = loclist_info.winid ~= 0

    if is_open then
        close_loclist()
    else
        open_loclist()
    end
end

-- Autocommand to handle changes in diagnostics
autocmd("DiagnosticChanged", {
    callback = function(args)
        local diagnostics = args.data.diagnostics
        local loclist_info = vim_fn.getloclist(0, { winid = 0 })
        local is_loclist_open = loclist_info.winid ~= 0

        -- Close loclist if diagnostics are cleared and it's open
        if vim.tbl_isempty(diagnostics) and is_loclist_open then
            vim.schedule(function()
                cmd.lclose()
            end)
        end

        -- If loclist is open, refresh its contents when diagnostics change.
        -- Note: Populating the loclist is implicitly handled by Neovim's
        -- diagnostic system when diagnostics change in a buffer.
        -- We just need to ensure the window remains or is updated if needed.
        -- Explicitly repopulating here with `open_loclist()` when it's already
        -- open would close and reopen it, which might not be desired.
        -- The current setup with `DiagnosticChanged` triggering on changes
        -- should keep the loclist populated if it's open and configured
        -- to show buffer diagnostics. The previous `open_loclist({open=false})`
        -- likely intended a refresh mechanism that isn't standard or clear.
        -- Removing that potentially confusing call. The `jump_from_loclist`
        -- and `toggle_loclist` functions rely on `getloclist(0)` reflecting
        -- the current state, which Neovim manages.
    end,
})


-- Define keymap to toggle the diagnostics location list
keymap("n", "<leader>qq", toggle_loclist, { buffer = true, desc = "Toggle diagnostics location list" })
