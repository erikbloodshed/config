local Config = {}
Config.__index = Config

function Config.new(options)
    local self = setmetatable({}, Config)

    self.config = {
        output_directory = "/tmp/",
        data_subdirectory = "dat",
        compiler = "g++",
        default_flags = "-std=c++23 -O2",
        compile_command = nil,
        assemble_command = nil,
    }

    self.config = vim.tbl_deep_extend('force', self.config, options or {})
    return self
end

function Config:setup(options)
    options = options or {}
end

function Config:get(key)
    return self.config[key]
end

function Config:set(key, value)
    self.config[key] = value
end

return {
    new = Config.new,
    config = Config.config,
}
