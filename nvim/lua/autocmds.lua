local diagnostic = vim.diagnostic
local keymap     = vim.keymap.set
local autocmd    = vim.api.nvim_create_autocmd
local lsp_buf    = vim.lsp.buf
local cmd        = vim.cmd
local setlocal   = vim.opt_local
local severity   = diagnostic.severity

autocmd("Filetype", {
    pattern = { "c", "cpp" },
    callback = function()
        setlocal.cinkeys:remove(":")
        setlocal.cindent = true
    end,
})

autocmd("Filetype", {
    pattern = { "help", "qf" },
    callback = function(args)
        keymap("n", "q", cmd.bdelete, { buffer = args.buf, silent = true, noremap = true })
    end,
})

autocmd({ "TermOpen" }, {
    pattern = { "*" },
    callback = function()
        cmd.startinsert()
    end,
})

autocmd("LspAttach", {
    callback = function(args)
        -- Configure Neovim's built-in diagnostics
        diagnostic.config({
            virtual_text = false,           -- Disable virtual text diagnostics
            severity_sort = true,           -- Sort diagnostics by severity
            float = { border = "rounded" }, -- Set rounded border for diagnostic float window
            signs = {                       -- Define custom text signs for different severity levels
                text = {
                    [severity.ERROR] = "",
                    [severity.WARN] = "󱈸",
                    [severity.HINT] = "",
                    [severity.INFO] = "",
                },
            },
        })
        require("diagnostics")

        local opts = { buffer = args.buf }
        keymap("n", "<leader>ed", diagnostic.open_float, opts)
        keymap("n", "<leader>gi", lsp_buf.implementation, opts)
        keymap("n", "<leader>gd", lsp_buf.definition, opts)
        keymap("n", "<leader>rn", lsp_buf.rename, opts)
        keymap("n", "<leader>fc", function()
            lsp_buf.format({ async = true })
        end, opts)
    end,
})
