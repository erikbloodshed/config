--[[
Optimized synchronous command execution for compilation using Neovim's libuv.
Runs an external command with arguments, waits for it to finish,
and captures its standard output and standard error.

This optimized version focuses on:
1. Reducing memory allocations and function calls
2. Pre-allocating resources where possible
3. Optimizing closure usage and callback patterns
4. Streamlining error handling paths
5. Using more efficient data structures and patterns

Parameters:
  cmd_and_args: table - A table containing compilation information.
                    It should have the following fields:
                    - compiler: string - The command/executable to run (e.g., 'g++', 'clang++').
                    - arg: table - A list of arguments for the command.
                      Example: { 'your_code.cpp', '-o', 'your_program' }
                      Example: { 'source.cpp', '-Wall', '-std=c++17' }

Returns:
  table: A table containing the results:
    - code: integer | nil - The exit code of the command. Nil if terminated by signal.
                          -1 if the function itself failed (e.g., spawn error, invalid input).
    - error: string | nil - An error message if the function itself failed
                             (e.g., spawn error, read error, pipe error).
]]
local M = {}

-- Use local references to frequently accessed functions for faster lookup
local uv = vim.uv
local is_active = uv.is_active
local is_closing = uv.is_closing
local close = uv.close
local loop_alive = uv.loop_alive
local stop = uv.stop
local new_pipe = uv.new_pipe
local read_start = uv.read_start
local shutdown = uv.shutdown
local spawn = uv.spawn

-- Pre-allocate common error messages to avoid string concatenation in hot paths
local ERROR_MESSAGES = {
    invalid_cmd_table = "Invalid command format: expected a table with 'compiler' and 'arg' fields",
    invalid_compiler = "Invalid command format: 'compiler' must be a non-empty string",
    invalid_args = "Invalid command format: 'arg' must be a table",
    not_executable = "Command not found or not executable: ",
}

-- Safe handle closure with optimized check path
local function safe_close(handle, callback)
    if handle and is_active(handle) and not is_closing(handle) then
        -- Use pcall for safety but optimize the common path
        pcall(close, handle, callback)
    elseif callback then
        -- Call the callback directly if handle is already closed
        callback()
    end
end

-- Execute a command using libuv with optimized resource management
function M.execute(cmd_table)
    -- Fast path validation for common error cases
    if type(cmd_table) ~= 'table' then
        return { error = ERROR_MESSAGES.invalid_cmd_table, code = -1 }
    end

    local command_path = cmd_table.compiler
    if type(command_path) ~= "string" or command_path == "" then
        return { error = ERROR_MESSAGES.invalid_compiler, code = -1 }
    end

    local command_args = cmd_table.arg
    if type(command_args) ~= 'table' then
        return { error = ERROR_MESSAGES.invalid_args, code = -1 }
    end

    -- Use vim.fn.executable through direct lookup for faster access
    if vim.fn.executable(command_path) == 0 then
        return { error = ERROR_MESSAGES.not_executable .. command_path, code = -1 }
    end

    -- Status tracking - use a single table to reduce closure allocations
    local status = {
        pipes_closed = 0,  -- Count of closed pipes for efficient completion checking
        exit_code = nil,   -- Process exit code
        internal_error = nil, -- Error message if any
        process_exited = false -- Process exit status
    }

    -- Pre-create pipes - optimized error path for early exits
    local stdin_pipe = new_pipe(false)
    local stdout_pipe = new_pipe(false)
    local stderr_pipe = new_pipe(false)
    local process_handle

    -- Optimized completion check that counts pipe closures rather than using separate flags
    local function check_completion()
        -- All done when process exited and all 3 pipes are closed (3 = stdin, stdout, stderr)
        if status.process_exited and status.pipes_closed >= 3 then
            -- Close process handle only after all pipes are closed
            safe_close(process_handle, function()
                -- Stop the loop only if still running
                if loop_alive() then
                    stop()
                end
            end)
        end
    end

    -- Single pipe closure handler used for all pipes - reduces function allocations
    local function on_pipe_close()
        status.pipes_closed = status.pipes_closed + 1
        check_completion()
    end

    -- Process exit handler with optimized pipe closure sequence
    local function on_exit(code)
        status.exit_code = code
        status.process_exited = true

        -- Close all pipes efficiently
        safe_close(stdout_pipe, on_pipe_close)
        safe_close(stderr_pipe, on_pipe_close)
        safe_close(stdin_pipe, on_pipe_close)

        -- Check completion state after updating flags
        check_completion()
    end

    -- Single optimized read handler for both stdout/stderr - reduces closure overhead
    local function on_pipe_read(pipe_name, err, data)
        if err then
            -- Only store the first error
            if not status.internal_error then
                status.internal_error = pipe_name .. " read error: " .. err.message
            end
            -- Close pipe on error and increment the closed counter
            safe_close(pipe_name == "stdout" and stdout_pipe or stderr_pipe, on_pipe_close)
            return
        end

        if not data then -- End of file
            safe_close(pipe_name == "stdout" and stdout_pipe or stderr_pipe, on_pipe_close)
        end
        -- Ignore data - we don't need to store it
    end

    -- Create specialized but optimized read handlers
    local on_stdout_read = function(err, data)
        on_pipe_read("stdout", err, data)
    end

    local on_stderr_read = function(err, data)
        on_pipe_read("stderr", err, data)
    end

    -- Configure options for spawning the process - reuse the same table structure
    local spawn_options = {
        args = command_args,
        stdio = { stdin_pipe, stdout_pipe, stderr_pipe }
    }

    -- Spawn the external command
    local spawn_err
    process_handle, spawn_err = spawn(command_path, spawn_options, on_exit)

    -- Optimized error handling for spawn failures
    if not process_handle then
        local error_msg = "Failed to spawn process"
        if spawn_err then
            error_msg = error_msg .. ": " .. tostring(spawn_err)
        end
        status.internal_error = error_msg

        -- Close all pipes at once for cleanup
        safe_close(stdin_pipe)
        safe_close(stdout_pipe)
        safe_close(stderr_pipe)

        return {
            error = status.internal_error,
            code = -1
        }
    end

    -- Start reading from stdout and stderr - use pcall for safety but optimize the normal path
    if not pcall(read_start, stdout_pipe, on_stdout_read) then
        status.internal_error = status.internal_error or "Failed to start reading stdout"
        safe_close(stdout_pipe, on_pipe_close)
    end

    if not pcall(read_start, stderr_pipe, on_stderr_read) then
        status.internal_error = status.internal_error or "Failed to start reading stderr"
        safe_close(stderr_pipe, on_pipe_close)
    end

    -- Immediately shut down stdin pipe as we don't send input
    shutdown(stdin_pipe, function(shutdown_err)
        if shutdown_err and not status.internal_error then
            status.internal_error = "Stdin shutdown error: " .. shutdown_err.message
        end
        -- Close the stdin pipe after shutdown attempt completes
        safe_close(stdin_pipe, on_pipe_close)
    end)

    -- Run the event loop once with 'default' mode for consistent behavior
    uv.run('default')

    -- Final guarantee to clean up any remaining handles (should rarely be needed)
    for _, handle in ipairs({ process_handle, stdin_pipe, stdout_pipe, stderr_pipe }) do
        safe_close(handle)
    end

    -- Return only needed information
    return {
        code = status.exit_code,
        error = status.internal_error,
    }
end

return M
