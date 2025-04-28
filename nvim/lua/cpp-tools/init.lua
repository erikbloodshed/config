local M = {}

function M.setup(opts)
    vim.api.nvim_create_autocmd("Filetype", {
        pattern = { "c", "cpp" },
        callback = function(args)
            local config = require("cpp-tools.config").init(opts)
            local build = require("cpp-tools.build").init(config)
            local arg = { buffer = args.buf, noremap = true }

            vim.keymap.set("n", "<leader>rc", function() build.compile() end, arg)
            vim.keymap.set("n", "<leader>rr", function() build.run() end, arg)
            vim.keymap.set("n", "<leader>ra", function() build.show_assembly() end, arg)
            vim.keymap.set("n", "<leader>fa", function() build.add_data_file() end, arg)
            vim.keymap.set("n", "<leader>fr", function() build.remove_data_file() end, arg)
            vim.keymap.set({ "n", "i" }, "<F12>", function() build.get_build_info() end, arg)
        end,
    })
end

return M
