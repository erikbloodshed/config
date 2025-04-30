local M = {}
local uv = vim.uv

-- Utility function to safely close a handle if it is active and not already closing.
-- Optionally invokes a callback after closure.
local function safe_close(handle, cb)
    if handle and uv.is_active(handle) and not uv.is_closing(handle) then
        pcall(uv.close, handle, cb)
    elseif cb then
        cb()
    end
end

-- Main function: asynchronously runs a command and returns only its exit code and error message (if any).
function M.execute(cmd)
    -- Validate the structure of the input
    if type(cmd) ~= "table" or type(cmd.compiler) ~= "string" or cmd.compiler == "" or type(cmd.arg) ~= "table" then
        return { error = "Invalid command format", code = -1 }
    end

    -- Check if the command is executable
    if vim.fn.executable(cmd.compiler) == 0 then
        return { error = "Command not executable: " .. cmd.compiler, code = -1 }
    end

    -- Create pipes for stdin, stdout, and stderr
    local stdin = uv.new_pipe(false)
    local stdout = uv.new_pipe(false)
    local stderr = uv.new_pipe(false)

    -- Handle and status tracking
    local process
    local spawn_err
    local exit_code
    local internal_error

    -- Flags to track when the process has exited and all pipes are closed
    local exited = false
    local closed = { stdin = false, stdout = false, stderr = false }

    -- Called whenever a pipe is closed, to decide if we should stop the event loop
    local function check_done()
        if exited and closed.stdin and closed.stdout and closed.stderr then
            -- Close the process handle last
            safe_close(process, function()
                if uv.loop_alive() then uv.stop() end
            end)
        end
    end

    -- Wrapper to simplify closing a specific pipe and updating state
    local function close_and_mark(name, pipe)
        safe_close(pipe, function()
            closed[name] = true
            check_done()
        end)
    end

    -- Called when the spawned process exits
    local function on_exit(code)
        exit_code = code
        exited = true
        -- Start cleaning up all pipes after the process exits
        close_and_mark("stdout", stdout)
        close_and_mark("stderr", stderr)
        close_and_mark("stdin", stdin)
        check_done()
    end

    -- Returns a pipe read callback that discards output but still handles read errors and EOF
    local function discard_output(name, pipe)
        return function(read_err, data)
            if read_err then
                internal_error = internal_error or (name .. " read error: " .. read_err.message)
                closed[name] = true
                safe_close(pipe, check_done)
            elseif not data then -- End of stream
                closed[name] = true
                safe_close(pipe, check_done)
            end
        end
    end

    -- Spawn the process asynchronously with pipes and exit callback
    process, spawn_err = uv.spawn(cmd.compiler, {
        args = cmd.arg,
        stdio = { stdin, stdout, stderr },
    }, on_exit)

    -- If spawning failed, clean up and return immediately
    if not process then
        for _, h in ipairs({ stdin, stdout, stderr }) do safe_close(h) end
        return { error = "Spawn failed: " .. tostring(spawn_err), code = -1 }
    end

    -- Start reading from stdout (output is discarded)
    local ok_out, err_out = pcall(uv.read_start, stdout, discard_output("stdout", stdout))
    if not ok_out then
        internal_error = "Failed to start stdout read: " .. tostring(err_out)
        closed.stdout = true
        safe_close(stdout, check_done)
    end

    -- Start reading from stderr (output is discarded)
    local ok_err, err_err = pcall(uv.read_start, stderr, discard_output("stderr", stderr))
    if not ok_err then
        internal_error = "Failed to start stderr read: " .. tostring(err_err)
        closed.stderr = true
        safe_close(stderr, check_done)
    end

    -- Immediately shut down stdin since we aren't writing to it
    uv.shutdown(stdin, function(shutdown_err)
        if shutdown_err then
            internal_error = internal_error or ("Stdin shutdown error: " .. shutdown_err.message)
        end
        closed.stdin = true
        safe_close(stdin, check_done)
    end)

    -- Start the libuv event loop and block until `uv.stop()` is called
    uv.run("default")

    -- Ensure everything is closed after loop finishes
    for _, h in ipairs({ process, stdin, stdout, stderr }) do
        safe_close(h)
    end

    -- Return only exit code and internal error, if any
    return { code = exit_code, error = internal_error }
end

return M

