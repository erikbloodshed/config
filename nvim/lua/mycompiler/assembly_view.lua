local function open(asm_file)
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
    vim.keymap.set("n", "q", vim.cmd.close, { buffer = true, noremap = true, nowait = true, silent = true, })
end

return {
    open = open,
}
