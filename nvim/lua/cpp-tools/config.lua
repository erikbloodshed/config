local Config = {}
Config.__index = Config

function Config.new(options)
    local self = setmetatable({}, Config)
    self.defaults = {
        output_directory = "/tmp/",
        data_subdirectory = "dat",
        compiler = "g++",
        default_flags = "-std=c++23 -O2",
        compile_command = nil, -- Allow overriding the entire compile command
        assemble_command = nil, -- Allow overriding the entire assemble command
    }
    self.config = {}
    self:setup(options) -- Initialize config
    return self
end

function Config:setup(options)
    options = options or {}
    self.config = vim.tbl_deep_extend('force', self.defaults, options)
end

function Config:get(key)
    return self.config[key]
end

function Config:set(key, value)
    self.config[key] = value
end

return {
    new = Config.new,
    defaults = Config.defaults,
}
