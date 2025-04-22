local M = {}

function M.scan_dir(dir)
    local handle = io.popen('find "' .. dir .. '" -type f 2>/dev/null')
    if not handle then return {} end
    local result = {}
    for file in handle:lines() do
        table.insert(result, file)
    end
    handle:close()
    return result
end

return M
