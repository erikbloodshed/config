local DataSelector = require("cpp-tools.data_selector")

local RunTask = {}
RunTask.__index = RunTask

function RunTask.new(config)
    local self = setmetatable({}, RunTask)
    self.config = config
    self.last_compiled_hash = nil
    self.data_file = nil
    self.data_selector_task = DataSelector.new(config)
    return self
end

function RunTask:run(last_compiled_hash)
    local outfile = self.config:get("output_directory") .. vim.fn.expand("%:t:r")
    local current_hash = self:get_buffer_hash() -- We need this method in RunTask or passed in

    if last_compiled_hash ~= current_hash then
        return false, "Compilation needed" -- Indicate compilation is required
    end

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
    return true
end

function RunTask:set_data_file(file)
    self.data_file = file
end

function RunTask:get_data_file()
    return self.data_file
end

-- We need to move get_buffer_hash here or pass the hash in
function RunTask:get_buffer_hash()
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
    local content = table.concat(lines, "\n")
    return vim.fn.sha256(content)
end

return {
    new = RunTask.new,
}
