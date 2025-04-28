local utils = require("cpp-tools.utils")

local M = {}

M.init = function(config, ft)
    local config_ft = config:get(ft)
    local config_dir = config:get("dir")

    local handler = require("cpp-tools.handler").new()

    local compiler = config_ft.compiler
    local compile_opts = config_ft.compile_opts
    local fallback_flags = config_ft.fallback_flags
    local compile_cmd = config_ft.compile_cmd
    local assemble_cmd = config_ft.assemble_cmd
    local output_dir = config_dir.output_directory
    local data_dir = config_dir.data_dir_name

    local options_file = utils.get_options_file(compile_opts)
    local flags = options_file or fallback_flags
    local infile = vim.api.nvim_buf_get_name(0)
    local exe_file = output_dir .. vim.fn.expand("%:t:r")
    local asm_file = exe_file .. ".s"
    local data_path = utils.get_data_path(data_dir)

    local hash = { compile = nil, assemble = nil }
    local data_file = nil

    -- Functions to get the compile and assemble commands
    local function get_compile_command()
        return compile_cmd or string.format(
            "%s %s -o %s %s",
            compiler,
            flags,
            exe_file,
            infile
        )
    end

    local function get_assemble_command()
        return assemble_cmd or string.format(
            "%s %s -S -o %s %s",
            compiler,
            flags,
            asm_file,
            infile
        )
    end

    -- Core functions that were previously methods of the 'Build' object
    local function process(key, callback)
        if vim.bo.modified then
            vim.cmd("silent! write")
        end
        local buffer_hash = utils.get_buffer_hash()
        if hash[key] ~= buffer_hash then
            local diagnostics = vim.diagnostic.get(0, { severity = { vim.diagnostic.severity.ERROR } })

            if vim.tbl_isempty(diagnostics) then
                callback()
                hash[key] = buffer_hash
                return true
            end

            utils.goto_first_diagnostic(diagnostics)
            vim.notify("Source code compilation failed.", vim.log.levels.ERROR)

            return false
        else
            vim.notify("Source code is already compiled.", vim.log.levels.WARN)
        end

        return true
    end

    local function compile()
        if process("compile", function()
            vim.fn.system(get_compile_command())
        end) then
            vim.notify("Compiled successfully.", vim.log.levels.INFO)
        end
    end

    local function run()
        if not process("compile", function()
            vim.fn.system(get_compile_command())
        end) then
            vim.notify("Compilation failed or skipped, cannot run.", vim.log.levels.WARN)
            return
        end
        handler:run(exe_file)
    end

    local function show_assembly()
        vim.cmd("silent! write")
        if not process("assemble", function()
            vim.fn.system(get_assemble_command())
        end) then
            vim.notify("Compilation failed or skipped, cannot run.", vim.log.levels.WARN)
            return
        end
        utils.open(string.format(" %s ", asm_file), utils.read_file(asm_file), "asm")
    end

    local function add_data_file()
        if not data_path then return end
        local files = utils.scan_dir(data_path)
        if vim.tbl_isempty(files) then
            vim.notify("No files found in data directory: " .. data_path, vim.log.levels.WARN)
            return
        end

        local prompt = 'Current: ' .. (data_file or 'None') .. '):'
        vim.ui.select(files, {
            prompt = prompt,
            format_item = function(item)
                return vim.fn.fnamemodify(item, ':t')
            end,
        }, function(choice)
            if choice then
                data_file = choice
                handler:set_data_file(data_file)
                vim.notify("Data file set to: " .. vim.fn.fnamemodify(choice, ':t'), vim.log.levels.INFO)
            end
        end)
    end

    local function remove_data_file()
        if data_file == nil then
            vim.notify("No data file is currently set.", vim.log.levels.WARN)
            return
        end

        vim.ui.select({ "Yes", "No" }, {
            prompt = "Remove data file (" .. vim.fn.fnamemodify(data_file, ':t') .. ")?",
        }, function(choice)
            if choice == "Yes" then
                data_file = nil
                handler:set_data_file(nil)
                vim.notify("Data file removed.", vim.log.levels.INFO)
            end
        end)
    end

    local function get_build_info()
        local lines = {
            "Filetype         : " .. ft,
            "Compiler         : " .. compiler,
            "Compile Flags    : " .. flags,
            "Source           : " .. infile,
            "Output Directory : " .. output_dir,
            "Data Directory   : " .. (data_path or ""),
            "Data File In Use : " .. (data_file or ""),
            "Date Modified    : " .. utils.get_modified_time(infile),
            "Date Created     : " .. utils.get_creation_time(infile)
        }

        local buf = utils.open(" Compile Info ", lines, "text")
        for i, line in ipairs(lines) do
            local col = line:find(":")
            if col then
                vim.api.nvim_buf_add_highlight(buf, -1, "Keyword", i - 1, 0, col - 1)
            end
        end
    end

    -- Return all functions that were once part of the 'Build' object
    return {
        compile = compile,
        run = run,
        show_assembly = show_assembly,
        add_data_file = add_data_file,
        remove_data_file = remove_data_file,
        get_build_info = get_build_info
    }
end

return M
