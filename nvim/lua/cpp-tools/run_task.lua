local RunTask = {}
RunTask.__index = RunTask

function RunTask.new(config)
    local self = setmetatable({}, RunTask)
    self.config = config
    self.data_file = nil
    return self
end

function RunTask:run(outfile)
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

function RunTask:set_data_file(file)
    self.data_file = file
end

function RunTask:get_data_file()
    return self.data_file
end

return {
    new = RunTask.new,
}
