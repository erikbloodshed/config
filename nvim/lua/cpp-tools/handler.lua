local utils = require("cpp-tools.utils")

local M = {}

M.compile = function(value, key, cmd)
    if vim.bo.modified then
        vim.cmd("silent! write")
    end
    local buffer_hash = utils.get_buffer_hash()
    if value[key] ~= buffer_hash then
        local diagnostics = vim.diagnostic.get(0, { severity = { vim.diagnostic.severity.ERROR } })

        if vim.tbl_isempty(diagnostics) then
            vim.fn.system(cmd)
            value[key] = buffer_hash
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
