--[[
Robust synchronous command execution for compilation using Neovim's libuv.
Runs an external command with arguments, waits for it to finish,
and captures its standard output and standard error.

This version focuses on improved error handling and resource cleanup
compared to the previous version, ensuring libuv handles are closed
even if errors occur during spawning or reading.

Parameters:
  cmd_and_args: table - A list where the first element is the command/executable
                       and subsequent elements are its arguments.
                       Example: {'g++', 'your_code.cpp', '-o', 'your_program'}
                       Example: {'clang++', 'source.cpp', '-Wall', '-std=c++17'}

Returns:
  table: A table containing the results:
    - code: integer | nil - The exit code of the command. Nil if terminated by signal.
    - stdout: string - The captured standard output.
    - stderr: string - The captured standard error.
    - error: string | nil - An error message if the function itself failed
                            (e.g., spawn error, read error, pipe error).
]]
local M = {}

-- Helper function to safely close a libuv handle.
-- Checks if the handle exists, is active, and not already closing before attempting to close.
-- Calls an optional callback after closure.
-- @param handle The libuv handle to close.
-- @param callback Optional function to call after the handle is closed.
local function safe_close_handle(handle, callback)
    if handle and vim.uv.is_active(handle) and not vim.uv.is_closing(handle) then
        -- Use pcall in case there's an unexpected issue during close,
        -- though uv.close itself is generally reliable on valid handles.
        pcall(vim.loop.close, handle, callback)
    elseif callback then
        -- If the handle isn't active or is already closing, call the callback immediately
        -- if one was provided, as it won't be called by uv.close.
        callback()
    end
end

-- Executes an external command asynchronously using libuv.
-- Returns only the exit code and any internal error message encountered during execution.
-- @param cmd_and_args A table where the first element is the command path
--                     and subsequent elements are arguments.
-- @return A table with keys:
--         - code (number|nil): The process exit code (0 for success, non-zero for error),
--                              or nil if terminated by a signal, or -1 for pre-execution errors.
--         - error (string|nil): An error message if an issue occurred within this
--                               function (e.g., spawn failed, pipe read error), otherwise nil.
function M.execute(cmd_and_args)
    local uv = vim.uv -- Get the libuv event loop handle from Neovim

    -- Validate input: must be a non-empty table
    if type(cmd_and_args) ~= 'table' or #cmd_and_args == 0 then
        return {
            error = "Invalid command format (expected non-empty table)",
            code = -1, -- Use -1 to indicate a function-level failure before execution
        }
    end

    local command_path = cmd_and_args[1]

    if vim.fn.executable(command_path) == 0 then
        return {
            error = "Command not found or not executable: " .. command_path,
            code = -1, -- Indicate failure before execution attempt
        }
    end

    local command_args = { unpack(cmd_and_args, 2) } -- Arguments from the second element onwards

    -- Setup pipes for standard input, output, and error
    -- These are required by uv.spawn stdio array, even if we discard the output.
    local stdin_pipe = uv.new_pipe(false)
    local stdout_pipe = uv.new_pipe(false)
    local stderr_pipe = uv.new_pipe(false)

    -- Variables to store process status and internal errors
    local exit_code = nil      -- Will hold the numeric exit code or nil if terminated by signal
    local internal_error = nil -- For errors within this function (spawn, pipe, read errors)

    -- Flags to track completion of asynchronous operations
    local process_exited = false
    local stdout_closed = false
    local stderr_closed = false
    local stdin_closed = false -- Track stdin pipe closure

    -- Declare process_handle here, it will be assigned the handle from uv.spawn
    local process_handle = nil

    -- Function to check if all necessary async operations are complete
    -- This determines when the uv.run() loop can stop.
    local function check_completion()
        -- All done when the process has exited AND all stdio pipes are closed.
        if process_exited and stdout_closed and stderr_closed and stdin_closed then
            -- Ensure the process handle is also closed before stopping the loop
            safe_close_handle(process_handle, function()
                -- Only stop the loop after the process handle is confirmed closed
                -- Check if the loop is still running before stopping
                if uv.loop_alive() then
                    uv.stop()
                end
            end)
        end
    end

    -- Callback function executed when the spawned process exits
    local on_exit = function(code)
        exit_code = code -- Capture the process exit code
        process_exited = true

        -- Attempt to close the stdio pipes now that the process is done.
        -- Use safe_close_handle which includes checks.
        safe_close_handle(stdout_pipe, function()
            stdout_closed = true; check_completion()
        end)
        safe_close_handle(stderr_pipe, function()
            stderr_closed = true; check_completion()
        end)
        -- Stdin should ideally already be closing/closed via the shutdown call below,
        -- but include it here as a safeguard.
        safe_close_handle(stdin_pipe, function()
            stdin_closed = true; check_completion()
        end)

        -- The process_handle is closed in check_completion after all pipes are closed.
        check_completion() -- Check completion state after updating flags
    end

    -- Callback function for reading data from standard output (data is ignored)
    local on_stdout_read = function(err, data)
        if err then
            -- Handle read errors on stdout
            internal_error = internal_error or ("Stdout read error: " .. err.message)
            stdout_closed = true -- Mark as closed due to error
            safe_close_handle(stdout_pipe, function() check_completion() end)
            return
        end

        if not data then -- data is nil, indicating End Of File (EOF)
            stdout_closed = true
            -- Close the stdout pipe now that we've read everything (or EOF reached)
            safe_close_handle(stdout_pipe, function() check_completion() end)
        end
        -- Ignore 'data' if it exists, we don't need to store it
    end

    -- Callback function for reading data from standard error (data is ignored)
    local on_stderr_read = function(err, data)
        if err then
            -- Handle read errors on stderr
            internal_error = internal_error or ("Stderr read error: " .. err.message)
            stderr_closed = true -- Mark as closed due to error
            safe_close_handle(stderr_pipe, function() check_completion() end)
            return
        end

        if not data then -- data is nil, indicating End Of File (EOF)
            stderr_closed = true
            -- Close the stderr pipe now that we've read everything (or EOF reached)
            safe_close_handle(stderr_pipe, function() check_completion() end)
        end
        -- Ignore 'data' if it exists, we don't need to store it
    end

    -- Configure options for spawning the process
    local spawn_options = {
        args = command_args,
        stdio = { stdin_pipe, stdout_pipe, stderr_pipe },
        -- Removed options: cwd, env, verbatim, detached, hide - keeping it simple
    }

    -- Spawn the external command
    local spawn_err
    process_handle, spawn_err = uv.spawn(command_path, spawn_options, on_exit)

    -- Check if spawning the process failed
    if not process_handle then
        local error_msg = "Failed to spawn process"
        if type(spawn_err) == 'string' then
            error_msg = error_msg .. ": " .. spawn_err
        else
            error_msg = error_msg .. ": " .. tostring(spawn_err)
        end
        internal_error = error_msg

        -- Ensure pipes are closed if spawn failed
        safe_close_handle(stdin_pipe)
        safe_close_handle(stdout_pipe)
        safe_close_handle(stderr_pipe)

        return {
            error = internal_error,
            code = -1, -- Indicate a failure before execution
        }
    end

    -- Spawn succeeded, process_handle is valid.

    -- Start reading (and discarding) data from standard output and standard error pipes
    local read_stdout_ok, read_stdout_err = pcall(uv.read_start, stdout_pipe, on_stdout_read)
    if not read_stdout_ok then
        internal_error = internal_error or ("Failed to start reading stdout: " .. tostring(read_stdout_err))
        stdout_closed = true -- Mark as logically closed due to error
        safe_close_handle(stdout_pipe, check_completion)
    end

    local read_stderr_ok, read_stderr_err = pcall(uv.read_start, stderr_pipe, on_stderr_read)
    if not read_stderr_ok then
        internal_error = internal_error or ("Failed to start reading stderr: " .. tostring(read_stderr_err))
        stderr_closed = true -- Mark as logically closed due to error
        safe_close_handle(stderr_pipe, check_completion)
    end

    -- Immediately shut down the stdin pipe as we don't send input.
    uv.shutdown(stdin_pipe, function(shutdown_err)
        if shutdown_err then
            internal_error = internal_error or ("Stdin shutdown error: " .. shutdown_err.message)
        end
        -- Even if shutdown fails, try closing the handle.
        -- Mark stdin as logically closed after shutdown attempt completes.
        stdin_closed = true
        safe_close_handle(stdin_pipe, check_completion)
    end)

    -- Run the libuv event loop until uv.stop() is called in check_completion.
    -- Use 'default' mode which blocks until stop() or no active handles remain.
    uv.run('default')

    -- After the loop finishes, perform final cleanup check (belt-and-suspenders)
    for _, handle in ipairs({ process_handle, stdin_pipe, stdout_pipe, stderr_pipe }) do
        safe_close_handle(handle) -- No callback needed here, loop is stopped
    end

    -- Return only the exit code and any internal error message
    return {
        code = exit_code,
        error = internal_error
    }
end

return M
