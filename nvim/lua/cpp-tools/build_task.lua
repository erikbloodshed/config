local utils = require("cpp-tools.utils")
local RunTask = require("cpp-tools.run_task")
local DataSelectorTask = require("cpp-tools.data_selector")

local BuildTask = {}
BuildTask.__index = BuildTask

function BuildTask.new(config)
    local self = setmetatable({}, BuildTask)
    self.config = config
    self.run_task = RunTask.new(config)
    self.data_select_task = DataSelectorTask.new(config) -- Create an instance!
    self.last_compiled_hash = nil
    self.last_assembled_hash = nil
    self.data_file = nil
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
        vim.api.nvim_echo({ { "Warning", "WarningMsg" }, { ": Source code is already compiled.", "Normal" }, }, true, {})
    end

    return success
end

function BuildTask:run()
    if not self:compile() then return end
    self.run_task:run(self.exe_file)
end

function BuildTask:assemble()
    local hash = utils.get_buffer_hash()
    local success = true

    if self.last_compiled_hash ~= hash then
        success = utils.compile(function()
            vim.cmd("!" ..
                self.config:get("assemble_command") or
                string.format("%s %s -S -o %s %s", self.compiler, self.flags, self.asm_file, self.infile)
            )
        end)

        if success then
            self.last_compiled_hash = hash
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

function BuildTask:set_data_file(file)
    self.data_file = file
    self.run_task:set_data_file(file)
end

function BuildTask:add_data_file()
    self.data_select_task:add(self) -- Call method on instance
end

function BuildTask:remove_data_file()
    self.data_select_task:remove(self) -- Call method on instance
end

function BuildTask:get_data_file()
    return self.data_file
end

return {
    new = BuildTask.new,
}
