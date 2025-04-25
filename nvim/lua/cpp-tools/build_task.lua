local utils = require("cpp-tools.utils")
local ExecutionHandler = require("cpp-tools.execution_handler")

local BuildTask = {}
BuildTask.__index = BuildTask

function BuildTask.new(config)
    local self = setmetatable({}, BuildTask)
    self.config = config
    self.execution_handler = ExecutionHandler.new(config)
    self.last_compiled_hash = nil
    self.last_assembled_hash = nil
    self.flags = utils.get_compile_flags(".compile_flags")
    self.exe_file = self.config:get("output_directory") .. vim.fn.expand("%:t:r")
    self.asm_file = self.exe_file .. ".s"
    self.infile = vim.api.nvim_buf_get_name(0)
    self.compiler = self.config:get("compiler")
    return self
end

function BuildTask:compile()
    local hash = utils.get_buffer_hash()
    local success = true

    if self.last_compiled_hash ~= hash then
        success = utils.compile(function()
            local cmd_compile = self.config:get("compile_command") or
                string.format("%s %s -o %s %s", self.compiler, self.flags, self.exe_file, self.infile)
            vim.cmd("!" .. cmd_compile)
        end)

        if success then
            self.last_compiled_hash = hash
        end
    else
        vim.api.nvim_echo({ { "Info", "Todo" }, { ": Source code is already compiled.", "Normal" }, }, true, {})
    end

    return success
end

function BuildTask:run()
    if not self:compile() then
        vim.notify("Compilation failed or skipped, cannot run.", vim.log.levels.WARN)
        return
    end
    self.execution_handler:run(self.exe_file)
end

function BuildTask:assemble()
    local hash = utils.get_buffer_hash()
    local success = true

    if self.last_assembled_hash ~= hash then
        success = utils.compile(function()
            vim.fn.system(self.config:get("assemble_command") or
                string.format("%s %s -S -o %s %s", self.compiler, self.flags, self.asm_file, self.infile))
        end)

        if success then
            self.last_assembled_hash = hash
        end
    end

    return success
end

function BuildTask:show_assembly()
    local hash = utils.get_buffer_hash()
    if self.last_assembled_hash ~= hash then
        if not self:assemble() then return end
    end
    utils.open(self.asm_file)
end

function BuildTask:add_data_file()
    self.execution_handler:select_data_file() -- Call method on instance
end

function BuildTask:remove_data_file()
    self.execution_handler:remove_data_file() -- Call method on instance
end

return {
    new = BuildTask.new,
}
