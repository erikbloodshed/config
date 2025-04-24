local CompileTask = {}
CompileTask.__index = CompileTask

function CompileTask.new(config)
    local self = setmetatable({}, CompileTask)
    self.config = config
    return self
end

function CompileTask:get_compile_flags(filename)
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

function CompileTask:goto_first_diagnostic(diagnostics)
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

function CompileTask:compile()
    local ext = vim.fn.expand("%:e")
    if ext == "h" or ext == "hpp" then
        return false
    end

    local compiler = self.config:get("compiler")
    local flags = self:get_compile_flags(".compile_flags")
    local outfile = self.config:get("output_directory") .. vim.fn.expand("%:t:r")
    local infile = vim.api.nvim_buf_get_name(0)
    local cmd_compile = self.config:get("compile_command")
                        or string.format("%s %s -o %s %s", compiler, flags, outfile, infile)

    local diagnostics = vim.diagnostic.get(0, { severity = { vim.diagnostic.severity.ERROR } })

    if vim.tbl_isempty(diagnostics) then
        vim.cmd("!" .. cmd_compile)
        return true
    end

    self:goto_first_diagnostic(diagnostics)
    return false
end

return {
    new = CompileTask.new,
}
