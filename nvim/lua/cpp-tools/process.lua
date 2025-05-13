--[[
Optimized synchronous command execution for compilation using Neovim's libuv.
Runs an external command with arguments, waits for it to finish,
and captures its exit code and standard error.

This optimized version returns only the error code and stderr with improved
resource management and memory efficiency.

Parameters:
  cmd_table: table - A table containing compilation information.
                    It should have the following fields:
                    - compiler: string - The command/executable to run (e.g., 'g++', 'clang++').
                    - arg: table - A list of arguments for the command.

Returns:
  table: A table containing the results:
    - code: integer | nil - The exit code of the command. Nil if terminated by signal.
                          -1 if the function itself failed (e.g., spawn error, invalid input).
    - stderr: string - The standard error output of the command (if any).
]]
local uv = vim.uv

-- Pre-allocate common error messages for better memory efficiency
local ERROR_MESSAGES = {
    invalid_cmd_table = "Invalid command format: expected a table with 'compiler' and 'arg' fields",
    invalid_compiler = "Invalid command format: 'compiler' must be a non-empty string",
    invalid_args = "Invalid command format: 'arg' must be a table",
    not_executable = "Command not found or not executable: ",
}

-- Safe handle closure with improved error handling
local function safe_close(handle, callback)
    if not handle then
        if callback then callback() end
        return
    end

    if uv.is_closing(handle) then
        if callback then callback() end
        return
    end

    -- Use protected call to handle potential errors
    pcall(uv.close, handle, callback or function() end)
end

-- Execute a command using libuv
local M = {}

function M.execute(cmd_table)
    -- Fast path validation with early returns
    if type(cmd_table) ~= 'table' then
        return { code = -1, stderr = ERROR_MESSAGES.invalid_cmd_table }
    end

    local command_path = cmd_table.compiler
    if type(command_path) ~= "string" or command_path == "" then
        return { code = -1, stderr = ERROR_MESSAGES.invalid_compiler }
    end

    local command_args = cmd_table.arg
    if type(command_args) ~= 'table' then
        return { code = -1, stderr = ERROR_MESSAGES.invalid_args }
    end

    -- Check if command is executable early to avoid unnecessary setup
    if vim.fn.executable(command_path) == 0 then
        return { code = -1, stderr = ERROR_MESSAGES.not_executable .. command_path }
    end

    -- Use a local result table to store the command execution results
    local result = {
        code = -1,
        stderr = ""
    }

    -- Use a single status table to track everything
    local status = {
        pending_closures = 2, -- stdin + stderr
        process_exited = false,
        stderr_builder = {},  -- Use a table for efficient string building
    }

    -- Used to track if we've already completed
    local completed = false

    -- Completion function to finalize results and clean up
    local function complete()
        if completed then return end
        completed = true

        -- Build final stderr output efficiently
        local stderr_content = table.concat(status.stderr_builder)

        result.stderr = stderr_content

        -- Make sure to stop the event loop
        if uv.loop_alive() then
            uv.stop()
        end
    end

    -- Create necessary pipes
    local stdin_pipe = uv.new_pipe(false)
    local stderr_pipe = uv.new_pipe(false)
    local process_handle

    -- Simplified pipe closure handler
    local function on_pipe_close()
        status.pending_closures = status.pending_closures - 1

        -- If all pipes are closed and process has exited, complete
        if status.pending_closures <= 0 and status.process_exited then
            complete()
        end
    end

    -- Process exit handler
    local function on_exit(code)
        result.code = code -- Store exit code in the result
        status.process_exited = true

        -- Close remaining pipes in case they haven't been closed yet
        safe_close(stderr_pipe, on_pipe_close)
        safe_close(stdin_pipe, on_pipe_close)

        -- If pipes are already closed, complete now
        if status.pending_closures <= 0 then
            complete()
        end

        -- Ensure process handle is closed
        safe_close(process_handle)
    end

    -- Optimized stderr reader
    local function on_stderr_read(err, data)
        if err then
            -- On read error, prepend error to stderr
            status.stderr_builder[#status.stderr_builder + 1] = "stderr read error: " .. tostring(err)
            safe_close(stderr_pipe, on_pipe_close)
            return
        end

        if data then
            -- Append data directly to the builder table
            status.stderr_builder[#status.stderr_builder + 1] = data
        else
            -- EOF reached, close the pipe
            safe_close(stderr_pipe, on_pipe_close)
        end
    end

    -- Spawn the process with optimized options
    local spawn_options = {
        args = command_args,
        stdio = { stdin_pipe, nil, stderr_pipe } -- No stdout pipe needed
    }

    local spawn_err
    process_handle, spawn_err = uv.spawn(command_path, spawn_options, on_exit)

    -- Handle spawn failures efficiently
    if not process_handle then
        local error_message = "Failed to spawn process: " .. (spawn_err or "unknown error")

        -- Clean up resources
        safe_close(stdin_pipe)
        safe_close(stderr_pipe)

        return {
            code = -1,
            stderr = error_message
        }
    end

    -- Start reading stderr
    local read_start_ok, read_err = pcall(uv.read_start, stderr_pipe, on_stderr_read)
    if not read_start_ok then
        status.stderr_builder[#status.stderr_builder + 1] = "Failed to start reading stderr: " .. tostring(read_err)
        safe_close(stderr_pipe, on_pipe_close)
    end

    -- Close stdin immediately (we don't write to it)
    safe_close(stdin_pipe, on_pipe_close)

    -- Set a timeout to prevent hanging indefinitely (5 seconds)
    local timeout_timer = uv.new_timer()
    if timeout_timer then
        uv.timer_start(timeout_timer, 5000, 0, function()
            if not completed then
                status.stderr_builder[#status.stderr_builder + 1] = "\nProcess timed out after 5 seconds"
                -- Force process termination
                if process_handle and not uv.is_closing(process_handle) then
                    pcall(uv.process_kill, process_handle, 15) -- SIGTERM
                end
                complete()
            end
            safe_close(timeout_timer)
        end)
    end

    -- Run the event loop
    uv.run()

    -- Clean up the timer if still active
    safe_close(timeout_timer)

    -- Always make sure we return something
    return result
end

return M
