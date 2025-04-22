local compiler_utils = require("user.cpp.compiler")
local asm = require("user.cpp.assembly")
local data_file = require("user.cpp.data_file")

local M = {}

function M.set_keymaps(opts)
    local keymaps = opts.keymaps
    local compiler = opts.compiler
    local flags = opts.flags
    local infile = opts.infile
    local outfile = opts.outfile
    local asm_file = opts.asm_file
    local ext = opts.ext
    local buffer_opts = { buffer = true, noremap = true }

    local data = opts.data_ref

    local function run()
        if vim.b.current_tick1 == vim.b.changedtick or compiler_utils.compile(compiler, flags, outfile, infile, ext) then
            vim.cmd.terminal()
            vim.defer_fn(function()
                local out_cmd = outfile
                if data[1] then
                    out_cmd = out_cmd .. " < " .. data[1]
                end
                if vim.b.terminal_job_id then
                    vim.api.nvim_chan_send(vim.b.terminal_job_id, out_cmd .. "\n")
                end
            end, 50)
        end
    end

    vim.keymap.set("n", keymaps.compile, function()
        compiler_utils.compile(compiler, flags, outfile, infile, ext)
    end, buffer_opts)

    vim.keymap.set("n", keymaps.run, run, buffer_opts)

    vim.keymap.set("n", keymaps.show_asm, function()
        asm.show(compiler, flags, asm_file, infile)
    end, buffer_opts)

    vim.keymap.set("n", keymaps.add_data, function()
        data_file.add(function(choice)
            data[1] = choice
        end)
    end, buffer_opts)

    vim.keymap.set("n", keymaps.remove_data, function()
        data_file.remove(data[1], function()
            data[1] = nil
            vim.notify("Data file removed.")
        end)
    end, buffer_opts)
end

return M
