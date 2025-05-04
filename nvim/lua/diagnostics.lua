-- Setup pretty quickfix formatting
-- Note: Requires the 'custom_qf' plugin or equivalent setup
local diagnostic      = vim.diagnostic
local keymap          = vim.keymap.set
local api             = vim.api
local autocmd         = api.nvim_create_autocmd
local cmd             = vim.cmd

-- Cache the loclist status to avoid unnecessary operations
local loclist_is_open = false
-- Track the last buffer that opened the location list

-- Convert diagnostics to location list items using Neovim's built-in function
local function diagnostics_to_qf_items(diagnostics)
    return vim.diagnostic.toqflist(diagnostics)
end

-- Update the location list without opening it
local function update_loclist(items)
    vim.fn.setloclist(0, {}, ' ', {
        title = "Diagnostics",
        items = items
    })
end

-- Open the location list with proper sizing based on content
local function open_loclist()
    local diagnostics = diagnostic.get()
    if vim.tbl_isempty(diagnostics) then
        vim.notify("No diagnostics in current buffer.", vim.log.levels.INFO)
        return
    end

    -- Convert diagnostics to location list items
    local items = diagnostics_to_qf_items(diagnostics)

    -- Update the location list
    update_loclist(items)

    -- Determine optimal height (min 3 rows, max 10 rows)
    local height = math.min(math.max(#items, 3), 10)

    -- Open the location list window
    cmd("lopen " .. height)
    loclist_is_open = true
end

-- Handle diagnostic changes efficiently
autocmd("DiagnosticChanged", {
    callback = function(args)
        local diagnostics = args.data.diagnostics

        if #diagnostics == 0 then
            -- Only try to close if it's actually open
            if loclist_is_open then
                vim.schedule(function()
                    if #api.nvim_list_wins() > 1 then
                        cmd.lclose()
                        loclist_is_open = false
                    elseif #api.nvim_list_wins() == 1 then
                        cmd("bdelete")
                    end
                end)
            end
            return
        end

        -- Get current window ID to check if loclist is visible
        local win_id = api.nvim_get_current_win()
        local loclist_info = vim.fn.getloclist(win_id, { winid = 0 })
        loclist_is_open = loclist_info.winid ~= 0

        -- Convert diagnostics to location list items
        local items = diagnostics_to_qf_items(diagnostics)

        -- Update the location list
        update_loclist(items)
    end,
})

-- Toggle function for the diagnostics location list
local function toggle_loclist()
    -- Check if loclist is really open by querying Neovim
    local win_id = api.nvim_get_current_win()
    local loclist_info = vim.fn.getloclist(win_id, { winid = 0 })
    loclist_is_open = loclist_info.winid ~= 0

    if loclist_is_open then
        -- Check if we have more than one window before trying to close
        if #api.nvim_list_wins() > 1 then
            cmd.lclose()
            loclist_is_open = false
        else
            vim.notify("Cannot close the last window", vim.log.levels.WARN)
        end
    else
        open_loclist()
    end
end

-- Define keymap to toggle the diagnostics location list
keymap("n", "<leader>xx", toggle_loclist, { desc = "Toggle diagnostics location list" })

return {
    open_loclist = open_loclist,
    update_loclist = update_loclist,
    toggle_loclist = toggle_loclist,
}
