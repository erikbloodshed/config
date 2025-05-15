--[[
Optimized synchronous command execution for compilation using Neovim's libuv.
Runs an external command with arguments, waits for it to finish,
and captures its exit code, standard error, and any script-level errors.

This version returns the error code, stderr, and an optional error_type
with improved resource management, memory efficiency, and error reporting.

Parameters:
  cmd_table: table - A table containing compilation information.
                    It should have the following fields:
                    - compiler: string - The command/executable to run (e.g., 'g++', 'clang++').
                    - arg: table - A list of arguments for the command.

Returns:
  table: A table containing the results:
    - code: integer | nil - The exit code of the command. Nil if terminated by signal.
                          -1 if the function itself failed (e.g., spawn error, invalid input).
    - stderr: string - The standard error output of the command or a script error message.
    - error_type: string | nil - If the script itself failed, this indicates the type of error
                                (e.g., "validation_error", "spawn_error", "timeout_error").
                                Nil if the command executed successfully or failed on its own.
]]
local uv = vim.uv

-- Pre-allocate common error messages for better memory efficiency and structured errors
local ERROR_MESSAGES = {
    invalid_cmd_table = "Invalid command format: expected a table with 'compiler' and 'arg' fields",
    invalid_compiler = "Invalid command format: 'compiler' must be a non-empty string",
    invalid_args = "Invalid command format: 'arg' must be a table",
    not_executable = "Command not found or not executable: ",
    pipe_creation_failed = "Failed to create necessary pipes for process I/O",
    spawn_failed = "Failed to spawn process: ",
    stderr_read_failed = "Failed to start reading stderr: ",
    stderr_read_error = "Error reading from stderr: ",
    timeout_timer_failed = "Warning: Failed to create timeout timer. Process might hang.",
    process_timed_out = "\nProcess timed out after 30 seconds",
    event_loop_failed = "Critical Error: libuv event loop failed",
}

-- Enum-like table for error types
local ERROR_TYPES = {
    VALIDATION = "validation_error",
    PIPE = "pipe_error",
    SPAWN = "spawn_error",
    STDERR_READ = "stderr_read_error",
    TIMEOUT = "timeout_error",
    LOOP = "loop_error",
}

-- Improved resource management with tracked handles
local ResourceManager = {
    handles = {}, -- Stores handles for the current ResourceManager instance

    -- Track a handle for later cleanup
    track = function(self, handle, handle_type)
        if handle then
            table.insert(self.handles, { handle = handle, type = handle_type or "generic" })
        end
        return handle
    end,

    -- Safe handle closure with improved error handling
    close = function(self, handle, callback)
        if not handle or uv.is_closing(handle) then
            if callback then pcall(callback) end -- Protect callback execution
            return
        end

        pcall(uv.close, handle, callback or function() end)

        -- Remove from tracked handles if present
        for i, tracked in ipairs(self.handles) do
            if tracked.handle == handle then
                table.remove(self.handles, i)
                break
            end
        end
    end,

    -- Clean up all remaining handles for this instance
    cleanup_instance = function(self)
        -- Make a copy since we'll be modifying the original table during iteration
        local handles_to_close = {}
        for _, tracked in ipairs(self.handles) do
            table.insert(handles_to_close, tracked.handle)
        end

        self.handles = {} -- Clear the instance's handles table

        for _, handle in ipairs(handles_to_close) do
            if handle and not uv.is_closing(handle) then
                pcall(uv.close, handle)
            end
        end
    end
}

-- Global resource manager for VimLeavePre cleanup (safety net)
local GlobalResourceManager = { handles = {} }
setmetatable(GlobalResourceManager, { __index = ResourceManager }) -- Inherit methods

-- Execute a command using libuv
local M = {}

function M.execute(cmd_table)
    -- Create a new resource manager instance for this specific execution
    local resources = setmetatable({ handles = {} }, { __index = ResourceManager })

    -- Build result table
    local result = {
        code = -1,       -- Default to -1 for script-level failures
        stderr = "",
        error_type = nil -- Will be set if the script itself errors
    }

    -- Fast path validation with early returns and structured errors
    if type(cmd_table) ~= 'table' then
        result.stderr = ERROR_MESSAGES.invalid_cmd_table
        result.error_type = ERROR_TYPES.VALIDATION
        return result
    end

    local command_path = cmd_table.compiler
    if type(command_path) ~= "string" or command_path == "" then
        result.stderr = ERROR_MESSAGES.invalid_compiler
        result.error_type = ERROR_TYPES.VALIDATION
        return result
    end

    local command_args = cmd_table.arg
    if type(command_args) ~= 'table' then
        result.stderr = ERROR_MESSAGES.invalid_args
        result.error_type = ERROR_TYPES.VALIDATION
        return result
    end

    -- Check if command is executable early
    if vim.fn.executable(command_path) == 0 then
        result.stderr = ERROR_MESSAGES.not_executable .. command_path
        result.error_type = ERROR_TYPES.VALIDATION
        return result
    end

    -- Use a single status table to track everything
    local status = {
        pending_closures = 2, -- stdin + stderr pipes initially
        process_exited = false,
        stderr_builder = {},  -- Use a table for efficient string building
        -- For extremely large/frequent stderr, consider pre-allocation
        -- (e.g., table.new(expected_chunks, 0) in Lua 5.4+)
        -- but for typical compilation output, this is fine.
    }

    local completed = false -- Flag to prevent multiple completions

    -- Completion function to finalize results and clean up
    local function complete()
        if completed then return end
        completed = true

        -- Build final stderr output efficiently if not already set by a script error
        if result.stderr == "" then
            result.stderr = table.concat(status.stderr_builder)
        end

        -- Clean up resources specific to this execution
        resources:cleanup_instance()

        -- Stop the event loop if it's still running.
        -- This is crucial for the synchronous-like behavior of M.execute().
        if uv.loop_alive() then
            uv.stop()
        end
    end

    -- Create necessary pipes with resource tracking
    local stdin_pipe = resources:track(uv.new_pipe(false), "stdin_pipe")
    local stderr_pipe = resources:track(uv.new_pipe(false), "stderr_pipe")

    if not stdin_pipe or not stderr_pipe then
        result.stderr = ERROR_MESSAGES.pipe_creation_failed
        result.error_type = ERROR_TYPES.PIPE
        complete() -- Ensure cleanup and loop stop
        return result
    end

    -- Simplified pipe closure handler
    local function on_pipe_close()
        status.pending_closures = status.pending_closures - 1
        if status.pending_closures <= 0 and status.process_exited then
            complete()
        end
    end

    -- Process exit handler
    local function on_exit(code, signal) -- Libuv provides code and signal
        -- If code is nil and signal is not 0, process was terminated by a signal.
        -- We primarily care about the exit code for compilation success/failure.
        -- If terminated by signal, 'code' will be nil. We can choose to report signal
        -- or stick to the original behavior of nil code. For simplicity, stick to 'code'.
        result.code = code
        if signal ~= 0 and code == nil then
            -- Optionally, indicate termination by signal in stderr or a new field
            table.insert(status.stderr_builder, string.format("\nProcess terminated by signal: %d", signal))
        end

        status.process_exited = true

        -- Ensure pipes are closed. These might already be closing or closed.
        resources:close(stderr_pipe, on_pipe_close)
        resources:close(stdin_pipe, on_pipe_close) -- stdin is closed earlier, but safe to call again

        if status.pending_closures <= 0 then
            complete()
        end
    end

    -- Optimized stderr reader
    local function on_stderr_read(err, data)
        if err then
            table.insert(status.stderr_builder, ERROR_MESSAGES.stderr_read_error .. tostring(err))
            -- Don't set result.error_type here as it's an I/O error with the child process,
            -- not necessarily a script setup error. The command's exit code will be more relevant.
            resources:close(stderr_pipe, on_pipe_close)
            return
        end

        if data then
            table.insert(status.stderr_builder, data)
        else -- EOF
            resources:close(stderr_pipe, on_pipe_close)
        end
    end

    -- Spawn the process
    local spawn_options = {
        args = command_args,
        stdio = { stdin_pipe, nil, stderr_pipe } -- No stdout pipe needed
    }

    local process_handle, spawn_pid_or_err = uv.spawn(command_path, spawn_options, on_exit)

    if not process_handle then
        result.stderr = ERROR_MESSAGES.spawn_failed .. tostring(spawn_pid_or_err)
        result.error_type = ERROR_TYPES.SPAWN
        -- Clean up pipes that were created before spawn failed
        resources:close(stderr_pipe, on_pipe_close)
        resources:close(stdin_pipe, on_pipe_close)
        complete()
        return result
    end
    resources:track(process_handle, "process") -- Track successful process handle

    -- Start reading stderr
    local read_start_ok, read_err = pcall(uv.read_start, stderr_pipe, on_stderr_read)
    if not read_start_ok then
        result.stderr = ERROR_MESSAGES.stderr_read_failed .. tostring(read_err)
        result.error_type = ERROR_TYPES.STDERR_READ -- This is a script setup failure
        -- Process is running, but we can't read its stderr. Attempt to kill and cleanup.
        pcall(uv.process_kill, process_handle, 15)  -- SIGTERM
        resources:close(stderr_pipe, on_pipe_close)
        complete()
        return result
    end

    -- Close stdin immediately as we don't write to it
    resources:close(stdin_pipe, on_pipe_close)

    -- Set a timeout
    local timeout_duration = 30000 -- 30 seconds
    local timeout_timer = resources:track(uv.new_timer(), "timeout_timer")

    if timeout_timer then
        uv.timer_start(timeout_timer, timeout_duration, 0, function()
            if completed then return end -- Already completed (e.g. process finished quickly)

            -- Process timed out
            result.error_type = ERROR_TYPES.TIMEOUT -- Mark as a timeout error from the script's perspective
            table.insert(status.stderr_builder, ERROR_MESSAGES.process_timed_out)
            result.code = -1                        -- Indicate script-level failure due to timeout

            if process_handle and not uv.is_closing(process_handle) then
                pcall(uv.process_kill, process_handle, 15) -- SIGTERM

                local kill_timer = resources:track(uv.new_timer(), "kill_timer_fallback")
                if kill_timer then
                    uv.timer_start(kill_timer, 2000, 0, function()
                        if process_handle and not uv.is_closing(process_handle) then
                            pcall(uv.process_kill, process_handle, 9) -- SIGKILL
                        end
                        resources:close(kill_timer)                   -- Close the kill_timer itself
                    end)
                end
            end
            complete()                     -- This will also stop the loop
            resources:close(timeout_timer) -- Ensure timeout_timer itself is closed
        end)
    else
        -- If timer creation fails, we can't enforce timeout. Log it.
        table.insert(status.stderr_builder, ERROR_MESSAGES.timeout_timer_failed)
        -- No result.error_type here, as it's a warning; the command might still complete.
    end

    -- Run the libuv event loop.
    -- This call will block until uv.stop() is called (in complete()) or the loop has no active handles.
    -- This is what gives M.execute() its synchronous-like behavior from the caller's perspective.
    local success, loop_err = pcall(uv.run)
    if not success and not completed then
        -- This is a critical failure of the event loop itself.
        result.stderr = ERROR_MESSAGES.event_loop_failed .. (loop_err and (": " .. tostring(loop_err)) or "")
        result.error_type = ERROR_TYPES.LOOP
        result.code = -1
        complete() -- Attempt to cleanup and ensure everything stops
    end

    -- Final safety net: if complete() was not called for some reason (e.g. error in uv.run before callbacks)
    if not completed then
        complete()
    end

    return result
end

-- Cleanup on module unload to prevent resource leaks from unexpected exits or errors
-- This uses the GlobalResourceManager as a safety net for any handles that might
-- somehow be orphaned if an execution context didn't clean up properly.
vim.api.nvim_create_autocmd("VimLeavePre", {
    callback = function()
        -- This is a global cleanup for any handles that might have been
        -- tracked by GlobalResourceManager if used, or as a conceptual placeholder.
        -- In the current design, each `M.execute` has its own `resources` manager.
        -- This global cleanup is more of a failsafe if the design were different
        -- or if handles were somehow leaked to a global scope.
        -- For the current script, `resources:cleanup_instance()` handles per-call cleanup.
        -- If we wanted a true global tracker for handles created outside M.execute,
        -- we would need to explicitly track them with GlobalResourceManager.
        -- For now, let's assume it's a placeholder for broader resource safety.
        -- print("VimLeavePre: Performing global resource cleanup if any were registered globally.")
        GlobalResourceManager:cleanup_instance() -- If it were used to track handles globally
    end,
    desc = "Ensure libuv handles from process module are cleaned up"
})

return M
