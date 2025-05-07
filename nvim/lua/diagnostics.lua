-- Cache the quickfix status (optional, can query vim directly)
local quickfix_is_open = false

-- Update the quickfix list without opening it
local function update_quickfixlist(items)
    vim.fn.setqflist({}, ' ', {
        title = "Diagnostics",
        items = items
    })
end

-- Handle diagnostic changes efficiently
vim.api.nvim_create_autocmd("DiagnosticChanged", {
    callback = function(args)
        local diagnostics = args.data.diagnostics

        -- Convert diagnostics to quickfix list items
        local items = vim.diagnostic.toqflist(diagnostics)

        -- Update the quickfix list
        update_quickfixlist(items)

        -- If quickfix window is open and there are no diagnostics, close it
        if #diagnostics == 0 then
            -- Query the quickfix list info to check if it's open
            local qf_info = vim.fn.getqflist({ winid = 0 })
            if qf_info.winid ~= 0 then -- winid 0 means no quickfix window is open
                 vim.schedule(function()
                    -- Check if we have more than one window before trying to close
                    if #vim.api.nvim_list_wins() > 1 then
                        vim.cmd.cclose()
                        quickfix_is_open = false -- Update our cached state
                    end
                 end)
            end
        end

    end,
})

-- Add this new autocommand

M = {
    -- Open the quickfix list with proper sizing based on content
    open_quickfixlist = function()
        local diagnostics = vim.diagnostic.get()
        if vim.tbl_isempty(diagnostics) then
            vim.notify("No diagnostics in current buffer.", vim.log.levels.INFO)
            return
        end

        -- Convert diagnostics to quickfix list items
        local items = vim.diagnostic.toqflist(diagnostics)

        -- Update the quickfix list
        update_quickfixlist(items)

        -- Determine optimal height (min 3 rows, max 10 rows)
        local height = math.min(math.max(#items, 3), 10)

        -- Open the quickfix window
        vim.cmd("copen " .. height)
        quickfix_is_open = true -- Update our cached state
    end,

    -- Toggle function for the diagnostics quickfix list
    toggle_quickfixlist = function()
        -- Check if quickfix is really open by querying Neovim
        local qf_info = vim.fn.getqflist({ winid = 0 })
        quickfix_is_open = qf_info.winid ~= 0 -- winid 0 means no quickfix window is open

        if quickfix_is_open then
             -- Check if we have more than one window before trying to close
            if #vim.api.nvim_list_wins() > 1 then
                vim.cmd.cclose()
                quickfix_is_open = false -- Update our cached state
            else
                vim.notify("Cannot close the last window", vim.log.levels.WARN)
            end
        else
            M.open_quickfixlist()
        end
    end
}
-- ... (update_quickfixlist, DiagnosticChanged autocommand, M table definition) ...

-- Autocommand group to prevent duplication
local auto_close_group = vim.api.nvim_create_augroup("DiagnosticsAutoCloseOnBufLeave", { clear = true })

vim.api.nvim_create_autocmd("BufLeave", {
    group = auto_close_group,
    pattern = "*", -- Trigger on leaving any buffer
    callback = function()
        local qf_info = vim.fn.getqflist({ winid = 0, title = 1 }) -- title = 1 requests title info

        if qf_info.winid ~= 0 and qf_info.title == "Diagnostics" then
            if #vim.api.nvim_list_wins() > 1 then
                vim.cmd.cclose()
                quickfix_is_open = false -- Update the cached state (this variable is local to diagnostics.lua)
                vim.notify("Quickfix closed.", vim.log.levels.INFO)
            else
                vim.notify("Cannot close quickfix: It's the last window.", vim.log.levels.WARN)
            end
        end
    end,
})

return M

