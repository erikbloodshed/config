vim.api.nvim_create_autocmd("Filetype", {
    pattern = { "c", "cpp" },
    callback = function()
        vim.lsp.enable("clangd")

        local function get_compile_flags(filename)
            local path = vim.fs.find(filename, {
                upward = true,
                type = "file",
                path = vim.fn.expand("%:p:h"),
                stop = vim.fn.expand("~"),
            })[1]
            if path ~= nil then
                return "@" .. path
            end
            return vim.bo.filetype == "cpp" and "-std=c++23 -O2" or "-std=c23 -O2"
        end

        vim.opt_local.cinkeys:remove(":")
        vim.opt_local.cindent = true
        vim.b.current_tick = 0

        local trouble = require("trouble")
        local compiler = vim.bo.filetype == "cpp" and "g++" or "gcc"
        local flags = get_compile_flags(".compile_flags")
        local outfile = "/tmp/" .. vim.fn.expand("%:t:r")
        local infile = vim.api.nvim_buf_get_name(0)
        local ext = vim.fn.expand("%:e")
        local cmd = string.format("!%s %s -o %s %s", compiler, flags, outfile, infile)

        local function compile()
            if ext == "h" or ext == "hpp" then
                return false
            end

            if vim.tbl_isempty(vim.diagnostic.get(0, { severity = { vim.diagnostic.severity.ERROR } })) then
                vim.cmd(cmd)
                vim.b.current_tick = vim.b.changedtick
                return true
            end

            trouble.open("diagnostics")
            return false
        end

        local function run()
            if trouble.is_open() then
                trouble.close()
            end

            if vim.b.current_tick == vim.b.changedtick or compile() then
                vim.cmd.terminal()
                vim.defer_fn(function()
                    -- to prevent race conditions
                    if vim.b.terminal_job_id then
                        vim.api.nvim_chan_send(vim.b.terminal_job_id, outfile .. "\n")
                    end
                end, 50)
            end
        end

        vim.keymap.set({ "n" }, "<leader>rc", compile, { buffer = true, noremap = true })
        vim.keymap.set({ "n" }, "<leader>rr", run, { buffer = true, noremap = true })
    end,
})

vim.api.nvim_create_autocmd("Filetype", {
    pattern = { "qf", "help", "query" },
    callback = function()
        vim.keymap.set("n", "q", vim.cmd.bdelete, { buffer = true, silent = true, noremap = true })
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
        vim.keymap.set("n", "<leader>ed", vim.diagnostic.open_float, opts)
        vim.keymap.set("n", "<leader>gi", vim.lsp.buf.implementation, opts)
        vim.keymap.set("n", "<leader>gd", vim.lsp.buf.definition, opts)
        vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
        vim.keymap.set("n", "<leader>fc",
            function()
                require("conform").format({ async = true })
            end, opts)
    end,
})
