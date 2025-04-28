local M = {}

M.scan_dir = function(dir)
    local handle = io.popen('find "' .. dir .. '" -type f 2>/dev/null')
    if not handle then
        vim.notify("Failed to scan directory: " .. dir, vim.log.levels.ERROR)
        return {}
    end
    local result = {}
    for file in handle:lines() do
        table.insert(result, file)
    end
    local ok, err = handle:close() -- Capture return values from handle:close()
    if not ok then
        vim.notify("Error closing file handle: " .. err, vim.log.levels.ERROR)
    end
    table.sort(result, function(a, b) return string.lower(a) < string.lower(b) end)
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
            return "@" .. path
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

    -- Final tweaks
    vim.bo[buf].modifiable = false
    vim.keymap.set("n", "q", vim.cmd.close, { buffer = buf, noremap = true, nowait = true, silent = true })

    return buf
end

function M.get_modified_time(filepath)
    local file_stats = vim.fn.getftime(filepath) -- `getftime` retrieves the file modification time
    if file_stats > 0 then
        return os.date("%Y-%B-%d %H:%M:%S", file_stats)
    else
        return "Unable to retrieve file modified time."
    end
end

-- function M.get_creation_time(file)
--     local handle = io.popen("stat -c %W " .. file)  -- %W gives the creation (birth) time
--     if not handle then return "Could not open " .. file end
--     local result = handle:read("*a")
--     handle:close()
--     local creation_time = tonumber(result)
--     if creation_time then
--         return os.date("%Y-%B-%d %H:%M:%S", creation_time)
--     else
--         return "Unable to retrieve file creation time."
--     end
-- end

--- Attempts to retrieve the creation (birth) time of a file using the 'stat' command.
-- WARNING: This method is highly dependent on the operating system and the filesystem.
-- The '%W' format specifier is specific to GNU stat (common on Linux) and requires
-- the filesystem to support recording the birth/creation time (e.g., ext4, XFS, Btrfs).
-- It will likely NOT work correctly on macOS, Windows, or Linux filesystems that
-- do not store creation time, potentially returning 0 or an error.
--
-- For a truly cross-platform solution, you would need to use OS-specific methods
-- (e.g., Windows API calls, macOS GetFileInfo) which are not directly available
-- in standard Lua and would require external libraries or different approaches.
--
-- @param file The path to the file.
-- @return A formatted date string representing the creation time if successful and supported,
--         or a descriptive error/status message otherwise.
function M.get_creation_time(file)
    -- Construct the command to get the birth time as a Unix timestamp.
    -- %W is for birth time (creation time) as seconds since Epoch (GNU stat).
    local command = "stat -c %W " .. file
    local handle = io.popen(command, "r") -- Open the pipe in read mode

    if not handle then
        -- io.popen failed to start the command. This could be due to permissions,
        -- command not found, or other system issues.
        return "Error: Could not execute stat command for file: " .. file
    end

    -- Read the entire output from the command.
    local result = handle:read("*a")

    -- Close the handle and capture the exit status of the command.
    -- The second return value from handle:close() is the exit status.
    local success, _, exit_code = pcall(handle.close, handle) -- Use pcall in case close fails

    if not success then
        -- Closing the handle failed, which is unusual but possible.
        return "Error: Failed to close stat command handle after execution."
    end

    -- Check the exit code of the stat command. A non-zero exit code
    -- usually means the command failed (e.g., file not found, invalid option).
    if exit_code ~= 0 then
        -- Trim output for cleaner error message, though result might be empty or contain error text
        local trimmed_result = result:gsub("^%s*(.-)%s*$", "%1")
        if trimmed_result == "" then
             return "Error: stat command failed (exit code " .. tostring(exit_code) .. "). File might not exist or command options unsupported."
        else
             return "Error: stat command failed (exit code " .. tostring(exit_code) .. "). Output: " .. trimmed_result
        end
    end

    -- Trim any leading/trailing whitespace from the successful output
    result = result:gsub("^%s*(.-)%s*$", "%1")

    -- Attempt to convert the result to a number (the timestamp).
    local creation_time = tonumber(result)

    if creation_time and creation_time > 0 then
        -- If conversion is successful and the timestamp is greater than 0,
        -- format and return the date. A timestamp of 0 often indicates
        -- that the birth time is not recorded on the filesystem.
        return os.date("%Y-%B-%d %H:%M:%S", creation_time)
    else
        -- If conversion failed (output wasn't a number) or the timestamp was 0.
        -- This indicates that stat -c %W did not provide a valid creation time.
        -- This is common on filesystems/OS where birth time is not supported or stored.
        return "Creation time not available or could not be retrieved for this file/filesystem using 'stat -c %W'."
    end
end
return M
