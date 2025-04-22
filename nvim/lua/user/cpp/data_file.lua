local file_util = require("user.utils.file")

local M = {}

function M.add(callback)
    local base = vim.fs.find("dat", {
        upward = true,
        type = "directory",
        path = vim.fn.expand("%:p:h"),
        stop = vim.fn.expand("~"),
    })[1]

    local files = file_util.scan_dir(base)
    if vim.tbl_isempty(files) then
        vim.notify("No files found in: " .. base, vim.log.levels.WARN)
        return
    end

    vim.ui.select(files, { prompt = "Select data input file:" }, function(choice)
        if choice then callback(choice) end
    end)
end

function M.remove(data, callback)
    if not data then
        vim.notify("No data file has been added.")
        return
    end
    vim.ui.select({ "Yes", "No" }, { prompt = "Remove data file for this source code?" }, function(choice)
        if choice == "Yes" then
            callback()
        end
    end)
end

return M
