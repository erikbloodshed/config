local AssemblyTask = {}
AssemblyTask.__index = AssemblyTask

function AssemblyTask.new(config) -- Accept config instance
    local self = setmetatable({}, AssemblyTask)
    self.config = config  -- Store the config instance
    self.last_assembled_hash = nil
    return self
end

function AssemblyTask:open(asm_file)
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

function AssemblyTask:show_assembly()
    local compiler = self:get_compiler()
    local flags = self:get_compile_flags(".compile_flags")
    local outfile = self.config:get("output_directory") .. vim.fn.expand("%:t:r")
    local infile = vim.api.nvim_buf_get_name(0)
    local asm_file = outfile .. ".s"
    local cmd_assemble = self.config:get("assemble_command")
        or string.format("%s %s -S -o %s %s", compiler, flags, asm_file, infile)
    local current_hash = self:get_buffer_hash()
    local diagnostics = vim.diagnostic.get(0, { severity = { vim.diagnostic.severity.ERROR } })

    if self.last_assembled_hash ~= current_hash then
        if vim.tbl_isempty(diagnostics) then
            vim.cmd("silent! write")
            vim.fn.system(cmd_assemble)
            self.last_assembled_hash = current_hash
        else
            self:goto_first_diagnostic(diagnostics)
            return
        end
    end

    self:open(asm_file) -- Use the member function
end

function AssemblyTask:get_compiler()
    return self.config:get("compiler")
end

function AssemblyTask:get_compile_flags(filename)
    local path = vim.fs.find(filename, {
        upward = true,
        type = "file",
        path = vim.fn.expand("%:p:h"),
        stop = vim.fn.expand("~"),
    })[1]
    if path ~= nil then
        return "@" .. path
    end
    return self.config:get("default_flags")
end

function AssemblyTask:goto_first_diagnostic(diagnostics)
    if vim.tbl_isempty(diagnostics) then
        return
    end
    local diag = diagnostics[1]
    local col = diag.col
    local lnum = diag.lnum
    local buf_lines = vim.api.nvim_buf_line_count(0)
    lnum = math.min(lnum, buf_lines - 1)
    local line = vim.api.nvim_buf_get_lines(0, lnum, lnum + 1, false)[1] or ""
    col = math.min(col, #line)
    vim.api.nvim_win_set_cursor(0, { lnum + 1, col + 1 })
end

function AssemblyTask:get_buffer_hash()
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
    local content = table.concat(lines, "\n")
    return vim.fn.sha256(content)
end

return {
    new = AssemblyTask.new,
}
