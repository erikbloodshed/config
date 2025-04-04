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

        local compiler = vim.bo.filetype == "cpp" and "g++" or "gcc"
        local flags = get_compile_flags(".compile_flags")
        local outfile = "/tmp/" .. vim.fn.expand("%:t:r")
        local infile = vim.api.nvim_buf_get_name(0)
        local asm_file = outfile .. ".s"
        local ext = vim.fn.expand("%:e")
        local cmd_compile = string.format("%s %s -o %s %s", compiler, flags, outfile, infile)
        local cmd_assemble = string.format("%s %s -S -o %s %s", compiler, flags, asm_file, infile)

        local function goto_first_diagnostic(diagnostics)
            local col = diagnostics[1].col
            local lnum = diagnostics[1].lnum

            -- Ensure line number is within buffer range
            local buf_lines = vim.api.nvim_buf_line_count(0)
            lnum = math.min(lnum, buf_lines - 1) -- lnum is 0-based, so subtract 1

            -- Get line content safely
            local line = vim.api.nvim_buf_get_lines(0, lnum, lnum + 1, false)[1] or ""

            -- Clamp column within the valid range
            col = math.min(col, #line)

            vim.api.nvim_win_set_cursor(0, { lnum + 1, col })
        end

        local function compile()
            if ext == "h" or ext == "hpp" then
                return false
            end

            local diagnostics = vim.diagnostic.get(0, { severity = { vim.diagnostic.severity.ERROR } })

            if vim.tbl_isempty(diagnostics) then
                vim.cmd("!" .. cmd_compile)
                vim.b.current_tick1 = vim.b.changedtick
                return true
            end

            goto_first_diagnostic(diagnostics)

            return false
        end

        local function run()
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
            local diagnostics = vim.diagnostic.get(0, { severity = { vim.diagnostic.severity.ERROR } })

            if vim.b.current_tick2 ~= vim.b.changedtick then
                if vim.tbl_isempty(diagnostics) then
                    vim.cmd("silent! write")
                    vim.fn.system(cmd_assemble)
                    vim.b.current_tick2 = vim.b.changedtick
                else
                    goto_first_diagnostic(diagnostics)
                    return
                end
            end

            -- Read the generated assembly file
            local asm_content = vim.fn.readfile(asm_file)

            -- Create a scratch buffer
            local buf = vim.api.nvim_create_buf(false, true)
            vim.bo[buf].buftype = "nofile"
            vim.bo[buf].bufhidden = "wipe"
            vim.bo[buf].swapfile = false
            vim.bo[buf].filetype = "asm"

            -- Set the assembly content in the buffer
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, asm_content)

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
        vim.diagnostic.config({
            -- virtual_text = false,
            virtual_text = { current_line = true },
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
