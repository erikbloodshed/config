local diagnostic = vim.diagnostic
local severity = diagnostic.severity
local vim_fn = vim.fn
local keymap = vim.keymap.set
local autocmd = vim.api.nvim_create_autocmd
local api = vim.api
local cmd = vim.cmd

diagnostic.config({
    -- virtual_text = false,
    virtual_text = { current_line = true },
    severity_sort = true,
    float = { border = "rounded" },
    signs = {
        text = {
            [severity.ERROR] = "",
            [severity.WARN] = "󱈸",
            [severity.HINT] = "",
            [severity.INFO] = "",
        },
    },
})
--

-- Create a custom formatter for diagnostics in location list
local function format_diagnostics_for_loclist()
    local diagnostics_list = diagnostic.get()
    if vim.tbl_isempty(diagnostics_list) then
        return {}
    end

    local items = {}
    for _, diag in ipairs(diagnostics_list) do
        local bufnr = diag.bufnr
        local filename = vim.api.nvim_buf_get_name(bufnr)
        local severity_name = severity[diag.severity] or "UNKNOWN"
        local severity_icon = {
            [severity.ERROR] = "E",
            [severity.WARN] = "W",
            [severity.HINT] = "H",
            [severity.INFO] = "I",
        }

        -- Format the text for the location list
        local text = string.format("[%s] %s",
            severity_icon[diag.severity] or "?",
            diag.message:gsub("\n", " "):gsub("\r", "")
        )

        -- Add source information if available
        if diag.source and diag.source ~= "" then
            text = text .. string.format(" [%s]", diag.source)
        end

        -- Add code if available
        if diag.code and diag.code ~= "" then
            text = text .. string.format(" (%s)", diag.code)
        end

        table.insert(items, {
            bufnr = bufnr,
            filename = filename,
            lnum = diag.lnum + 1, -- Convert to 1-based indexing
            col = diag.col + 1,   -- Convert to 1-based indexing
            text = text,
            type = severity_name:sub(1, 1),
        })
    end

    -- -- Sort by severity, then by filename, then by line number
    -- table.sort(items, function(a, b)
    --     if a.type ~= b.type then
    --         -- Order by severity: E, W, I, H
    --         local order = { E = 1, W = 2, I = 3, H = 4 }
    --         return order[a.type] < order[b.type]
    --     elseif a.filename ~= b.filename then
    --         return a.filename < b.filename
    --     elseif a.lnum ~= b.lnum then
    --         return a.lnum < b.lnum
    --     else
    --         return a.col < b.col
    --     end
    -- end)
    --
    return items
end

-- Replace your existing diagnostic.setloclist() calls with this custom function
local function set_formatted_loclist(opts)
    opts = opts or {}
    local items = format_diagnostics_for_loclist()
    vim.fn.setloclist(0, {}, ' ', {
        title = opts.title or "Diagnostics",
        items = items,
        nr = opts.nr,
    })

    if opts.open then
        local height = math.min(math.max(#items, 3), 10)
        cmd("lopen " .. height)
    end
end

keymap("n", "<leader>qq", function()
    local loclist = vim_fn.getloclist(0, { winid = 0 })
    local is_open = loclist.winid ~= 0

    if is_open then
        cmd("lclose")
    else
        -- Open the location list
        local diag = diagnostic.get()
        if vim.tbl_isempty(diag) then
            vim.notify("No diagnostics in current buffer.", vim.log.levels.WARN)
            return
        end

        set_formatted_loclist({ open = true })
    end
end, { desc = "Toggle diagnostics location list" })

keymap("n", "<CR>", function()
    local idx = vim.fn.line(".")
    local loclist = vim.fn.getloclist(0)

    local item = loclist[idx]
    if item and item.bufnr then
        cmd("lclose")
        api.nvim_set_current_buf(item.bufnr)
        api.nvim_win_set_cursor(0, { item.lnum, (item.col > 0 and item.col - 1 or 0) })
    end
end, { desc = "Close diagnostics location list on jump" })

autocmd("DiagnosticChanged", {
    callback = function(args)
        local diagnostics = args.data.diagnostics
        if vim.tbl_isempty(diagnostics) then
            vim.cmd.lclose()
        end

        -- Only update loclist if it's currently visible
        local loclist = vim_fn.getloclist(0, { winid = 0 })
        if loclist.winid ~= 0 then
            set_formatted_loclist({ open = false })
        end
    end,
})
