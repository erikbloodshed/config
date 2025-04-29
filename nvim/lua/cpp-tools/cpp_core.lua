--[[
vim.system_sync(cmd, options)

Provides a synchronous interface similar to vim.system() but built
on the asynchronous vim.loop.spawn (libuv).

Runs an external command, waits for it to finish, captures its output,
and returns the results.

Parameters:
  cmd: string | table
    - If string: The command and arguments as a single string.
                 WARNING: Simple space-splitting is used, which may fail
                 for arguments containing spaces or requiring complex quoting.
                 Using a table is generally safer. Example: "ls -l /tmp"
    - If table: A list where the first element is the command/executable
                and subsequent elements are its arguments.
                Example: {'ls', '-l', '/tmp'}
  options: table (optional) - A table containing zero or more of the following:
    - input: string - Text to be written to the command's standard input.
    - cwd: string - The working directory to run the command in. Defaults to
                     the current directory if nil.
    - env: table - Environment variables for the child process as a table
                   of key-value pairs (e.g., {VAR1 = "value1", VAR2 = "value2"}).
                   If provided, this *replaces* the parent's environment entirely
                   for the child. To inherit and modify, first get
                   vim.loop.os_environ(), modify it, then pass the result here.
                   If nil, the child inherits the parent's environment.
    - timeout: integer (milliseconds) - Maximum time to allow the command to run.
                 If the command exceeds this time, it will be terminated (SIGTERM),
                 and an error will be included in the result. Defaults to no timeout.
    - verbatim_args: boolean - (Windows only) If true, pass arguments directly
                       without quoting or escaping. Ignored on non-Windows.
                       Corresponds to uv.spawn options.verbatim.
    - detached: boolean - If true, run the process detached (becomes group leader).
                       See uv.spawn options.detached. Defaults to false.
    - hide_window: boolean - (Windows only) If true, hide the console window.
                       Corresponds to uv.spawn options.hide. Ignored on non-Windows.

Returns:
  table: A table containing the results:
    - code: integer | nil - The exit code of the command. Nil if terminated by signal or timeout.
    - signal: integer - The signal number that terminated the process (usually 0
                       if the process exited normally). May be non-zero if killed
                       by a signal (e.g., due to timeout).
    - stdout: string - The captured standard output. Lines are typically terminated
                       by '\n'.
    - stderr: string - The captured standard error. Lines are typically terminated
                       by '\n'.
    - error: string | nil - An error message if the function itself failed (e.g.,
                       timeout, spawn error, I/O error). Nil on success.

Example Usage:
  local result = vim.system_sync({'echo', 'hello world'})
  print(vim.inspect(result))
  -- Expected: { code = 0, signal = 0, stdout = "hello world\n", stderr = "", error = nil }

  local result_input = vim.system_sync({'cat'}, { input = "some data" })
  print(vim.inspect(result_input))
  -- Expected: { code = 0, signal = 0, stdout = "some data", stderr = "", error = nil }

  local result_err = vim.system_sync({'sh', '-c', 'echo "to stderr" >&2 && exit 1'})
  print(vim.inspect(result_err))
  -- Expected: { code = 1, signal = 0, stdout = "", stderr = "to stderr\n", error = nil }

  local result_timeout = vim.system_sync({'sleep', '5'}, { timeout = 1000 })
  print(vim.inspect(result_timeout))
  -- Expected: { code = nil, signal = 15, stdout = "", stderr = "", error = "Command timed out" } -- Signal might vary
]]
local M = {}
function M.system_sync(cmd, options)
    local uv = vim.loop -- Get the libuv event loop handle from Neovim

    -- 1. Process arguments and options
    options = options or {}
    local input_text = options.input
    local cwd = options.cwd
    local env_vars = options.env
    local timeout_ms = options.timeout
    local verbatim_args = options.verbatim_args -- Windows specific
    local detached = options.detached
    local hide_window = options.hide_window   -- Windows specific

    local command_path
    local command_args

    if type(cmd) == 'string' then
        -- Basic parsing: split by space. Fails with quoted arguments. Use table form for safety.
        local parts = {}
        for part in string.gmatch(cmd, "[^%s]+") do
            table.insert(parts, part)
        end
        if #parts == 0 then
            return { error = "Empty command string", code = -1, signal = 0, stdout = "", stderr = "" }
        end
        command_path = parts[1]
        command_args = {}
        for i = 2, #parts do
            table.insert(command_args, parts[i])
        end
    elseif type(cmd) == 'table' then
        if #cmd == 0 then
            return { error = "Empty command table", code = -1, signal = 0, stdout = "", stderr = "" }
        end
        command_path = cmd[1]
        command_args = {}
        for i = 2, #cmd do
            table.insert(command_args, cmd[i])
        end
    else
        return { error = "Invalid command type (expected string or table)", code = -1, signal = 0, stdout = "", stderr =
        "" }
    end

    -- 2. Prepare state variables and handles
    local stdin_pipe = uv.new_pipe(false) -- false = not IPC pipe
    local stdout_pipe = uv.new_pipe(false)
    local stderr_pipe = uv.new_pipe(false)

    local stdout_chunks = {}
    local stderr_chunks = {}
    local exit_code = nil
    local exit_signal = nil
    local internal_error = nil -- Stores errors from this function, not the command's stderr
    local timed_out = false

    local process_handle = nil
    local pid = nil
    local timer_handle = nil

    -- Flags to track async completion
    local stdin_closed = false
    local stdout_closed = false
    local stderr_closed = false
    local process_exited = false

    -- 3. Define Core Callbacks

    -- Function to check if all async operations are complete
    local function check_completion()
        if process_exited and stdin_closed and stdout_closed and stderr_closed then
            -- Stop the timer if it's still active (process finished before timeout)
            if timer_handle and uv.is_active(timer_handle) then
                uv.timer_stop(timer_handle)                           -- Stop it first
                if uv.is_active(timer_handle) then                    -- Check again as stop might be async? Close it.
                    uv.close(timer_handle, function() timer_handle = nil end) -- Ensure timer handle is closed
                else
                    timer_handle = nil
                end
            end
            -- Stop the event loop, allowing uv.run() to return
            uv.stop()
        end
    end

    -- Callback for when the process exits
    local on_exit = function(code, signal)
        -- vim.notify("Process exited. Code: " .. tostring(code) .. ", Signal: " .. tostring(signal), vim.log.levels.DEBUG)
        exit_code = code
        exit_signal = signal
        process_exited = true

        -- Attempt to close pipes if they weren't already closed by EOF.
        -- This handles cases where the process exits abruptly.
        -- Use pcall as closing might fail if already closing/closed.
        if stdout_pipe and uv.is_closing(stdout_pipe) == false then pcall(uv.close, stdout_pipe,
                function()
                    stdout_closed = true; check_completion()
                end) else stdout_closed = true end
        if stderr_pipe and uv.is_closing(stderr_pipe) == false then pcall(uv.close, stderr_pipe,
                function()
                    stderr_closed = true; check_completion()
                end) else stderr_closed = true end
        if stdin_pipe and uv.is_closing(stdin_pipe) == false then pcall(uv.close, stdin_pipe,
                function()
                    stdin_closed = true; check_completion()
                end) else stdin_closed = true end

        -- Close the process handle itself *after* recording exit status
        if process_handle and uv.is_closing(process_handle) == false then
            pcall(uv.close, process_handle, check_completion) -- Check completion after process handle closes
        else
            check_completion()                            -- Check immediately if handle is already closed/inactive
        end
    end

    -- Callback for reading stdout data
    local on_stdout_read = function(err, data)
        if err then
            -- vim.notify("Stdout read error: " .. err.message, vim.log.levels.WARN)
            internal_error = internal_error or ("Stdout read error: " .. err.message)
            -- Don't close pipe here, let EOF or on_exit handle it
            return -- Stop processing this callback
        end

        if data then
            -- vim.notify("Stdout data received: " .. #data .. " bytes", vim.log.levels.DEBUG)
            table.insert(stdout_chunks, data)
        else -- data is nil, meaning End Of File (EOF)
            -- vim.notify("Stdout EOF", vim.log.levels.DEBUG)
            stdout_closed = true
            if stdout_pipe and uv.is_closing(stdout_pipe) == false then
                pcall(uv.close, stdout_pipe, check_completion) -- Close the pipe now that we've read everything
            else
                check_completion()                       -- Check completion if already closing/closed
            end
        end
    end

    -- Callback for reading stderr data
    local on_stderr_read = function(err, data)
        if err then
            -- vim.notify("Stderr read error: " .. err.message, vim.log.levels.WARN)
            internal_error = internal_error or ("Stderr read error: " .. err.message)
            -- Don't close pipe here, let EOF or on_exit handle it
            return -- Stop processing this callback
        end

        if data then
            -- vim.notify("Stderr data received: " .. #data .. " bytes", vim.log.levels.DEBUG)
            table.insert(stderr_chunks, data)
        else -- data is nil, meaning End Of File (EOF)
            -- vim.notify("Stderr EOF", vim.log.levels.DEBUG)
            stderr_closed = true
            if stderr_pipe and uv.is_closing(stderr_pipe) == false then
                pcall(uv.close, stderr_pipe, check_completion) -- Close the pipe now that we've read everything
            else
                check_completion()                       -- Check completion if already closing/closed
            end
        end
    end

    -- 4. Configure Spawn Options
    local spawn_options = {
        args = command_args,
        stdio = { stdin_pipe, stdout_pipe, stderr_pipe },
        cwd = cwd,
        env = env_vars,
        verbatim = verbatim_args,
        detached = detached,
        hide = hide_window,
    }

    -- 5. Spawn the Process
    local spawn_ok, handle_or_err = pcall(uv.spawn, command_path, spawn_options, on_exit)

    if not spawn_ok then
        -- vim.notify("Failed to spawn process: " .. tostring(handle_or_err), vim.log.levels.ERROR)
        -- Ensure pipes created are closed on spawn failure
        pcall(uv.close, stdin_pipe)
        pcall(uv.close, stdout_pipe)
        pcall(uv.close, stderr_pipe)
        return { error = "Failed to spawn process: " .. tostring(handle_or_err), code = -1, signal = 0, stdout = "", stderr =
        "" }
    end

    -- Spawn succeeded, unpack the handle and pid
    process_handle = handle_or_err[1]
    pid = handle_or_err[2]
    -- vim.notify("Process spawned. PID: " .. pid, vim.log.levels.DEBUG)

    -- 6. Start Reading Output
    local read_stdout_ok, read_stdout_err = pcall(uv.read_start, stdout_pipe, on_stdout_read)
    if not read_stdout_ok then
        internal_error = internal_error or ("Failed to start reading stdout: " .. tostring(read_stdout_err))
        -- vim.notify(internal_error, vim.log.levels.WARN)
        -- Attempt to close the problematic pipe
        stdout_closed = true
        if stdout_pipe and uv.is_closing(stdout_pipe) == false then pcall(uv.close, stdout_pipe, check_completion) end
    end

    local read_stderr_ok, read_stderr_err = pcall(uv.read_start, stderr_pipe, on_stderr_read)
    if not read_stderr_ok then
        internal_error = internal_error or ("Failed to start reading stderr: " .. tostring(read_stderr_err))
        -- vim.notify(internal_error, vim.log.levels.WARN)
        -- Attempt to close the problematic pipe
        stderr_closed = true
        if stderr_pipe and uv.is_closing(stderr_pipe) == false then pcall(uv.close, stderr_pipe, check_completion) end
    end

    -- 7. Write Input and Close Stdin
    if input_text and #input_text > 0 then
        uv.write(stdin_pipe, input_text, function(write_err)
            if write_err then
                -- vim.notify("Stdin write error: " .. write_err.message, vim.log.levels.WARN)
                internal_error = internal_error or ("Stdin write error: " .. write_err.message)
                -- Even on write error, try to shutdown/close
            end
            -- After writing (or attempting to), shutdown the write end of the pipe
            uv.shutdown(stdin_pipe, function(shutdown_err)
                if shutdown_err then
                    -- vim.notify("Stdin shutdown error: " .. shutdown_err.message, vim.log.levels.WARN)
                    internal_error = internal_error or ("Stdin shutdown error: " .. shutdown_err.message)
                end
                -- After shutdown, close the pipe handle completely
                stdin_closed = true
                if stdin_pipe and uv.is_closing(stdin_pipe) == false then
                    pcall(uv.close, stdin_pipe, check_completion)
                else
                    check_completion()
                end
            end)
        end)
    else
        -- No input provided, just shutdown and close stdin immediately
        uv.shutdown(stdin_pipe, function(shutdown_err)
            if shutdown_err then
                -- vim.notify("Stdin shutdown error (no input): " .. shutdown_err.message, vim.log.levels.WARN)
                internal_error = internal_error or ("Stdin shutdown error: " .. shutdown_err.message)
            end
            stdin_closed = true
            if stdin_pipe and uv.is_closing(stdin_pipe) == false then
                pcall(uv.close, stdin_pipe, check_completion)
            else
                check_completion()
            end
        end)
    end

    -- 8. Setup Timeout Timer (if requested)
    if timeout_ms and timeout_ms > 0 then
        timer_handle = uv.new_timer()
        if not timer_handle then
            internal_error = internal_error or "Failed to create timer handle"
            -- vim.notify(internal_error, vim.log.levels.ERROR)
        else
            uv.timer_start(timer_handle, timeout_ms, 0, function()
                -- vim.notify("Timeout triggered!", vim.log.levels.WARN)
                timed_out = true
                internal_error = internal_error or "Command timed out"

                -- Attempt to terminate the process
                if process_handle and uv.is_active(process_handle) then
                    -- Try SIGTERM first (15), then maybe SIGKILL (9) if needed?
                    -- uv.process_kill returns boolean success, not error object
                    local killed = pcall(uv.process_kill, process_handle, 15) -- 15 is SIGTERM on Unix-like
                    if not killed then
                        -- vim.notify("Failed to send SIGTERM on timeout.", vim.log.levels.WARN)
                        -- Could try SIGKILL here if SIGTERM fails
                        pcall(uv.process_kill, process_handle, 9) -- 9 is SIGKILL
                    end
                    -- Note: process_kill signals the OS, the actual exit and triggering
                    -- of the on_exit callback might take a moment.
                end

                -- Stop and close the timer itself
                if timer_handle and uv.is_active(timer_handle) then
                    uv.timer_stop(timer_handle)
                    if uv.is_active(timer_handle) then -- Check again, close if needed
                        uv.close(timer_handle, function() timer_handle = nil end)
                    else
                        timer_handle = nil
                    end
                end

                -- Force the event loop to stop. check_completion might not run if
                -- the process termination is delayed or pipes don't close quickly.
                uv.stop()
            end)
        end
    end

    -- 9. Run the Event Loop
    -- This blocks execution of this Lua function until uv.stop() is called
    -- (either by check_completion or the timeout) or until there are no more
    -- active handles/requests.
    -- vim.notify("Starting event loop...", vim.log.levels.DEBUG)
    uv.run('default')
    -- vim.notify("Event loop finished.", vim.log.levels.DEBUG)

    -- 10. Collect Results and Final Cleanup
    local final_stdout = table.concat(stdout_chunks)
    local final_stderr = table.concat(stderr_chunks)

    -- Final safeguard: ensure handles are closed if loop exited unexpectedly
    -- (shouldn't be necessary with proper check_completion and timeout handling)
    for _, handle in ipairs({ stdin_pipe, stdout_pipe, stderr_pipe, process_handle, timer_handle }) do
        if handle and uv.is_active(handle) and uv.is_closing(handle) == false then
            -- vim.notify("Force closing handle in final cleanup: " .. tostring(handle), vim.log.levels.DEBUG)
            pcall(uv.close, handle)
        end
    end

    -- 11. Return Results
    return {
        code = exit_code,
        signal = exit_signal,
        stdout = final_stdout,
        stderr = final_stderr,
        error = internal_error -- Report timeout or other internal errors here
    }
end

return M

-- Remove or comment out the example usage lines before using in production code
-- print("--- Example: echo hello world ---")
-- local result1 = vim.system_sync({'echo', 'hello world'})
-- print(vim.inspect(result1))

-- print("\n--- Example: cat with input ---")
-- local result2 = vim.system_sync({'cat'}, { input = "Line 1\nLine 2" })
-- print(vim.inspect(result2))

-- print("\n--- Example: command producing stderr and non-zero exit ---")
-- local result3 = vim.system_sync({'sh', '-c', 'echo "stdout msg" && echo "stderr msg" >&2 && exit 42'})
-- print(vim.inspect(result3))

-- print("\n--- Example: timeout ---")
-- local result4 = vim.system_sync({'sleep', '3'}, { timeout = 1500 }) -- 1.5 second timeout
-- print(vim.inspect(result4))

-- print("\n--- Example: invalid command ---")
-- local result5 = vim.system_sync({'hopefully_this_command_does_not_exist'})
-- print(vim.inspect(result5)) -- Expect spawn error

-- print("\n--- Example: string command ---")
-- local result6 = vim.system_sync('ls -l *.lua') -- Adjust pattern as needed
-- print(vim.inspect(result6))
