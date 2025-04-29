local utils = require("cpp-tools.utils")
-- local cpp_core = require("cpp-tools.cpp_core")
-- local compiler = require("cpp-tools.test_compiler")
-- local compiler = require("cpp-tools.test_compiler2")
local compiler = require("cpp-tools.test_compiler3")

local M = {}

M.compile = function(value, key, cmd)
    if vim.bo.modified then
        vim.cmd("silent! write")
    end

    local buffer_hash = utils.get_buffer_hash()

    if value[key] ~= buffer_hash then
        local diagnostics = vim.diagnostic.get(0, { severity = { vim.diagnostic.severity.ERROR } })

        -- local obj = cpp_core.system_sync(cmd)
        local obj = compiler.compiler(vim.split(cmd, " "))

        if not obj or obj.code == 0 then
            if not obj then
                print("It sucks!!!")
                return
            end
            value[key] = buffer_hash
            vim.notify("Source code compilation successful with exit code " .. obj.code .. ".",
                vim.log.levels.INFO)
            return true
        else
            vim.notify("Source code compilation failed with error code " .. obj.code .. ".", vim.log.levels.ERROR)
            return false
        end

        utils.goto_first_diagnostic(diagnostics)
        return false
    end

    vim.notify("Source code is already compiled.", vim.log.levels.WARN)
    return true
end

M.run = function(exe, data_file)
    vim.cmd.terminal()
    vim.defer_fn(function()
        local command = exe
        if data_file ~= nil then
            command = exe .. " < " .. data_file
        end
        if vim.b.terminal_job_id then
            vim.api.nvim_chan_send(vim.b.terminal_job_id, command .. "\n")
        else
            vim.notify("Could not get terminal job ID to send command.", vim.log.levels.WARN)
        end
    end, 100)
end

return M
