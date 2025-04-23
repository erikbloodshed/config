local compiler_utils = require("cpp-tools.compiler")
local asm = require("cpp-tools.asm")
local data_file = require("cpp-tools.data_file")
local runner = require("cpp-tools.runner")

local M = {}

function M.initialize(opts)
    local map_opts = { buffer = true, noremap = true }

    vim.keymap.set("n", opts.keymaps.compile, function()
        compiler_utils.compile(opts.compiler, opts.flags, opts.outfile, opts.infile, opts.ext)
    end, map_opts)

    vim.keymap.set("n", opts.keymaps.run, function()
        runner.run(opts)
    end, map_opts)

    vim.keymap.set("n", opts.keymaps.show_asm, function()
        asm.show(opts.compiler, opts.flags, opts.asm_file, opts.infile)
    end, map_opts)

    vim.keymap.set("n", opts.keymaps.add_data, function()
        data_file.add(opts.data_folder, function(choice)
            opts.data_ref[1] = choice
        end)
    end, map_opts)

    vim.keymap.set("n", opts.keymaps.remove_data, function()
        data_file.remove(opts.data_ref[1], function()
            opts.data_ref[1] = nil
            vim.notify("Data file removed.")
        end)
    end, map_opts)
end

return M
