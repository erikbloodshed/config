--[[
  This Lua module provides functionality for building, running, and inspecting C/C++ code
  within the Neovim editor. It integrates with external tools and manages project-specific
  configurations and data files.
]]

-- Import required modules
local handler = require("cpp-tools.handler") --  manages the execution of external processes (like compiler, runner).
local utils = require("cpp-tools.utils")     -- contains helper functions for file operations, path manipulation, etc.

-- Define the main module table 'M' which will be returned.
local M = {}

M.init = function(config)
    -- Store configuration values in local variables for easier access.
    local compiler = config.compiler
    local flags = config.compile_opts
    local output_dir = config.output_directory
    local data_dir = config.data_dir_name

    -- TODO: Validate the config values and apply defaults where appropriate.

    local src_file = vim.api.nvim_buf_get_name(0)
    -- TODO: Ensure output_dir ends with a path separator to avoid invalid paths.
    local exe_file = output_dir .. vim.fn.expand("%:t:r")
    local asm_file = exe_file .. ".s"

    -- TODO: Consider memoizing or caching this path lookup for performance.
    local data_path = utils.get_data_path(data_dir)

    -- NOTE: Persisting hashes to disk (e.g. per-project) could optimize larger workflows.
    local hash = { compile = nil, assemble = nil }

    local data_file = nil

    -- local compile_command = utils.flatten_tbl({ compiler, flags, "-o", exe_file, src_file })
    -- local assemble_command = utils.flatten_tbl({ compiler, flags, "-S", "-o", asm_file, src_file })
    local compile_args = utils.merged_list(flags, { "-o", exe_file, src_file })
    local assemble_args = utils.merged_list(flags, { "-S", "-o", asm_file, src_file })

    local compile_command = { compiler = compiler, arg = compile_args }
    local assemble_command = { compiler = compiler, arg = assemble_args }

    -- TODO: Log failure details or errors on compile failure.
    local function compile()
        return handler.translate(hash, "compile", compile_command)
    end

    -- TODO: Support passing runtime arguments or environment variables.
    local function run()
        if compile() then
            handler.run(exe_file, data_file)
        end
    end

    -- TODO: Skip assembly generation if existing file is already up-to-date.
    local function show_assembly()
        if handler.translate(hash, "assemble", assemble_command) then
            utils.open(asm_file, utils.read_file(asm_file), "asm")
        end
    end

    -- TODO: Allow previewing a data file’s contents before selection.
    -- TODO: Optionally remember last-used data file per buffer/project.
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
        else
            vim.notify("'" .. data_dir .. "' directory not found.", vim.log.levels.ERROR)
        end
    end

    -- TODO: Add optional deletion of file from filesystem when removing.
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
            return
        end
        vim.notify("No data file is currently set.", vim.log.levels.WARN)
    end

    -- TODO: Add file size or compile time to info output.
    -- TODO: Option to export or log this information to disk.
    local function get_build_info()
        local lines = {
            "Filetype         : " .. vim.bo.filetype,
            "Compiler         : " .. compiler,
            "Compile Flags    : " .. table.concat(flags, " "),
            "Source           : " .. src_file,
            "Output Directory : " .. output_dir,
            "Data Directory   : " .. (data_path or "Not Found"),
            "Data File In Use : " .. (data_file and vim.fn.fnamemodify(data_file, ':t') or "None"),
            "Date Modified    : " .. utils.get_modified_time(src_file),
        }

        local ns_id = vim.api.nvim_create_namespace("build_info_highlight")
        local buf_id = utils.open("Build Info", lines, "text")

        for idx = 1, #lines do
            local line = lines[idx]
            local colon_pos = line:find(":")
            if colon_pos and colon_pos > 1 then
                vim.api.nvim_buf_add_highlight(buf_id, ns_id, "Keyword", idx - 1, 0, colon_pos - 1)
            end
        end
    end

    -- TODO: Add a `clean` function to remove exe/asm/data artifacts.
    -- TODO: Add a `rebuild` function that forces recompile even if hashes match.
    return {
        compile = compile,
        run = run,
        show_assembly = show_assembly,
        add_data_file = add_data_file,
        remove_data_file = remove_data_file,
        get_build_info = get_build_info,
    }
end

return M
