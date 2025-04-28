local Config = {}
Config.__index = Config

function Config.new(options)
    local self = setmetatable({}, Config)
    return self:init(options)
end

function Config:init(opts)
    self.config = {
        c = {
            compiler       = "gcc",
            fallback_flags = "-std=c23 -O2",
            compile_opts   = nil,
            compile_cmd    = nil,
            assemble_cmd   = nil,
        },

        cpp = {
            compiler       = "g++-15",
            fallback_flags = "-std=c++23 -O2",
            compile_opts   = nil,
            compile_cmd    = nil,
            assemble_cmd   = nil,
        },

        dir = {
            data_dir_name    = "dat",
            output_directory = "/tmp/",
        }
    }

    self.config = vim.tbl_deep_extend('force', self.config, opts or {})
    return self
end

function Config:get(key)
    return self.config[key]
end

function Config:set(key, value)
    self.config[key] = value
end

return Config
