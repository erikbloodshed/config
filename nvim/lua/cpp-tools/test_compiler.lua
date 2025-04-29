--[[
Simplified synchronous command execution for compilation.
Runs an external command (like a C++ compiler) with arguments,
waits for it to finish, and captures its standard output and standard error.

This version removes features not typically needed for basic compilation,
such as sending input, setting working directory, environment variables,
timeouts, or Windows-specific options.

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
    - error: string | nil - An error message if the function itself failed (e.g., spawn error).
]]
local M = {}

function M.compiler(cmd_and_args)
    local uv = vim.loop -- Get the libuv event loop handle from Neovim

    -- Validate input: must be a non-empty table
    if type(cmd_and_args) ~= 'table' or #cmd_and_args == 0 then
        return {
            error = "Invalid command format (expected non-empty table)",
            code = -1,
            stdout = "",
            stderr = ""
        }
    end

    local command_path = cmd_and_args[1]
    local command_args = {}
    -- Extract arguments starting from the second element
    for i = 2, #cmd_and_args do
        table.insert(command_args, cmd_and_args[i])
    end

    -- Setup pipes for standard input, output, and error
    -- We still need to set up stdin, even if we immediately close it,
    -- as uv.spawn expects stdio handles.
    local stdin_pipe = uv.new_pipe(false)
    local stdout_pipe = uv.new_pipe(false)
    local stderr_pipe = uv.new_pipe(false)

    -- Variables to store captured output and process status
    local stdout_chunks = {}
    local stderr_chunks = {}
    local exit_code = nil
    local internal_error = nil -- For errors within this function, not command stderr

    -- Flags to track completion of asynchronous operations
    local process_exited = false
    local stdout_closed = false
    local stderr_closed = false
    local stdin_closed = false -- Track stdin pipe closure

    local process_handle = nil -- Handle for the spawned process

    -- Function to check if all necessary async operations are complete
    -- This determines when the uv.run() loop can stop.
    local function check_completion()
        -- All done when the process has exited AND all stdio pipes are closed.
        if process_exited and stdout_closed and stderr_closed and stdin_closed then
            uv.stop() -- Stop the libuv event loop
        end
    end

    -- Callback function executed when the spawned process exits
    local on_exit = function(code, signal)
        exit_code = code -- Capture the process exit code
        -- signal is less relevant for typical compilation errors, we mainly care about 'code'
        process_exited = true

        -- Attempt to close the stdio pipes now that the process is done.
        -- Use pcall in case a pipe is already closing or closed.
        -- Call check_completion after each pipe closure to see if we can stop the loop.
        if stdout_pipe and uv.is_closing(stdout_pipe) == false then pcall(uv.close, stdout_pipe, function() stdout_closed = true; check_completion() end) else stdout_closed = true end
        if stderr_pipe and uv.is_closing(stderr_pipe) == false then pcall(uv.close, stderr_pipe, function() stderr_closed = true; check_completion() end) else stderr_closed = true end
        if stdin_pipe and uv.is_closing(stdin_pipe) == false then pcall(uv.close, stdin_pipe, function() stdin_closed = true; check_completion() end) else stdin_closed = true end

        -- Close the process handle itself after recording the exit status
        if process_handle and uv.is_closing(process_handle) == false then
             pcall(uv.close, process_handle, check_completion) -- Check completion after process handle closes
        else
            check_completion() -- Check immediately if handle is already closed/inactive
        end
    end

    -- Callback function for reading data from standard output
    local on_stdout_read = function(err, data)
        if err then
            -- Handle read errors on stdout
            internal_error = internal_error or ("Stdout read error: " .. err.message)
            -- Don't close the pipe here; let EOF or on_exit handle it.
            return
        end

        if data then
            -- Append received data chunk to our list
            table.insert(stdout_chunks, data)
        else -- data is nil, indicating End Of File (EOF)
            stdout_closed = true
            -- Close the stdout pipe now that we've read everything
             if stdout_pipe and uv.is_closing(stdout_pipe) == false then pcall(uv.close, stdout_pipe, check_completion) else check_completion() end
        end
    end

    -- Callback function for reading data from standard error
    local on_stderr_read = function(err, data)
        if err then
            -- Handle read errors on stderr
            internal_error = internal_error or ("Stderr read error: " .. err.message)
            -- Don't close the pipe here; let EOF or on_exit handle it.
            return
        end

        if data then
            -- Append received data chunk to our list
            table.insert(stderr_chunks, data)
        else -- data is nil, indicating End Of File (EOF)
            stderr_closed = true
            -- Close the stderr pipe now that we've read everything
            if stderr_pipe and uv.is_closing(stderr_pipe) == false then pcall(uv.close, stderr_pipe, check_completion) else check_completion() end
        end
    end

    -- Configure options for spawning the process
    local spawn_options = {
        args = command_args,
        -- Map stdio streams: stdin, stdout, stderr
        stdio = { stdin_pipe, stdout_pipe, stderr_pipe },
        -- Removed options: cwd, env, verbatim, detached, hide
    }

    -- Spawn the external command
    local spawn_ok, handle_or_err = pcall(uv.spawn, command_path, spawn_options, on_exit)

    -- Check if spawning the process failed
    if not spawn_ok then
        -- Ensure pipes are closed if spawn failed
        pcall(uv.close, stdin_pipe)
        pcall(uv.close, stdout_pipe)
        pcall(uv.close, stderr_pipe)
        return {
            error = "Failed to spawn process: " .. tostring(handle_or_err),
            code = -1,
            stdout = "",
            stderr = ""
        }
    end

    -- Spawn succeeded, get the process handle
    process_handle = handle_or_err[1]
    -- local pid = handle_or_err[2] -- PID is not needed for this simplified version

    -- Start reading data from standard output and standard error pipes
    local read_stdout_ok, read_stdout_err = pcall(uv.read_start, stdout_pipe, on_stdout_read)
    if not read_stdout_ok then
        internal_error = internal_error or ("Failed to start reading stdout: " .. tostring(read_stdout_err))
        stdout_closed = true -- Mark as closed due to error
        if stdout_pipe and uv.is_closing(stdout_pipe) == false then pcall(uv.close, stdout_pipe, check_completion) end
    end

    local read_stderr_ok, read_stderr_err = pcall(uv.read_start, stderr_pipe, on_stderr_read)
    if not read_stderr_ok then
        internal_error = internal_error or ("Failed to start reading stderr: " .. tostring(read_stderr_err))
        stderr_closed = true -- Mark as closed due to error
        if stderr_pipe and uv.is_closing(stderr_pipe) == false then pcall(uv.close, stderr_pipe, check_completion) end
    end

    -- Since we don't need to send input for compilation,
    -- immediately shut down and close the stdin pipe.
    uv.shutdown(stdin_pipe, function(shutdown_err)
        if shutdown_err then
             internal_error = internal_error or ("Stdin shutdown error: " .. shutdown_err.message)
        end
        stdin_closed = true -- Mark stdin as closed
         if stdin_pipe and uv.is_closing(stdin_pipe) == false then pcall(uv.close, stdin_pipe, check_completion) else check_completion() end
    end)


    -- Run the libuv event loop. This call blocks until uv.stop() is called
    -- from within one of the callbacks (specifically, check_completion).
    uv.run('default')

    -- After the loop finishes, collect the captured output
    local final_stdout = table.concat(stdout_chunks)
    local final_stderr = table.concat(stderr_chunks)

    -- Final safeguard: ensure all handles are closed in case the loop
    -- exited unexpectedly before check_completion could close everything.
     for _, handle in ipairs({ stdout_pipe, stderr_pipe, stdin_pipe, process_handle }) do
         if handle and uv.is_active(handle) and uv.is_closing(handle) == false then
             pcall(uv.close, handle) -- Attempt to close the handle
         end
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

