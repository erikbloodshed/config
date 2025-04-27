local utils = require("cpp-tools.utils")

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

function Handler:select_data_file(data_path)
    if not data_path then return end
    local base = data_path
    local files = utils.scan_dir(base)
    if vim.tbl_isempty(files) then
        vim.notify("No files found in data directory: " .. base, vim.log.levels.WARN)
        return
    end

    local prompt = 'Current: ' .. (self.data_file or 'None') .. '):'
    vim.ui.select(files, {
        prompt = prompt,
        format_item = function(item)
            return vim.fn.fnamemodify(item, ':t')
        end,
    }, function(choice)
        if choice then
            self.data_file = choice
            vim.notify("Data file set to: " .. vim.fn.fnamemodify(choice, ':t'), vim.log.levels.INFO)
        end
    end)
end

function Handler:remove_data_file()
    if self.data_file == nil then
        vim.notify("No data file is currently set.", vim.log.levels.WARN)
        return
    end

    vim.ui.select({ "Yes", "No" }, {
        prompt = "Remove data file (" .. vim.fn.fnamemodify(self.data_file, ':t') .. ")?",
    }, function(choice)
        if choice == "Yes" then
            self.data_file = nil
            vim.notify("Data file removed.", vim.log.levels.INFO)
        end
    end)
end

function Handler:get_data_file()
    return self.data_file
end

return {
    new = Handler.new,
}
