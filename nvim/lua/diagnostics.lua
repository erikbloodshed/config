local diagnostic = vim.diagnostic
local severity = diagnostic.severity
local vim_fn = vim.fn
local keymap = vim.keymap.set
local autocmd = vim.api.nvim_create_autocmd
local api = vim.api
local cmd = vim.cmd

local severity_labels = {
    [severity.ERROR] = "ERROR",
    [severity.WARN] = "WARN",
    [severity.HINT] = "HINT",
    [severity.INFO] = "INFO",
}

local errorformat =
    [[%l:%c:\ [%tRROR]\ %m]] .. [[,%l:%c:\ [%tARN]\ %m]] ..
    [[,%l:%c:\ [%tNFO]\ %m]] .. [[,%l:%c:\ [%tINT]\ %m]]

diagnostic.config({
    virtual_text = false,
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

local function jump_from_loclist()
    local idx = vim.fn.line(".")
    local loclist = vim.fn.getloclist(0)

    local item = loclist[idx]
    if item and item.bufnr then
        local bufnr = item.bufnr
        local lnum = item.lnum or 1
        local col = item.col and math.max(0, item.col - 1) or 0

        cmd("lclose")

        vim.schedule(function()
            if api.nvim_buf_is_valid(bufnr) and api.nvim_buf_is_loaded(bufnr) then
                -- Clamp line number to avoid out-of-bounds errors
                local line_count = vim.api.nvim_buf_line_count(bufnr)
                local safe_line = math.max(1, math.min(lnum, line_count))

                api.nvim_set_current_buf(bufnr)
                api.nvim_win_set_cursor(0, { safe_line, col })
            end
        end)
    end
end

local function set_diagnostics_format(opts)
    local diagnostics_list = diagnostic.get()
    if vim.tbl_isempty(diagnostics_list) then
        return
    end

    -- Format each diagnostic according to a pattern that errorformat can parse
    local formatted_lines = {}
    for _, diag in ipairs(diagnostics_list) do
        local lnum = diag.lnum + 1 -- Convert to 1-based indexing
        local col = diag.col + 1   -- Convert to 1-based indexing
        local severity_label = severity_labels[diag.severity]
        local message = diag.message:gsub("\n", " "):gsub("\r", "")

        -- Add formatted diagnostic line to our list
        table.insert(formatted_lines, string.format("%d:%d: [%s] %s",
            lnum, col,
            severity_label, message))
    end

    vim.fn.setloclist(0, {}, ' ', {
        title = "Diagnostics",
        efm = errorformat,
        lines = formatted_lines,
    })

    -- Open the location list if requested
    if opts.open then
        local height = math.min(math.max(#diagnostics_list, 3), 10)
        cmd("lopen " .. height)
        local loclist_info = vim_fn.getloclist(0, { winid = 0 })

        if loclist_info.winid ~= 0 then
            local loclist_bufnr = api.nvim_win_get_buf(loclist_info.winid)
            keymap("n", "<CR>", jump_from_loclist,
                { buffer = loclist_bufnr, nowait = true, desc = "Close diagnostics location list on jump" })
            keymap("n", "<Esc>", "<Cmd>lclose<CR>",
                { buffer = loclist_bufnr, nowait = true, desc = "Close diagnostics location list" })
        end
    end
end

local function toggle_loclist()
    local loclist_info = vim_fn.getloclist(0, { winid = 0 })
    local is_open = loclist_info.winid ~= 0

    if is_open then
        cmd("lclose")
    else
        -- Open the location list
        local diag = diagnostic.get()
        if vim.tbl_isempty(diag) then
            vim.notify("No diagnostics in current buffer.", vim.log.levels.WARN)
            return
        end

        -- set_formatted_loclist({ open = true })
        set_diagnostics_format({ open = true })
    end
end


autocmd("DiagnosticChanged", {
    callback = function(args)
        local diagnostics = args.data.diagnostics
        if vim.tbl_isempty(diagnostics) then
            vim.schedule(function()
                vim.cmd.lclose()
            end)
        end

        -- Only update loclist if it's currently visible
        local loclist_info = vim_fn.getloclist(0, { winid = 0 })
        if loclist_info.winid ~= 0 then
            -- set_formatted_loclist({ open = false })
            set_diagnostics_format({ open = false })
        end
    end,
})

keymap("n", "<leader>xx", toggle_loclist, { buffer = true, desc = "Toggle diagnostics location list" })
