local diagnostics = require("user.cpp.diagnostics")

local M = {}

function M.get_compile_flags(filename, fallback)
    local path = vim.fs.find(filename, {
        upward = true,
        type = "file",
        path = vim.fn.expand("%:p:h"),
        stop = vim.fn.expand("~"),
    })[1]
    return path and ("@" .. path) or fallback
end

function M.compile(compiler, flags, outfile, infile, ext)
    if ext == "h" or ext == "hpp" then return false end
    local diagnostics_list = vim.diagnostic.get(0, { severity = { vim.diagnostic.severity.ERROR } })

    if vim.tbl_isempty(diagnostics_list) then
        vim.cmd("!" .. string.format("%s %s -o %s %s", compiler, flags, outfile, infile))
        vim.b.current_tick1 = vim.b.changedtick
        return true
    end

    diagnostics.goto_first(diagnostics_list)
    return false
end

return M
