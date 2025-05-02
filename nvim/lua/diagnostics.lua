local diagnostic = vim.diagnostic
local severity = diagnostic.severity
local vim_fn = vim.fn
local keymap = vim.keymap.set
local autocmd = vim.api.nvim_create_autocmd
local api = vim.api
local cmd = vim.cmd

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

local function set_diagnostics_format(opts)
    local diagnostics_list = diagnostic.get()
    if vim.tbl_isempty(diagnostics_list) then
        return
    end

    -- Format each diagnostic according to a pattern that errorformat can parse
    local formatted_lines = {}
    local severity_labels = {
        [severity.ERROR] = "ERROR",
        [severity.WARN] = "WARN",
        [severity.HINT] = "HINT",
        [severity.INFO] = "INFO",
    }

    for _, diag in ipairs(diagnostics_list) do
        local lnum = diag.lnum + 1 -- Convert to 1-based indexing
        local col = diag.col + 1   -- Convert to 1-based indexing
        local severity_label = severity_labels[diag.severity] or "UNKNOWN"
        local message = diag.message:gsub("\n", " "):gsub("\r", "")

        -- Add formatted diagnostic line to our list
        table.insert(formatted_lines, string.format("%d:%d: [%s] %s",
            lnum, col,
            severity_label, message))
    end

    -- Save the current errorformat
    local prev_errorformat = vim.o.errorformat

    -- Set a custom errorformat to parse our diagnostic format
    vim.o.errorformat = [[%l:%c:\ [%tRROR]\ %m]]                      -- Error lines
    vim.o.errorformat = vim.o.errorformat .. [[,%l:%c:\ [%tARN]\ %m]] -- Warning lines
    vim.o.errorformat = vim.o.errorformat .. [[,%l:%c:\ [%tNFO]\ %m]] -- Info lines
    vim.o.errorformat = vim.o.errorformat .. [[,%l:%c:\ [%tINT]\ %m]] -- Hint lines

    -- Load the formatted lines with our custom errorformat
    vim.fn.setloclist(0, {}, ' ', {
        title = "Diagnostics",
        efm = vim.o.errorformat, -- Use our custom errorformat
        lines = formatted_lines,
    })

    -- Restore the original errorformat
    vim.o.errorformat = prev_errorformat

    -- Open the location list if requested
    if opts.open then
        local height = math.min(math.max(#diagnostics_list, 3), 10)
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

        -- set_formatted_loclist({ open = true })
        set_diagnostics_format({ open = true })
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
            -- set_formatted_loclist({ open = false })
            set_diagnostics_format({ open = false })
        end
    end,
})
