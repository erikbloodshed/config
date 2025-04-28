local Handler = {}
Handler.__index = Handler

function Handler.new()
    local self = setmetatable({}, Handler)
    self.data_file = nil
    return self
end

function Handler:run(exe)
    vim.cmd.terminal()
    vim.defer_fn(function()
        local command = exe
        if self.data_file ~= nil then
            command = exe .. " < " .. self.data_file
        end
        if vim.b.terminal_job_id then
            vim.api.nvim_chan_send(vim.b.terminal_job_id, command .. "\n")
        else
            vim.notify("Could not get terminal job ID to send command.", vim.log.levels.WARN)
        end
    end, 100)
end

function Handler:set_data_file(data)
    self.data_file = data
end

return {
    new = Handler.new,
}
