local M = {}

local default_config = {
    compiler_c = "gcc",
    compiler_cpp = "g++",
    fallback_flags_c = "-std=c23 -O2",
    fallback_flags_cpp = "-std=c++23 -O2",
    output_dir = "/tmp",
    data_folder_name = "dat",
    keymaps = {
        compile = "<leader>rc",
        run = "<leader>rr",
        show_asm = "<leader>ra",
        add_data = "<leader>fa",
        remove_data = "<leader>fr",
    },
}

function M.setup(user_config)
    M.options = vim.tbl_deep_extend("force", {}, default_config, user_config or {})
end

return M
