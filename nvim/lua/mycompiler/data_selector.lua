local config = require('mycompiler.config')

local function scan_dir(dir)
    local handle = io.popen('find "' .. dir .. '" -type f 2>/dev/null')
    if not handle then return {} end
    local result = {}
    for file in handle:lines() do
        table.insert(result, file)
    end
    handle:close()
    return result
end

local function add(task)
    local base = vim.fn.getcwd() .. "/" .. config.config.data_subdirectory
    local files = scan_dir(base)
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

local function remove(task)
    if task:get_data_file() == nil then
        vim.notify("No data file has been added.")
        return
    end

    vim.ui.select({ "Yes", "No" }, {
        prompt = "Do you want to remove data file for this source code?",
    }, function(choice)
        if choice == "Yes" then
            task:set_data_file(nil)
            vim.notify("Data file has been removed.")
        end
    end)
end

return {
    add = add,
    remove = remove,
}
