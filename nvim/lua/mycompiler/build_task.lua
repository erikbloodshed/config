local config = require('mycompiler.config')

local BuildTask = {}
BuildTask.__index = BuildTask

function BuildTask.new()
    local self = setmetatable({}, BuildTask)
    self.current_tick1 = 0
    self.current_tick2 = 0
    self.data_file = nil
    return self
end

function BuildTask:get_compiler()
    return vim.bo.filetype == "cpp" and config.config.default_cpp_compiler or config.config.default_c_compiler
end

function BuildTask:get_compile_flags(filename)
    local path = vim.fs.find(filename, {
        upward = true,
        type = "file",
        path = vim.fn.expand("%:p:h"),
        stop = vim.fn.expand("~"),
    })[1]
    if path ~= nil then
        return "@" .. path
    end
    return vim.bo.filetype == "cpp" and config.config.default_cpp_flags or config.config.default_c_flags
end

function BuildTask:goto_first_diagnostic(diagnostics)
    if vim.tbl_isempty(diagnostics) then
        return
    end
    local diag = diagnostics[1]
    local col = diag.col
    local lnum = diag.lnum
    local buf_lines = vim.api.nvim_buf_line_count(0)
    lnum = math.min(lnum, buf_lines - 1)
    local line = vim.api.nvim_buf_get_lines(0, lnum, lnum + 1, false)[1] or ""
    col = math.min(col, #line)
    vim.api.nvim_win_set_cursor(0, { lnum + 1, col + 1 })
end

function BuildTask:compile()
    local ext = vim.fn.expand("%:e")
    if ext == "h" or ext == "hpp" then
        return false
    end

    local compiler = self:get_compiler()
    local flags = self:get_compile_flags(".compile_flags")
    local outfile = config.config.output_directory .. vim.fn.expand("%:t:r")
    local infile = vim.api.nvim_buf_get_name(0)
    local cmd_compile = config.config.compile_command
                        or string.format("%s %s -o %s %s", compiler, flags, outfile, infile)

    local diagnostics = vim.diagnostic.get(0, { severity = { vim.diagnostic.severity.ERROR } })

    if vim.tbl_isempty(diagnostics) then
        vim.cmd("!" .. cmd_compile)
        self.current_tick1 = vim.b.changedtick
        return true
    end

    self:goto_first_diagnostic(diagnostics)
    return false
end

function BuildTask:run()
    local outfile = config.config.output_directory .. vim.fn.expand("%:t:r")
    if self.current_tick1 == vim.b.changedtick or self:compile() then
        vim.cmd.terminal()
        vim.defer_fn(function()
            local out = outfile
            if self.data_file ~= nil then
                out = outfile .. " < " .. self.data_file
            end
            if vim.b.terminal_job_id then
                vim.api.nvim_chan_send(vim.b.terminal_job_id, out .. "\n")
            end
        end, 50)
    end
end

function BuildTask:show_assembly()
    local compiler = self:get_compiler()
    local flags = self:get_compile_flags(".compile_flags")
    local outfile = config.config.output_directory .. vim.fn.expand("%:t:r")
    local infile = vim.api.nvim_buf_get_name(0)
    local asm_file = outfile .. ".s"
    local cmd_assemble = config.config.assemble_command
                         or string.format("%s %s -S -o %s %s", compiler, flags, asm_file, infile)

    local diagnostics = vim.diagnostic.get(0, { severity = { vim.diagnostic.severity.ERROR } })

    if self.current_tick2 ~= vim.b.changedtick then
        if vim.tbl_isempty(diagnostics) then
            vim.cmd("silent! write")
            vim.fn.system(cmd_assemble)
            self.current_tick2 = vim.b.changedtick
        else
            self:goto_first_diagnostic(diagnostics)
            return
        end
    end

    require('mycompiler.assembly_view').open(asm_file)
end

function BuildTask:set_data_file(file)
    self.data_file = file
end

function BuildTask:get_data_file()
    return self.data_file
end

return {
    new = BuildTask.new,
}
