local utils = require("cpp-tools.utils")

local Build = {}
Build.__index = Build

function Build.new(config, ft)
    local self             = setmetatable({}, Build)

    self.execution_handler = require("cpp-tools.execution_handler").new()

    self.compiler          = config:get(ft).compiler
    self.compile_opts      = config:get(ft).compile_opts
    self.fallback_flags    = config:get(ft).fallback_flags
    self.output_dir        = config:get("dir").output_directory
    self.data_dir          = config:get("dir").data_dir_name
    self.compile_cmd       = config:get(ft).compile_cmd
    self.assemble_cmd      = config:get(ft).assemble_cmd

    self.options_file      = utils.get_options_file(self.compile_opts)
    self.flags             = self.options_file or self.fallback_flags
    self.exe_file          = self.output_dir .. vim.fn.expand("%:t:r")
    self.asm_file          = self.exe_file .. ".s"
    self.infile            = vim.api.nvim_buf_get_name(0)
    self.data_path         = utils.get_data_path(self.data_dir)
    self.hash              = { compile = nil, assemble = nil }

    self.cmp_command       = self.compile_cmd or
        string.format("%s %s -o %s %s", self.compiler, self.flags, self.exe_file, self.infile)
    self.asm_command       = self.assemble_cmd or
        string.format("%s %s -S -o %s %s", self.compiler, self.flags, self.asm_file, self.infile)

    return self
end

function Build:process(key, callback)
    if vim.bo.modified then
        vim.cmd("silent! write")
    end
    local buffer_hash = utils.get_buffer_hash()
    if self.hash[key] ~= buffer_hash then
        local diagnostics = vim.diagnostic.get(0, { severity = { vim.diagnostic.severity.ERROR } })

        if vim.tbl_isempty(diagnostics) then
            callback()
            self.hash[key] = buffer_hash
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

function Build:compile()
    if self:process("compile", function() vim.fn.system(self.cmp_command) end) then
        vim.notify("Compiled successfully.", vim.log.levels.INFO)
    end
end

function Build:run()
    if not self:process("compile", function() vim.fn.system(self.cmp_command) end) then
        vim.notify("Compilation failed or skipped, cannot run.", vim.log.levels.WARN)
        return
    end
    self.execution_handler:run(self.exe_file)
end

function Build:show_assembly()
    vim.cmd("silent! write")
    if not self:process("assemble", function()
            vim.fn.system(self.asm_command)
        end) then
        vim.notify("Compilation failed or skipped, cannot run.", vim.log.levels.WARN)
        return
    end
    utils.open(string.format(" %s ", self.asm_file), utils.read_file(self.asm_file), "asm")
end

function Build:add_data_file()
    self.execution_handler:select_data_file(self.data_path) -- Call method on instance
end

function Build:remove_data_file()
    self.execution_handler:remove_data_file() -- Call method on instance
end

function Build:get_build_info()
    local lines = {
        "Filetype         : " .. vim.bo.filetype,
        "Compiler         : " .. self.compiler,
        "Compile Flags    : " .. self.flags,
        "Source           : " .. self.infile,
        "Output Directory : " .. self.output_dir,
        "Data Directory   : " .. (self.data_path or ""),
        "Date Modified    : " .. utils.get_modified_time(self.infile),
        "Date Created     : " .. utils.get_creation_time(self.infile)
    }

    local buf = utils.open(" Compile Info ", lines, "text")
    for i, line in ipairs(lines) do
        local col = line:find(":")
        if col then
            vim.api.nvim_buf_add_highlight(buf, -1, "Keyword", i - 1, 0, col - 1)
        end
    end
end

return {
    new = Build.new,
}
