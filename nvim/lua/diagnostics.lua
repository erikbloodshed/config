-- Setup pretty quickfix formatting
local diagnostic      = vim.diagnostic
local keymap          = vim.keymap.set
local autocmd         = vim.api.nvim_create_autocmd
local cmd             = vim.cmd

-- Cache the loclist status to avoid unnecessary operations
local loclist_is_open = false

-- Efficiently convert diagnostic object to location list item
local function diagnostic_to_qf_item(diag)
    -- Map severity levels to single characters
    local severity_map = { "E", "W", "I", "H" }

    return {
        bufnr = diag.bufnr,
        lnum = diag.lnum + 1, -- Convert 0-index to 1-index
        col = diag.col + 1,   -- Convert 0-index to 1-index
        end_lnum = diag.end_lnum and (diag.end_lnum + 1) or nil,
        end_col = diag.end_col and (diag.end_col + 1) or nil,
        text = diag.message,
        type = severity_map[diag.severity] or "E"
    }
end

-- Convert multiple diagnostics to location list items
local function diagnostics_to_qf_items(diagnostics)
    local items = {}
    for _, diag in ipairs(diagnostics) do
        table.insert(items, diagnostic_to_qf_item(diag))
    end
    return items
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

    -- Return focus to the original window (optional)
    vim.cmd("wincmd p")
end

local function toggle_loclist()
    if loclist_is_open then
        cmd.lclose()
        loclist_is_open = false
    else
        open_loclist()
    end
end

-- Handle diagnostic changes efficiently
autocmd("DiagnosticChanged", {
    callback = function(args)
        local diagnostics = args.data.diagnostics

        if #diagnostics == 0 then
            -- Only try to close if it's actually open
            if loclist_is_open then
                vim.schedule(function()
                    cmd.lclose()
                    loclist_is_open = false
                end)
            end
            return
        end

        -- Get current window ID to check if loclist is visible
        local win_id = vim.api.nvim_get_current_win()
        local loclist_info = vim.fn.getloclist(win_id, { winid = 0 })
        loclist_is_open = loclist_info.winid ~= 0

        -- Convert diagnostics to location list items
        local items = diagnostics_to_qf_items(diagnostics)

        -- Update the location list
        update_loclist(items)
    end,
})

-- Close loclist when closing a buffer or window (optional cleanup)
autocmd({ "BufWinLeave", "WinLeave" }, {
    callback = function()
        -- Schedule to next tick to avoid race conditions
        vim.schedule(function()
            -- Check if there are any diagnostics left in any visible buffer
            local has_diagnostics = false
            for _, buf in ipairs(vim.api.nvim_list_bufs()) do
                if vim.api.nvim_buf_is_loaded(buf) and #diagnostic.get(buf) > 0 then
                    has_diagnostics = true
                    break
                end
            end

            -- If no diagnostics and loclist is open, close it
            if not has_diagnostics and loclist_is_open then
                cmd.lclose()
                loclist_is_open = false
            end
        end)
    end
})

-- Define keymap to toggle the diagnostics location list
keymap("n", "<leader>xx", toggle_loclist, { buffer = true, desc = "Toggle diagnostics location list" })

return {
    open_loclist = open_loclist,
    toggle_loclist = toggle_loclist
}
