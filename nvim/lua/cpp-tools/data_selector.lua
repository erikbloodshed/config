local DataSelector = {}
DataSelector.__index = DataSelector

function DataSelector.new(config)
    local self = setmetatable({}, DataSelector)
    self.config = config
    return self
end

function DataSelector:add(task)
    local base = vim.fn.getcwd() .. "/" .. self.config:get("data_subdirectory")
    local files = require("cpp-tools.utils").scan_dir(base)
    if vim.tbl_isempty(files) then
        vim.notify("No files found in: " .. base, vim.log.levels.WARN)
        return
    end

    vim.ui.select(files, {
        prompt = 'Select data input file:',
    }, function(choice)
        if choice then
            task:set_data_file(choice)
        end
    end)
end

function DataSelector:remove(task)
    if task:get_data_file() == nil then
        vim.notify("No data file has been added.", vim.log.levels.WARN)  -- Use WARN level
        return
    end

    vim.ui.select({ "Yes", "No" }, {
        prompt = "Do you want to remove data file for this source code?",
    }, function(choice)
        if choice == "Yes" then
            task:set_data_file(nil)
            vim.notify("Data file has been removed.", vim.log.levels.INFO) -- Use INFO level
        end
    end)
end

return {
    new = DataSelector.new,
}
