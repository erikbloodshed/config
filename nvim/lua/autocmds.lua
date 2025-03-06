vim.api.nvim_create_autocmd("Filetype", {
    pattern = { "c", "cpp" },
    callback = function()
        vim.opt_local.cinkeys:remove(":")
        vim.opt_local.cindent = true
        vim.b.current_tick1 = 0
        vim.b.current_tick2 = 0

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

        local trouble = require("trouble")
        local compiler = vim.bo.filetype == "cpp" and "g++" or "gcc"
        local flags = get_compile_flags(".compile_flags")
        local outfile = "/tmp/" .. vim.fn.expand("%:t:r")
        local infile = vim.api.nvim_buf_get_name(0)
        local ext = vim.fn.expand("%:e")
        local cmd_compile = string.format("%s %s -o %s %s", compiler, flags, outfile, infile)
        local asm_file = outfile .. ".s"
        local cmd_assemble = string.format("%s %s -S %s -o %s", compiler, flags, infile, asm_file)


        local function compile()
            if ext == "h" or ext == "hpp" then
                return false
            end

            if vim.tbl_isempty(vim.diagnostic.get(0, { severity = { vim.diagnostic.severity.ERROR } })) then
                vim.cmd("!" .. cmd_compile)
                vim.b.current_tick1 = vim.b.changedtick
                return true
            end

            trouble.open("diagnostics")
            return false
        end

        local function run()
            if trouble.is_open() then
                trouble.close()
            end

            if vim.b.current_tick1 == vim.b.changedtick or compile() then
                vim.cmd.terminal()
                vim.defer_fn(function()
                    -- to prevent race conditions
                    if vim.b.terminal_job_id then
                        vim.api.nvim_chan_send(vim.b.terminal_job_id, outfile .. "\n")
                    end
                end, 50)
            end
        end

        local function show_assembly()
            if vim.b.current_tick2 ~= vim.b.changedtick then
                -- Run the command
                local result = vim.fn.system(cmd_assemble)

                -- Check for compilation errors
                if vim.v.shell_error ~= 0 then
                    vim.notify("Assembly generation failed:\n" .. result, vim.log.levels.ERROR)
                    return
                end

                vim.b.current_tick2 = vim.b.changedtick
            end

            -- Read the generated assembly file
            local asm_content = vim.fn.readfile(asm_file)

            -- Create a scratch buffer
            local buf = vim.api.nvim_create_buf(false, true)
            vim.bo[buf].buftype = "nofile"
            vim.bo[buf].bufhidden = "hide"
            vim.bo[buf].swapfile = false

            -- Set the assembly content in the buffer
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, asm_content)

            -- Set filetype to enable Tree-sitter highlighting
            vim.bo[buf].filetype = "asm"

            -- Open the buffer in a new window
            vim.api.nvim_open_win(buf, true, {
                relative = "editor",
                width = math.floor(vim.o.columns * 0.8),
                height = math.floor(vim.o.lines * 0.8),
                row = math.floor(vim.o.lines * 0.1),
                col = math.floor(vim.o.columns * 0.1),
                style = "minimal",
                border = "rounded",
                title = asm_file,
                title_pos = "center",
            })

            vim.bo[buf].modifiable = false
            vim.keymap.set("n", "q", vim.cmd.close, { buffer = true, noremap = true, nowait = true })
        end

        vim.keymap.set("n", "<leader>rc", compile, { buffer = true, noremap = true })
        vim.keymap.set("n", "<leader>rr", run, { buffer = true, noremap = true })
        vim.keymap.set("n", "<leader>ra", show_assembly, { buffer = true, noremap = true })
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
        vim.keymap.set("n", "<leader>fc", function()
            vim.lsp.buf.format({ async = true })
        end, opts)
    end,
})
