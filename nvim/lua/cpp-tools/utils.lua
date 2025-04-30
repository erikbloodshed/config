local M = {}

M.scan_dir = function(dir)
    local result = {}

    -- Check if the initial directory exists and is a directory
    local stat = vim.uv.fs_stat(dir)
    if not stat or stat.type ~= "directory" then
        vim.notify("Data directory not found or is not a directory: " .. dir, vim.log.levels.WARN)
        return {} -- Return empty table if dir doesn't exist or isn't a directory
    end

    -- Use vim.fs.dir to get an iterator for the directory contents
    -- The second argument '{}' can be used for options (like filtering), but we'll filter manually.
    -- The third argument '{ depth = math.huge }' enables recursive scanning.
    local iter, err = vim.fs.dir(dir, {})

    if not iter then
        vim.notify("Failed to scan directory: " .. dir .. (err and (" (" .. err .. ")") or ""), vim.log.levels.ERROR)
        return {} -- Return empty table on error
    end

    -- Iterate through the directory entries provided by vim.fs.dir
    for path, entry_type in iter do
        -- Check if the entry is a file
        if entry_type == "file" then
            -- Construct the full path by joining the base directory and the relative path
            local full_path = vim.fs.joinpath(dir, path)
            table.insert(result, full_path)
        end
    end

    -- Sort the results alphabetically (case-insensitive)
    table.sort(result, function(a, b)
        return string.lower(a) < string.lower(b)
    end)

    return result
end

M.get_buffer_hash = function()
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
    local content = table.concat(lines, "\n")
    return vim.fn.sha256(content)
end

M.goto_first_diagnostic = function(diagnostics)
    if vim.tbl_isempty(diagnostics) then
        return
    end
    local diag = diagnostics[1]
    local col = diag.col
    local lnum = diag.lnum
    local buf_lines = vim.api.nvim_buf_line_count(0)
    lnum = math.min(lnum, buf_lines - 1)
    local line = vim.api.nvim_buf_get_lines(0, lnum, lnum + 1, false)[1] or ""
    col = math.min(col, #line)
    vim.api.nvim_win_set_cursor(0, { lnum + 1, col + 1 })
end

M.get_options_file = function(filename)
    if filename then
        local path = vim.fs.find(filename, {
            upward = true,
            type = "file",
            path = vim.fn.expand("%:p:h"),
            stop = vim.fn.expand("~"),
        })[1]

        if path then
            return { "@" .. path }
        end
    end

    return nil
end

M.get_data_path = function(filename)
    if filename then
        local path = vim.fs.find(filename, {
            upward = true,
            type = "directory",
            path = vim.fn.expand("%:p:h"),
            stop = vim.fn.expand("~"),
        })[1]
        return path
    end

    return nil
end

M.read_file = function(filepath)
    local f = io.open(filepath, "r")

    if not f then return nil, "Could not open file: " .. filepath end
    local content = {}
    for line in f:lines() do table.insert(content, line) end
    f:close()

    return content
end

M.open = function(title, lines, ft)
    local max_line_length = 0
    for _, line in ipairs(lines) do
        max_line_length = math.max(max_line_length, #line)
    end
    local width = math.min(max_line_length + 4, math.floor(vim.o.columns * 0.8))
    local height = math.min(#lines, math.floor(vim.o.lines * 0.8))

    local buf = vim.api.nvim_create_buf(false, true)

    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].swapfile = false
    vim.bo[buf].filetype = ft

    -- Fill buffer content
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

    -- Open floating window
    vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = width,
        height = height,
        row = (vim.o.lines - height) / 2,
        col = (vim.o.columns - width) / 2,
        style = "minimal",
        border = "rounded",
        title = title,
        title_pos = "center",
    })

    vim.bo[buf].modifiable = false
    vim.keymap.set("n", "q", vim.cmd.close, { buffer = buf, noremap = true, nowait = true, silent = true })

    return buf
end

function M.memoize(func)
    local cache = {}
    return function(arg)
        if cache[arg] == nil then
            cache[arg] = func(arg)
        end
        return cache[arg]
    end
end

function M.get_modified_time(filepath)
    local file_stats = vim.uv.fs_stat(filepath)
    if file_stats then
        return os.date("%Y-%B-%d %H:%M:%S", file_stats.mtime.sec)
    else
        return "Unable to retrieve file modified time."
    end
end

function M.flatten_tbl(table)
    if type(table) == "table" then
        return vim.iter(table):flatten():totable()
    else
        return {}
    end
end

return M
