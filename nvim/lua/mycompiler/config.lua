local defaults = {
    filetypes = { "c", "cpp" },
    output_directory = "/tmp/",
    data_subdirectory = "dat",
    default_c_compiler = "gcc",
    default_cpp_compiler = "g++",
    default_c_flags = "-std=c23 -O2",
    default_cpp_flags = "-std=c++23 -O2",
    compile_command = nil, -- Allow overriding the entire compile command
    assemble_command = nil, -- Allow overriding the entire assemble command
}

local M = {}

function M.setup(options)
    options = options or {}
    M.config = vim.tbl_deep_extend('force', defaults, options)
end

M.defaults = defaults -- Expose defaults for reference

return M
