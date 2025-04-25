local CompileTask = {}
CompileTask.__index = CompileTask

function CompileTask.new(config)
    local self = setmetatable({}, CompileTask)
    self.config = config
    return self
end

function CompileTask:compile(args, cmd)
    local utils = require("cpp-tools.utils")

    -- local compiler = self.config:get("compiler")
    -- local flags = utils.get_compile_flags(".compile_flags")
    -- local outfile = self.config:get("output_directory") .. vim.fn.expand("%:t:r")
    -- local infile = vim.api.nvim_buf_get_name(0)
    local compiler = args.compiler
    local flags = args.flags
    local outfile = args.outfile
    local infile = args.infile

    local cmd_compile = self.config:get("compile_command")
        or string.format("%s %s -o %s %s", compiler, flags, outfile, infile)

    local diagnostics = vim.diagnostic.get(0, { severity = { vim.diagnostic.severity.ERROR } })

    if vim.tbl_isempty(diagnostics) then
        cmd(cmd_compile)
        return true
    end

    utils.goto_first_diagnostic(diagnostics)
    return false
end

return {
    new = CompileTask.new,
}
