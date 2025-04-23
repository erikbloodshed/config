local config = require("cpp-tools.config")
local compiler_utils = require("cpp-tools.compiler")
local keymaps = require("cpp-tools.keymaps")

local M = {}

function M.setup(user_opts)
    config.setup(user_opts)
    local cfg = config.options

    vim.api.nvim_create_autocmd("Filetype", {
        pattern = { "c", "cpp" },
        callback = function()
            vim.opt_local.cinkeys:remove(":")
            vim.b.current_tick1 = 0
            vim.b.current_tick2 = 0

            local compiler = vim.bo.filetype == "cpp" and cfg.compiler_cpp or cfg.compiler_c
            local flags = compiler_utils.get_compile_flags(".compile_flags",
                vim.bo.filetype == "cpp" and cfg.fallback_flags_cpp or cfg.fallback_flags_c)
            local infile = vim.api.nvim_buf_get_name(0)
            local outfile = cfg.output_dir .. "/" .. vim.fn.expand("%:t:r")
            local asm_file = outfile .. ".s"
            local ext = vim.fn.expand("%:e")
            local data = { nil }

            keymaps.set_keymaps({
                keymaps = cfg.keymaps,
                compiler = compiler,
                flags = flags,
                infile = infile,
                outfile = outfile,
                asm_file = asm_file,
                ext = ext,
                data_ref = data,
                data_folder = cfg.data_folder_name,
            })
        end,
    })
end

return M
