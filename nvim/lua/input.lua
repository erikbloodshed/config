local function window_center(input_width)
    return {
        relative = "win",
        row = math.max(vim.api.nvim_win_get_height(0) / 2 - 1, 0),
        col = math.max(vim.api.nvim_win_get_width(0) / 2 - input_width / 2, 0),
    }
end

local function under_cursor(_)
    return {
        relative = "cursor",
        row = 1,
        col = 0,
    }
end

local function is_valid_varname(name)
    -- Must start with a letter or underscore, followed by letters, numbers, or underscores
    return name:match("^[A-Za-z_][A-Za-z0-9_]*$") ~= nil
end

local function input(opts, on_confirm, win_config)
    local prompt = opts.prompt or "Input: "
    local default = opts.default or ""
    on_confirm = on_confirm or function() end

    -- Calculate a minimal width with a bit buffer
    local default_width = vim.str_utfindex(default) + 10
    local prompt_width = vim.str_utfindex(prompt) + 10
    local input_width = math.max(default_width, prompt_width)

    local default_win_config = {
        focusable = true,
        style = "minimal",
        border = "rounded",
        width = input_width,
        height = 1,
        title = prompt,
    }

    -- Apply user's window config.
    win_config = vim.tbl_deep_extend("force", default_win_config, win_config)

    -- Place the window near cursor or at the center of the window.
    if prompt == "New Name: " then
        win_config = vim.tbl_deep_extend("force", win_config, under_cursor(win_config.width))
    else
        win_config = vim.tbl_deep_extend("force", win_config, window_center(win_config.width))
    end

    -- Create floating window.
    local buffer = vim.api.nvim_create_buf(false, true)
    local window = vim.api.nvim_open_win(buffer, true, win_config)
    vim.api.nvim_buf_set_text(buffer, 0, 0, 0, 0, { default })

    -- Put cursor at the end of the default value
    vim.cmd("startinsert")
    vim.api.nvim_win_set_cursor(window, { 1, vim.str_utfindex(default) + 1 })

    local function close(cancel)
        on_confirm(cancel and nil or vim.api.nvim_buf_get_lines(buffer, 0, 1, false)[1])
        vim.cmd("stopinsert")
        vim.api.nvim_win_close(window, true)
    end

    vim.keymap.set("n", "<esc>", function() close(true) end, { buffer = buffer })
    vim.keymap.set("n", "q", function() close(true) end, { buffer = buffer })
    vim.keymap.set({ "n", "i", "v" }, "<CR>", function()
        local lines = vim.api.nvim_buf_get_lines(buffer, 0, 1, false)
        local input_value = lines[1]
        vim.cmd("stopinsert")
        vim.api.nvim_win_close(window, true)

        input_value = input_value and vim.trim(input_value) or ""

        if input_value == "" or input_value == default then
            return -- ignore empty or no-op rename
        end

        if not is_valid_varname(input_value) then
            vim.notify("Invalid variable name: '" .. input_value .. "'", vim.log.levels.ERROR)
            return
        end

        on_confirm(input_value)
    end, { buffer = buffer })
end

vim.ui.input = function(opts, on_confirm)
    opts = opts or {}
    input(opts, on_confirm, {})
end
