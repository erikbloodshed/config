vim.api.nvim_create_autocmd("Filetype", {
    pattern = { "qf", "help", "query" },
    callback = function()
        vim.keymap.set("n", "q", vim.cmd.bdelete, { buffer = true, silent = true, noremap = true })
    end,
})

vim.api.nvim_create_autocmd("Filetype", {
    pattern = { "c", "cpp" },
    callback = function()
        vim.lsp.enable("clangd")
        vim.opt_local.formatoptions:remove({ "c", "r", "o" })
        vim.opt_local.cinkeys:remove(":")
        vim.opt_local.cindent = true
        vim.opt_local.autowrite = true
        vim.b.current_tick = 0
        local infile = vim.api.nvim_buf_get_name(0)
        local outfile = "/tmp/" .. vim.fn.expand("%:t:r")
        local compiler = "g++"
        local default_flags = "-std=c++23 -O2"
        local ext = vim.fn.expand("%:e")

        if vim.bo.filetype == "c" then
            compiler = "gcc"
            default_flags = "-std=c23 -O2"
        end

        local get_compile_flags = function()
            local dir = vim.fn.expand("%:p:h")
            while dir do
                local file_path = dir .. "/.compile_flags"
                if vim.uv.fs_stat(file_path) then
                    return "@" .. file_path
                end
                dir = dir:match("^(.*)/[^/]+$")
            end
            return default_flags
        end

        local flags = get_compile_flags()

        local compile = function()
            if ext == "h" or ext == "hpp" then
                return false
            elseif vim.b.current_tick == vim.b.changedtick then
                return true
            elseif next(vim.diagnostic.get(0, { severity = { vim.diagnostic.severity.ERROR } })) == nil then
                local cmd = string.format("!%s %s -o %s %s", compiler, flags, outfile, infile)
                vim.api.nvim_command(cmd)
                vim.b.current_tick = vim.b.changedtick
                return true
            else
                require("trouble").open("diagnostics")
                return false
            end
        end

        local run = function()
            local trouble = require("trouble")
            if trouble.is_open() then
                trouble.close()
            end

            if compile() then
                vim.cmd.terminal()
                vim.defer_fn(function()
                    vim.api.nvim_input(outfile .. "<CR>")
                end, 75)
            end
        end

        vim.keymap.set({ "n" }, "<leader>rc", compile, { buffer = true, noremap = true })
        vim.keymap.set({ "n" }, "<leader>rr", run, { buffer = true, noremap = true })
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
        vim.diagnostic.config({
            virtual_text = false,
            severity_sort = true,
            float = { border = "rounded" },
            signs = {
                text = {
                    [vim.diagnostic.severity.ERROR] = "",
                    [vim.diagnostic.severity.WARN] = "󱈸",
                    [vim.diagnostic.severity.HINT] = "",
                    [vim.diagnostic.severity.INFO] = "",
                },
            },
        })
        local opts = { buffer = args.buf }
        vim.keymap.set("n", "<leader>ed", vim.diagnostic.open_float)
        vim.keymap.set("n", "<leader>gi", vim.lsp.buf.implementation, opts)
        vim.keymap.set("n", "<leader>gd", vim.lsp.buf.definition, opts)
        vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
        vim.keymap.set("n", "<leader>fc", function()
            require("conform").format({ async = true })
        end, opts)
    end,
})
