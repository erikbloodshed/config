local M = {}

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

function M.add(data_folder_name, callback)
    local base = vim.fs.find(data_folder_name, {
        upward = true,
        type = "directory",
        path = vim.fn.expand("%:p:h"),
        stop = vim.fn.expand("~"),
    })[1]
    if not base then
        vim.notify("No data folder found", vim.log.levels.WARN)
        return
    end
    local files = scan_dir(base)
    if vim.tbl_isempty(files) then
        vim.notify("No files found in: " .. base, vim.log.levels.WARN)
        return
    end
    vim.ui.select(files, { prompt = 'Select data input file:' }, callback)
end

function M.remove(current_data, callback)
    if not current_data then
        vim.notify("No data file has been added.")
        return
    end
    vim.ui.select({ "Yes", "No" }, {
        prompt = "Remove current data file?",
    }, function(choice)
        if choice == "Yes" then
            callback()
        end
    end)
end

return M
