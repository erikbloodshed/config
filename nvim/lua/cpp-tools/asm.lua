local M = {}

function M.show(compiler, flags, asm_file, infile)
    local diagnostics = vim.diagnostic.get(0, { severity = vim.diagnostic.severity.ERROR })

    if vim.b.current_tick ~= vim.b.changedtick then
        if vim.tbl_isempty(diagnostics) then
            vim.cmd("silent! write")
            vim.system({ compiler, flags, "-S", "-o", asm_file, infile }):wait()
            vim.b.current_tick = vim.b.changedtick
        else
            local d = diagnostics[1]
            local line = vim.api.nvim_buf_get_lines(0, d.lnum, d.lnum + 1, false)[1] or ""
            vim.api.nvim_win_set_cursor(0, { d.lnum + 1, math.min(d.col, #line) })
            return
        end
    end

    local asm_content = vim.fn.readfile(asm_file)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].swapfile = false
    vim.bo[buf].filetype = "asm"

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, asm_content)
    vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = math.floor(vim.o.columns * 0.8),
        height = math.floor(vim.o.lines * 0.8),
        row = math.floor(vim.o.lines * 0.1),
        col = math.floor(vim.o.columns * 0.1),
        style = "minimal",
        border = "rounded",
        title = asm_file,
        title_pos = "center",
    })

    vim.bo[buf].modifiable = false
    vim.keymap.set("n", "q", vim.cmd.close, { buffer = buf, noremap = true, nowait = true })
end

return M
