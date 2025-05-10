local get_buffer_hash = function()
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
    local content = table.concat(lines, "\n")
    return vim.fn.sha256(content)
end

local M = {
    translate = function(value, key, cmd)
        local diagnostics = vim.diagnostic.get(0, { severity = { vim.diagnostic.severity.ERROR } })

        if #diagnostics == 0 then
            if vim.bo.modified then vim.cmd("silent! write") end
            local buffer_hash = get_buffer_hash()

            if value[key] ~= buffer_hash then
                local result = require("cpp-tools.process").execute(cmd)

                if result.code == 0 then
                    value[key] = buffer_hash
                    vim.notify("Code compilation successful with exit code " .. result.code .. ".",
                        vim.log.levels.INFO)
                    return true
                else
                    if result.stderr ~= nil then
                        vim.notify(result.stderr, vim.log.levels.ERROR)
                    end

                    return false
                end
            end

            vim.notify("Source code is already compiled.", vim.log.levels.WARN)
            return true
        end

        require("diagnostics").open_quickfixlist()
        return false
    end,

    run = function(exe, args, datfile)
        local command = exe

        if args then
            command = command .. " " .. args
        end

        if datfile then
            command = command .. " < " .. datfile
        end

        vim.cmd.terminal()

        vim.defer_fn(function()
            if vim.b.terminal_job_id then
                vim.api.nvim_chan_send(vim.b.terminal_job_id, command .. "\n")
            else
                vim.notify("Could not get terminal job ID to send command.", vim.log.levels.WARN)
            end
        end, 100)
    end
}

return M
