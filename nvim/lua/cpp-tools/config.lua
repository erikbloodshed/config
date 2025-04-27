local Config = {}
Config.__index = Config

function Config.new(options)
    local self = setmetatable({}, Config)
    return self:init(options)
end

function Config:init(options)
    self.config = {
        c = {
            compiler         = "gcc",
            fallback_flags   = "-std=c23 -O2",
            infile           = nil,
            compile_command  = nil,
            assemble_command = nil,
        },

        cpp = {
            compiler         = "g++",
            fallback_flags   = "-std=c++23 -O2",
            infile           = nil,
            compile_command  = nil,
            assemble_command = nil,
        },

        dir = {
            data_directory   = "dat",
            output_directory = "/tmp/",
        }
    }
    if options then
        self.config = vim.tbl_deep_extend('force', self.config, options)
    end
    return self
end

function Config:get(key)
    return self.config[key]
end

function Config:set(key, value)
    self.config[key] = value
end

return Config
