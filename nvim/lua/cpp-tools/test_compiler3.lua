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

--- Helper function to safely close a libuv handle.
-- Checks if the handle exists, is active, and not already closing before attempting to close.
-- Calls an optional callback after closure.
-- @param handle The libuv handle to close.
-- @param callback Optional function to call after the handle is closed.
local function safe_close_handle(handle, callback)
    if handle and vim.loop.is_active(handle) and not vim.loop.is_closing(handle) then
        -- Use pcall in case there's an unexpected issue during close,
        -- though uv.close itself is generally reliable on valid handles.
        pcall(vim.loop.close, handle, callback)
    elseif callback then
        -- If the handle isn't active or is already closing, call the callback immediately
        -- if one was provided, as it won't be called by uv.close.
        callback()
    end
end

function M.compiler(cmd_and_args)
    local uv = vim.loop -- Get the libuv event loop handle from Neovim

    -- Validate input: must be a non-empty table
    if type(cmd_and_args) ~= 'table' or #cmd_and_args == 0 then
        return {
            error = "Invalid command format (expected non-empty table)",
            code = -1, -- Use -1 to indicate a function-level failure before execution
            stdout = "",
            stderr = ""
        }
    end

    local command_path = cmd_and_args[1]
    -- Arguments can be passed directly from the second element onwards
    local command_args = { unpack(cmd_and_args, 2) }

    -- Setup pipes for standard input, output, and error
    -- Even if not used for input, stdin pipe is required by uv.spawn stdio array.
    local stdin_pipe = uv.new_pipe(false)
    local stdout_pipe = uv.new_pipe(false)
    local stderr_pipe = uv.new_pipe(false)

    -- Variables to store captured output and process status
    local stdout_chunks = {}
    local stderr_chunks = {}
    local exit_code = nil      -- Will hold the numeric exit code or nil if terminated by signal
    local internal_error = nil -- For errors within this function (spawn, pipe, read errors)
    local exit_signal = nil    -- Will hold the signal number if terminated by signal

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
                uv.stop()
            end)
        end
    end

    -- Callback function executed when the spawned process exits
    local on_exit = function(code, signal)
        exit_code = code     -- Capture the process exit code (0 for success, non-zero for error)
        exit_signal = signal -- Capture the signal number if terminated by signal

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
        -- but we include it here as a safeguard.
        safe_close_handle(stdin_pipe, function()
            stdin_closed = true; check_completion()
        end)

        -- The process_handle is closed in check_completion after all pipes are closed.
        check_completion() -- Check completion state after updating flags
    end

    -- Callback function for reading data from standard output
    local on_stdout_read = function(err, data)
        if err then
            -- Handle read errors on stdout
            internal_error = internal_error or ("Stdout read error: " .. err.message)
            -- Mark as closed due to error and attempt to close the pipe
            stdout_closed = true
            safe_close_handle(stdout_pipe, function() check_completion() end)
            return
        end

        if data then
            -- Append received data chunk to our list
            table.insert(stdout_chunks, data)
        else -- data is nil, indicating End Of File (EOF)
            stdout_closed = true
            -- Close the stdout pipe now that we've read everything
            safe_close_handle(stdout_pipe, function() check_completion() end)
        end
    end

    -- Callback function for reading data from standard error
    local on_stderr_read = function(err, data)
        if err then
            -- Handle read errors on stderr
            internal_error = internal_error or ("Stderr read error: " .. err.message)
            -- Mark as closed due to error and attempt to close the pipe
            stderr_closed = true
            safe_close_handle(stderr_pipe, function() check_completion() end)
            return
        end

        if data then
            -- Append received data chunk to our list
            table.insert(stderr_chunks, data)
        else -- data is nil, indicating End Of File (EOF)
            stderr_closed = true
            -- Close the stderr pipe now that we've read everything
            safe_close_handle(stderr_pipe, function() check_completion() end)
        end
    end

    -- Configure options for spawning the process
    local spawn_options = {
        args = command_args,
        -- Map stdio streams: stdin, stdout, stderr
        -- The pipes must be created BEFORE calling uv.spawn
        stdio = { stdin_pipe, stdout_pipe, stderr_pipe },
        -- Removed options: cwd, env, verbatim, detached, hide - keeping it simple
    }

    -- Spawn the external command
    -- uv.spawn returns a handle and PID on success, or nil and error on failure
    -- Assign the handle directly to the pre-declared process_handle variable
    local spawn_err
    process_handle, spawn_err = uv.spawn(command_path, spawn_options, on_exit)

    -- Check if spawning the process failed
    if not process_handle then
        -- Determine the error message from spawn_err (which should be a string)
        local error_msg = "Failed to spawn process"
        if type(spawn_err) == 'string' then
            error_msg = error_msg .. ": " .. spawn_err
        else
            -- Fallback for unexpected error types
            error_msg = error_msg .. ": " .. tostring(spawn_err)
        end
        internal_error = error_msg -- Record the internal error

        -- Crucially, ensure pipes are closed if spawn failed
        -- Use safe_close_handle with no callbacks as the loop won't run
        safe_close_handle(stdin_pipe)
        safe_close_handle(stdout_pipe)
        safe_close_handle(stderr_pipe)

        return {
            error = internal_error,
            code = -1, -- Indicate a failure before execution
            stdout = "",
            stderr = ""
        }
    end

    -- Spawn succeeded, process_handle is valid.

    -- Start reading data from standard output and standard error pipes
    -- Use pcall to catch errors if read_start itself fails (less common but possible)
    local read_stdout_ok, read_stdout_err = pcall(uv.read_start, stdout_pipe, on_stdout_read)
    if not read_stdout_ok then
        internal_error = internal_error or ("Failed to start reading stdout: " .. tostring(read_stdout_err))
        -- If read_start fails, mark the pipe as logically closed due to error
        stdout_closed = true
        -- Attempt to close the pipe handle
        safe_close_handle(stdout_pipe, check_completion)
    end

    local read_stderr_ok, read_stderr_err = pcall(uv.read_start, stderr_pipe, on_stderr_read)
    if not read_stderr_ok then
        internal_error = internal_error or ("Failed to start reading stderr: " .. tostring(read_stderr_err))
        -- If read_start fails, mark the pipe as logically closed due to error
        stderr_closed = true
        -- Attempt to close the pipe handle
        safe_close_handle(stderr_pipe, check_completion)
    end

    -- Since we don't need to send input for compilation,
    -- immediately shut down the stdin pipe. This signals EOF to the process
    -- if it were trying to read from stdin, and allows the pipe to close.
    uv.shutdown(stdin_pipe, function(shutdown_err)
        if shutdown_err then
            -- Record shutdown errors, but don't necessarily fail the whole operation
            -- unless it prevents the pipe from closing.
            internal_error = internal_error or ("Stdin shutdown error: " .. shutdown_err.message)
        end
        stdin_closed = true -- Mark stdin as closed after shutdown callback
        -- Now that shutdown is complete, attempt to close the stdin pipe handle.
        safe_close_handle(stdin_pipe, check_completion)
    end)

    -- Run the libuv event loop. This call blocks the current thread
    -- until uv.stop() is called from within one of the callbacks
    -- (specifically, check_completion, after all handles are closed).
    uv.run('default')

    -- After the loop finishes (meaning uv.stop() was called), collect the captured output
    local final_stdout = table.concat(stdout_chunks)
    local final_stderr = table.concat(stderr_chunks)

    -- Final check and cleanup: Although check_completion and safe_close_handle
    -- aim to close everything before uv.stop(), this is a belt-and-suspenders
    -- approach to ensure no handles are left dangling if the logic had a flaw
    -- or if uv.stop() was called prematurely by some external factor (unlikely
    -- in this isolated context, but good practice).
    -- We iterate through the handles and attempt to close any that are still active.
    for _, handle in ipairs({ process_handle, stdin_pipe, stdout_pipe, stderr_pipe }) do
        safe_close_handle(handle)  -- No callback needed here, loop is already stopped
    end

    -- Return the results
    return {
        code = exit_code,
        stdout = final_stdout,
        stderr = final_stderr,
        error = internal_error -- Reports errors from this function itself (e.g., spawn/read errors)
    }
end

return M
