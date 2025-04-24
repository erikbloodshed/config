local CompileTask = require("cpp-tools.compile_task")
local RunTask = require("cpp-tools.run_task")
local AssemblyTask = require("cpp-tools.assembly_task")
local DataSelectorTask = require("cpp-tools.data_selector")

local BuildTask = {}
BuildTask.__index = BuildTask

function BuildTask.new(config)
    local self = setmetatable({}, BuildTask)
    self.config = config
    self.compile_task = CompileTask.new(config)
    self.run_task = RunTask.new(config)
    self.assembly_task = AssemblyTask.new(config)
    self.data_select_task = DataSelectorTask.new(config) -- Create an instance!
    self.last_compiled_hash = nil
    self.last_assembled_hash = nil
    self.data_file = nil
    return self
end

function BuildTask:compile()
    local success = self.compile_task:compile()
    if success then
        self.last_compiled_hash = self:get_buffer_hash()
    end
    return success
end

function BuildTask:run()
    local success = self.run_task:run(self.last_compiled_hash)
    if not success then
        if self:compile() then
            self.run_task:run(self.last_compiled_hash)
        end
    end
end

function BuildTask:show_assembly()
    self.assembly_task:show_assembly()
end

function BuildTask:get_buffer_hash()
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
    local content = table.concat(lines, "\n")
    return vim.fn.sha256(content)
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

