local utils = require("cpp-tools.utils")
local process = require("cpp-tools.process")
local notify = vim.notify
local diagnostic = vim.diagnostic
local ERROR = vim.log.levels.ERROR
local WARN = vim.log.levels.WARN

local M = {}

M.translate = function(value, key, cmd)
    local diagnostics = diagnostic.get(0, { severity = { vim.diagnostic.severity.ERROR } })

    if vim.tbl_isempty(diagnostics) then
        if vim.bo.modified then vim.cmd("silent! write") end
        local buffer_hash = utils.get_buffer_hash()

        if value[key] ~= buffer_hash then
            local obj = process.execute(cmd)

            if obj.code == 0 then
                value[key] = buffer_hash
                notify("Code compilation successful with exit code " .. obj.code .. ".",
                    vim.log.levels.INFO)
                return true
            else
                notify("Compilation failed: " .. obj.error .. ".", ERROR)
                return false
            end
        end

        notify("Source code is already compiled.", WARN)
        return true
    end

    utils.goto_first_diagnostic(diagnostics)
    return false
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
            notify("Could not get terminal job ID to send command.", WARN)
        end
    end, 100)
end

return M
