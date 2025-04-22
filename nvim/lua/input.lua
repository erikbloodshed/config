vim.ui.input = function(opts, on_confirm)
    opts = opts or {}
    local prompt = opts.prompt or "Input: "
    local default = opts.default or ""
    on_confirm = on_confirm or function() end

    -- Calculate a minimal width with a bit buffer
    local default_width = vim.str_utfindex(default) + 8
    local prompt_width = vim.str_utfindex(prompt) + 8
    local input_width = math.max(default_width, prompt_width)

    local default_win_config = {
        relative = "cursor",
        row = 1,
        col = 0,
        focusable = false,
        style = "minimal",
        border = "rounded",
        width = input_width,
        height = 1,
        title = prompt,
        noautocmd = true,
    }


    -- Place the window near cursor or at the center of the window.
    if prompt ~= "New Name: " then
        default_win_config.relative = "win"
        default_win_config.row = math.max(vim.api.nvim_win_get_height(0) / 2 - 1, 0)
        default_win_config.col = math.max(vim.api.nvim_win_get_width(0) / 2 - input_width / 2, 0)
    end

    -- Create floating window.
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_open_win(bufnr, true, default_win_config)
    vim.api.nvim_buf_set_text(bufnr, 0, 0, 0, 0, { default })

    -- Put cursor at the end of the default value
    vim.cmd("startinsert")
    vim.api.nvim_win_set_cursor(0, { 1, vim.str_utfindex(default) + 1 })

    -- Enter to confirm
    vim.keymap.set({ "n", "i", "v" }, "<cr>", function()
        on_confirm(vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1])
        vim.cmd("stopinsert")
        vim.defer_fn(function() vim.api.nvim_win_close(0, true) end, 5)
    end, { buffer = bufnr })

    -- Esc or q to close
    vim.keymap.set("n", "<esc>", function()
        on_confirm(nil)
        vim.cmd("stopinsert")
        vim.defer_fn(function() vim.api.nvim_win_close(0, true) end, 5)
    end, { buffer = bufnr })
    vim.keymap.set("n", "q", function()
        on_confirm(nil)
        vim.cmd("stopinsert")
        vim.defer_fn(function() vim.api.nvim_win_close(0, true) end, 5)
    end, { buffer = bufnr })
end
