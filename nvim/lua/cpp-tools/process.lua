--[[
Optimized synchronous command execution for compilation using Neovim's libuv.
Runs an external command with arguments, waits for it to finish,
and captures its exit code and standard error.

This refactored version returns only the error code and stderr.

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

-- Pre-allocate common error messages
local ERROR_MESSAGES = {
    invalid_cmd_table = "Invalid command format: expected a table with 'compiler' and 'arg' fields",
    invalid_compiler = "Invalid command format: 'compiler' must be a non-empty string",
    invalid_args = "Invalid command format: 'arg' must be a table",
    not_executable = "Command not found or not executable: ",
}

-- Safe handle closure
local function safe_close(handle, callback)
    if handle and uv.is_active(handle) and not uv.is_closing(handle) then
        pcall(uv.close, handle, callback)
    elseif callback then
        callback()
    end
end

-- Execute a command using libuv
local M = {
    execute = function(cmd_table)
        -- Fast path validation
        if type(cmd_table) ~= 'table' then
            return { code = -1, stderr = ERROR_MESSAGES.invalid_cmd_table } -- Modified return
        end

        local command_path = cmd_table.compiler
        if type(command_path) ~= "string" or command_path == "" then
            return { code = -1, stderr = ERROR_MESSAGES.invalid_compiler } -- Modified return
        end

        local command_args = cmd_table.arg
        if type(command_args) ~= 'table' then
            return { code = -1, stderr = ERROR_MESSAGES.invalid_args } -- Modified return
        end

        if vim.fn.executable(command_path) == 0 then
            return { code = -1, stderr = ERROR_MESSAGES.not_executable .. command_path } -- Modified return
        end

        -- Status tracking
        local status = {
            pipes_closed = 0,
            exit_code = nil,
            internal_error = nil, -- Still track internal errors for stderr potential
            process_exited = false,
            stderr_data = {}      -- Only need stderr data
        }

        -- Create pipes (excluding stdout)
        local stdin_pipe = uv.new_pipe(false)
        local stderr_pipe = uv.new_pipe(false)
        local process_handle

        local function check_completion()
            -- All done when process exited and relevant pipes (stdin, stderr) are closed (2 pipes)
            if status.process_exited and status.pipes_closed >= 2 then -- Adjusted count
                safe_close(process_handle, function()
                    if uv.loop_alive() then
                        uv.stop()
                    end
                end)
            end
        end

        local function on_pipe_close()
            status.pipes_closed = status.pipes_closed + 1
            check_completion()
        end

        local function on_exit(code)
            status.exit_code = code
            status.process_exited = true

            -- Close remaining pipes (stdin, stderr)
            safe_close(stderr_pipe, on_pipe_close)
            safe_close(stdin_pipe, on_pipe_close)

            check_completion()
        end

        -- Simplified read handler only for stderr
        local function on_stderr_read(err, data)
            if err then
                if not status.internal_error then
                    -- Include internal read errors in stderr for debugging
                    status.internal_error = "stderr read error: " .. err.message
                end
                safe_close(stderr_pipe, on_pipe_close)
                return
            end

            if data then
                table.insert(status.stderr_data, data)
            else -- End of file
                safe_close(stderr_pipe, on_pipe_close)
            end
        end

        -- Configure options for spawning (remove stdout pipe)
        local spawn_options = {
            args = command_args,
            stdio = { stdin_pipe, nil, stderr_pipe } -- Pass nil for stdout
        }

        local spawn_err
        process_handle, spawn_err = uv.spawn(command_path, spawn_options, on_exit)

        if not process_handle then
            local error_msg = "Failed to spawn process"
            if spawn_err then
                error_msg = error_msg .. ": " .. tostring(spawn_err)
            end
            status.internal_error = error_msg -- Store internal error for stderr

            safe_close(stdin_pipe)
            safe_close(stderr_pipe)

            return {
                code = -1,
                stderr = status.internal_error or "" -- Return internal error via stderr
            }
        end

        -- Start reading only from stderr
        if not pcall(uv.read_start, stderr_pipe, on_stderr_read) then
            -- Include internal start errors in stderr
            status.internal_error = status.internal_error or "Failed to start reading stderr"
            safe_close(stderr_pipe, on_pipe_close)
        end

        -- FIX: Close stdin pipe directly rather than using shutdown
        -- This avoids the type mismatch warning
        safe_close(stdin_pipe, function(close_err)
            if close_err and not status.internal_error then
                -- Include internal close errors in stderr
                status.internal_error = "Stdin close error: " .. tostring(close_err)
            end
            on_pipe_close() -- Call this manually since we're not using the safe_close wrapper
        end)

        -- Run the event loop
        uv.run('default')

        -- Final cleanup (exclude stdout)
        for _, handle in ipairs({ process_handle, stdin_pipe, stderr_pipe }) do
            safe_close(handle)
        end

        -- Combine stderr chunks
        local stderr_content = table.concat(status.stderr_data)
        -- If there was an internal error during execution, prepend it to stderr
        if status.internal_error then
            stderr_content = status.internal_error .. "\n" .. stderr_content
        end

        return {
            code = status.exit_code,
            stderr = stderr_content
        }
    end
}

return M
