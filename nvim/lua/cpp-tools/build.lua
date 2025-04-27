local utils = require("cpp-tools.utils")

local Build = {}
Build.__index = Build

function Build.new(config, ft)
    local self             = setmetatable({}, Build)

    self.execution_handler = require("cpp-tools.execution_handler").new()

    self.compiler          = config:get(ft).compiler
    self.infile            = config:get(ft).infile
    self.fallback_flags    = config:get(ft).fallback_flags
    self.output_dir        = config:get("dir").output_directory
    self.data_dir          = config:get("dir").data_directory

    self.flags             = utils.get_compile_flags(self.infile) or self.fallback_flags
    self.exe_file          = self.output_dir .. "/" .. vim.fn.expand("%:t:r")
    self.asm_file          = self.exe_file .. ".s"
    self.infile            = vim.api.nvim_buf_get_name(0)

    self.compile_cmd       = config:get(ft).compile_command or
        string.format("%s %s -o %s %s", self.compiler, self.flags, self.exe_file, self.infile)
    self.assemble_cmd      = config:get(ft).assemble_command or
        string.format("%s %s -S -o %s %s", self.compiler, self.flags, self.asm_file, self.infile)

    self.hash              = { compile = nil, assemble = nil }

    return self
end

function Build:process(key, callback)
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
    self:process("compile", function() vim.cmd("!" .. self.compile_cmd) end)
end

function Build:run()
    if not self:process("compile", function() vim.cmd("!" .. self.compile_cmd) end) then
        vim.notify("Compilation failed or skipped, cannot run.", vim.log.levels.WARN)
        return
    end
    self.execution_handler:run(self.exe_file)
end

function Build:show_assembly()
    if not self:process("assemble", function()
            vim.cmd("silent! write")
            vim.fn.system(self.assemble_cmd)
        end) then
        vim.notify("Compilation failed or skipped, cannot run.", vim.log.levels.WARN)
        return
    end
    utils.open(string.format(" %s ", self.asm_file), utils.read_file(self.asm_file), "asm")
end

function Build:add_data_file()
    self.execution_handler:select_data_file(self.data_dir) -- Call method on instance
end

function Build:remove_data_file()
    self.execution_handler:remove_data_file() -- Call method on instance
end

function Build:get_build_info()
    local lines = {
        "Compiler         : " .. self.compiler,
        "Filetype         : " .. vim.bo.filetype,
        "Source           : " .. self.infile,
        "Fallback Flags   : " .. self.fallback_flags,
        "Detected Flags   : " .. self.flags,
        "Output Directory : " .. self.output_dir,
        "Data Directory   : " .. self.data_dir,
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
