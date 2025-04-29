local handler = require("cpp-tools.handler")
local utils = require("cpp-tools.utils")

local M = {}

M.init = function(config)
    local compiler = config.compiler
    local compile_opts = config.compile_opts
    local fallback_flags = config.fallback_flags
    local output_dir = config.output_directory
    local data_dir = config.data_dir_name

    local options_file = utils.get_options_file(compile_opts)
    local flags = options_file or fallback_flags
    local src_file = vim.api.nvim_buf_get_name(0)
    local exe_file = output_dir .. vim.fn.expand("%:t:r")
    local asm_file = exe_file .. ".s"
    local data_path = utils.get_data_path(data_dir)

    local hash = { compile = nil, assemble = nil }
    local data_file = nil

    local compile_command = { compiler, flags, "-o", exe_file, src_file }
    local assemble_command = { compiler, flags, "-S -o", asm_file, src_file }

    local function compile()
        return handler.compile(hash, "compile", compile_command)
    end

    local function run()
        if compile() then
            handler.run(exe_file, data_file)
        end
    end

    local function show_assembly()
        if handler.compile(hash, "assemble", assemble_command) then
            utils.open(asm_file, utils.read_file(asm_file), "asm")
        end
    end

    local function add_data_file()
        if data_path then
            local files = utils.scan_dir(data_path)
            if vim.tbl_isempty(files) then
                vim.notify("No files found in data directory: " .. data_path, vim.log.levels.WARN)
                return
            end

            vim.ui.select(files, {
                prompt = "Current: " .. (data_file or "None"),
                format_item = function(item)
                    return vim.fn.fnamemodify(item, ':t')
                end,
            }, function(choice)
                if choice then
                    data_file = choice
                    vim.notify("Data file set to: " .. vim.fn.fnamemodify(choice, ':t'), vim.log.levels.INFO)
                end
            end)
        end
    end

    local function remove_data_file()
        if data_file then
            vim.ui.select({ "Yes", "No" }, {
                prompt = "Remove data file (" .. vim.fn.fnamemodify(data_file, ':t') .. ")?",
            }, function(choice)
                if choice == "Yes" then
                    data_file = nil
                    vim.notify("Data file removed.", vim.log.levels.INFO)
                end
            end)
        end
        vim.notify("No data file is currently set.", vim.log.levels.WARN)
    end

    local function get_build_info()
        local lines = {
            "Filetype         : " .. vim.bo.filetype,
            "Compiler         : " .. compiler,
            "Compile Flags    : " .. table.concat(flags, " "),
            "Source           : " .. src_file,
            "Output Directory : " .. output_dir,
            "Data Directory   : " .. (data_path or ""),
            "Data File In Use : " .. (data_file or ""),
            "Date Modified    : " .. utils.get_modified_time(src_file),
        }

        local buf_id = utils.open("Build Info", lines, "text")
        for i, line in ipairs(lines) do
            local col = line:find(":")
            if col then
                vim.api.nvim_buf_add_highlight(buf_id, -1, "Keyword", i - 1, 0, col - 1)
            end
        end
    end

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
