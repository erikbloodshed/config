local compiler_utils = require("user.cpp.compiler")
local asm = require("user.cpp.assembly")
local data_file = require("user.cpp.data_file")

local M = {}

function M.setup()
    vim.api.nvim_create_autocmd("Filetype", {
        pattern = { "c", "cpp" },
        callback = function()
            vim.opt_local.cinkeys:remove(":")
            vim.opt_local.cindent = true
            vim.b.current_tick1 = 0
            vim.b.current_tick2 = 0

            local compiler = vim.bo.filetype == "cpp" and "g++" or "gcc"
            local flags = compiler_utils.get_compile_flags(".compile_flags",
                vim.bo.filetype == "cpp" and "-std=c++23 -O2" or "-std=c23 -O2")
            local infile = vim.api.nvim_buf_get_name(0)
            local outfile = "/tmp/" .. vim.fn.expand("%:t:r")
            local asm_file = outfile .. ".s"
            local ext = vim.fn.expand("%:e")
            local data = nil

            local function run()
                if vim.b.current_tick1 == vim.b.changedtick or compiler_utils.compile(compiler, flags, outfile, infile, ext) then
                    vim.cmd.terminal()
                    vim.defer_fn(function()
                        local out_cmd = outfile
                        if data then out_cmd = out_cmd .. " < " .. data end
                        if vim.b.terminal_job_id then
                            vim.api.nvim_chan_send(vim.b.terminal_job_id, out_cmd .. "\n")
                        end
                    end, 50)
                end
            end

            local opts = { buffer = true, noremap = true }

            vim.keymap.set("n", "<leader>rc", function()
                compiler_utils.compile(compiler, flags, outfile, infile, ext)
            end, opts)

            vim.keymap.set("n", "<leader>rr", run, opts)

            vim.keymap.set("n", "<leader>ra", function()
                asm.show(compiler, flags, asm_file, infile)
            end, opts)

            vim.keymap.set("n", "<leader>fa", function()
                data_file.add(function(choice) data = choice end)
            end, opts)

            vim.keymap.set("n", "<leader>fr", function()
                data_file.remove(data, function()
                    data = nil
                    vim.notify("Data file removed.")
                end)
            end, opts)
        end,
    })
end

return M
