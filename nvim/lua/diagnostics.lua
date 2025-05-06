-- Cache the loclist status to avoid unnecessary operations
local loclist_is_open = false

-- Update the location list without opening it
local function update_loclist(items)
    vim.fn.setloclist(0, {}, ' ', {
        title = "Diagnostics",
        items = items
    })
end

-- Automatically close location list window when leaving a buffer
vim.api.nvim_create_autocmd("BufLeave", {
    group = vim.api.nvim_create_augroup("CloseLoclistOnBufferLeave", { clear = true }),
    callback = function()
        -- Only close location list for normal buffers
        if vim.bo.buftype == "" then
            vim.cmd("lclose")
        end
    end,
    desc = "Close location list when leaving buffer"
})

-- Handle diagnostic changes efficiently
vim.api.nvim_create_autocmd("DiagnosticChanged", {
    callback = function(args)
        local diagnostics = args.data.diagnostics

        if #diagnostics == 0 then
            -- Only try to close if it's actually open
            if loclist_is_open then
                vim.schedule(function()
                    if #vim.api.nvim_list_wins() > 1 then
                        vim.cmd.lclose()
                        loclist_is_open = false
                    end
                end)
            end
        end

        -- Convert diagnostics to location list items
        local items = vim.diagnostic.toqflist(diagnostics)

        -- Update the location list
        update_loclist(items)
    end,
})

M = {
    -- Open the location list with proper sizing based on content
    open_loclist = function()
        local diagnostics = vim.diagnostic.get()
        if vim.tbl_isempty(diagnostics) then
            vim.notify("No diagnostics in current buffer.", vim.log.levels.INFO)
            return
        end

        -- Convert diagnostics to location list items
        local items = vim.diagnostic.toqflist(diagnostics)

        -- Update the location list
        update_loclist(items)

        -- Determine optimal height (min 3 rows, max 10 rows)
        local height = math.min(math.max(#items, 3), 10)

        -- Open the location list window
        vim.cmd("lopen " .. height)
        loclist_is_open = true
    end,

    -- Toggle function for the diagnostics location list
    toggle_loclist = function()
        -- Check if loclist is really open by querying Neovim
        local win_id = vim.api.nvim_get_current_win()
        local loclist_info = vim.fn.getloclist(win_id, { winid = 0 })
        loclist_is_open = loclist_info.winid ~= 0

        if loclist_is_open then
            -- Check if we have more than one window before trying to close
            if #vim.api.nvim_list_wins() > 1 then
                vim.cmd.lclose()
                loclist_is_open = false
            else
                vim.notify("Cannot close the last window", vim.log.levels.WARN)
            end
        else
            M.open_loclist()
        end
    end
}

return M
