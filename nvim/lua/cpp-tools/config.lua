M = {}

M.init = function(options)
    local config = {
        c = {
            compiler         = "gcc",
            fallback_flags   = { "-std=c23", "-O2" },
            compile_opts     = nil,
            data_dir_name    = "dat",
            output_directory = "/tmp/",
        },

        cpp = {
            compiler         = "g++",
            fallback_flags   = {"-std=c++23", "-O2"},
            compile_opts     = nil,
            data_dir_name    = "dat",
            output_directory = "/tmp/",
        }
    }

    config = vim.tbl_deep_extend('force', config, options or {})

    return config[vim.bo.filetype]
end

return M
