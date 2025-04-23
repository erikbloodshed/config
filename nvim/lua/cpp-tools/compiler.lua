local M = {}

function M.get_compile_flags(filename, fallback)
    local path = vim.fs.find(filename, {
        upward = true,
        type = "file",
        path = vim.fn.expand("%:p:h"),
        stop = vim.fn.expand("~"),
    })[1]
    if path then
        return "@" .. path
    end
    return fallback
end

function M.compile(compiler, flags, outfile, infile, ext)
    if ext == "h" or ext == "hpp" then
        return false
    end

    local diagnostics = vim.diagnostic.get(0, { severity = vim.diagnostic.severity.ERROR })
    if vim.tbl_isempty(diagnostics) then
        vim.cmd(string.format("!%s %s -o %s %s", compiler, flags, outfile, infile))
        return true
    end

    local d = diagnostics[1]
    local line = vim.api.nvim_buf_get_lines(0, d.lnum, d.lnum + 1, false)[1] or ""
    vim.api.nvim_win_set_cursor(0, { d.lnum + 1, math.min(d.col, #line) })
    return false
end

return M
