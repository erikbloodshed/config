local utils = require("cpp-tools.utils")
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
    return self.compile_task:compile()
end

function BuildTask:run()
    local hash = utils.get_buffer_hash()
    if self.last_compiled_hash ~= hash then
        if not self:compile() then return end
        self.last_compiled_hash = hash
    end
    self.run_task:run()
end

function BuildTask:show_assembly()
    self.assembly_task:show_assembly()
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

