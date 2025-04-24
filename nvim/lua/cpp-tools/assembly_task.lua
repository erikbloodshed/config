local AssemblyTask = {}
AssemblyTask.__index = AssemblyTask

function AssemblyTask.new(config) -- Accept config instance
    local self = setmetatable({}, AssemblyTask)
    self.config = config          -- Store the config instance
    return self
end

function AssemblyTask:show_assembly()
    local utils = require("cpp-tools.utils")
    local compiler = self.config:get("compiler")
    local flags = utils.get_compile_flags(".compile_flags")
    local outfile = self.config:get("output_directory") .. vim.fn.expand("%:t:r")
    local infile = vim.api.nvim_buf_get_name(0)
    local asm_file = outfile .. ".s"
    local cmd_assemble = self.config:get("assemble_command")
        or string.format("%s %s -S -o %s %s", compiler, flags, asm_file, infile)

    local diagnostics = vim.diagnostic.get(0, { severity = { vim.diagnostic.severity.ERROR } })

    if vim.tbl_isempty(diagnostics) then
        vim.cmd("silent! write")
        vim.fn.system(cmd_assemble)
        return true
    end

    utils.goto_first_diagnostic(diagnostics)
    return false
end

return {
    new = AssemblyTask.new,
}
