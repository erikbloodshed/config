M = {}

function M.system_sync(cmd, opts)
  local uv = vim.loop
  opts = opts or {}

  -- Parse command and arguments
  local command, args = nil, {}

  if type(cmd) == "string" then
    local split = vim.split(cmd, "%s+")
    if #split == 0 then return { error = "Empty command string", code = -1, signal = 0, stdout = "", stderr = "" } end
    command = split[1]
    args = vim.list_slice(split, 2)
  elseif type(cmd) == "table" and #cmd > 0 then
    command = cmd[1]
    args = vim.list_slice(cmd, 2)
  else
    return { error = "Invalid command type", code = -1, signal = 0, stdout = "", stderr = "" }
  end

  local stdout, stderr, exit_code, exit_signal, internal_error = {}, {}, nil, nil, nil
  local done = false

  -- Pipe handles
  local stdin_pipe, stdout_pipe, stderr_pipe = uv.new_pipe(false), uv.new_pipe(false), uv.new_pipe(false)
  local process_handle, timer_handle = nil, nil

  local function safe_close(handle)
    if handle and not uv.is_closing(handle) then
      uv.close(handle)
    end
  end

  local function check_done()
    if done then return end
    if process_handle and uv.is_active(process_handle) then return end
    if stdout_pipe and not uv.is_active(stdout_pipe) then return end
    if stderr_pipe and not uv.is_active(stderr_pipe) then return end
    done = true
    if timer_handle then
      uv.timer_stop(timer_handle)
      safe_close(timer_handle)
    end
    uv.stop()
  end

  local function start_read(pipe, acc)
    uv.read_start(pipe, function(err, data)
      if err then
        internal_error = internal_error or err
        return
      end
      if data then
        table.insert(acc, data)
      else
        safe_close(pipe)
        check_done()
      end
    end)
  end

  local function shutdown_stdin()
    if not opts.input then
      safe_close(stdin_pipe)
      return check_done()
    end
    uv.write(stdin_pipe, opts.input, function(err)
      if err then internal_error = internal_error or err end
      uv.shutdown(stdin_pipe, function()
        safe_close(stdin_pipe)
        check_done()
      end)
    end)
  end

  -- Process exit callback
  local function on_exit(code, signal)
    exit_code, exit_signal = code, signal
    safe_close(stdout_pipe)
    safe_close(stderr_pipe)
    safe_close(process_handle)
    check_done()
  end

  -- Prepare spawn options
  local spawn_opts = {
    args = args,
    stdio = { stdin_pipe, stdout_pipe, stderr_pipe },
    cwd = opts.cwd,
    env = opts.env,
    verbatim = opts.verbatim_args,
    detached = opts.detached,
    hide = opts.hide_window,
  }

  -- Try spawning the process
  local ok, handle, pid = pcall(function()
    return uv.spawn(command, spawn_opts, on_exit)
  end)

  if not ok or not handle then
    safe_close(stdin_pipe)
    safe_close(stdout_pipe)
    safe_close(stderr_pipe)
    return {
      error = "Failed to spawn process: " .. tostring(handle),
      code = -1, signal = 0, stdout = "", stderr = ""
    }
  end

  process_handle = handle

  start_read(stdout_pipe, stdout)
  start_read(stderr_pipe, stderr)
  shutdown_stdin()

  if opts.timeout and opts.timeout > 0 then
    timer_handle = uv.new_timer()
    uv.timer_start(timer_handle, opts.timeout, 0, function()
      internal_error = "Command timed out"
      pcall(uv.process_kill, process_handle, 15)
    end)
  end

  uv.run()

  return {
    code = exit_code,
    signal = exit_signal or 0,
    stdout = table.concat(stdout),
    stderr = table.concat(stderr),
    error = internal_error and tostring(internal_error) or nil
  }
end

return M
