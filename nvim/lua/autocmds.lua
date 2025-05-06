vim.api.nvim_create_autocmd({ "BufEnter" }, {
    pattern = { "*" },
    callback = function()
        require("bufferswitch").setup()
        require("custom_ui.input")
        require("custom_ui.select")
        require("custom_ui.qf").setup({
            show_multiple_lines = false,
            max_filename_length = 30,
        })

        -- local arg = { buffer = args.buf, noremap = true }
        -- vim.keymap.set("n", "<Left>", function() vim.cmd("bprev") end, arg)
        -- vim.keymap.set("n", "<Right>", function() vim.cmd("bnext") end, arg)
    end,
})

vim.api.nvim_create_autocmd("Filetype", {
    pattern = { "c", "cpp" },
    callback = function(args)
        vim.opt_local.cinkeys:remove(":")
        vim.opt_local.cindent = true

        local config = require("cpp-tools.config").init({
            cpp = {
                compiler = "g++-15",
                compile_opts = ".compile_flags",
            }
        })

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

vim.api.nvim_create_autocmd("Filetype", {
    pattern = { "help", "qf" },
    callback = function(args)
        vim.keymap.set("n", "q", vim.cmd.bdelete, { buffer = args.buf, silent = true, noremap = true })
    end,
})

vim.api.nvim_create_autocmd({ "TermOpen" }, {
    pattern = { "*" },
    callback = function()
        vim.cmd.startinsert()
    end,
})

vim.api.nvim_create_autocmd("LspAttach", {
    callback = function(args)
        -- Configure Neovim's built-in diagnostics
        vim.diagnostic.config({
            virtual_text = false,           -- Disable virtual text diagnostics
            severity_sort = true,           -- Sort diagnostics by severity
            float = { border = "rounded" }, -- Set rounded border for diagnostic float window
            signs = {                       -- Define custom text signs for different severity levels
                text = {
                    [vim.diagnostic.severity.ERROR] = "",
                    [vim.diagnostic.severity.WARN] = "󱈸",
                    [vim.diagnostic.severity.HINT] = "",
                    [vim.diagnostic.severity.INFO] = "",
                },
            },
        })

        local diagnostics = require("diagnostics")

        local opts = { buffer = args.buf }
        vim.keymap.set("n", "<leader>ed", vim.diagnostic.open_float, opts)
        vim.keymap.set("n", "<leader>gi", vim.lsp.buf.implementation, opts)
        vim.keymap.set("n", "<leader>gd", vim.lsp.buf.definition, opts)
        vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
        vim.keymap.set("n", "<leader>fc", function()
            vim.lsp.buf.format({ async = true })
        end, opts)
        vim.keymap.set("n", "<leader>xx", diagnostics.toggle_loclist, opts)
    end,
})
