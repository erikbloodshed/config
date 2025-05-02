local api = vim.api
local keymap = vim.keymap.set

vim.ui.input = function(opts, on_confirm)
    opts = opts or {}

    local prompt = opts.prompt or "Input: "
    local default = opts.default or ""
    on_confirm = on_confirm or function() end

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

    if prompt ~= "New Name: " then
        default_win_config.relative = "win"
        default_win_config.row = math.max(api.nvim_win_get_height(0) / 2 - 1, 0)
        default_win_config.col = math.max(api.nvim_win_get_width(0) / 2 - input_width / 2, 0)
    end

    local bufnr = api.nvim_create_buf(false, true)
    api.nvim_open_win(bufnr, true, default_win_config)
    api.nvim_buf_set_text(bufnr, 0, 0, 0, 0, { default })

    vim.cmd("startinsert")
    api.nvim_win_set_cursor(0, { 1, vim.str_utfindex(default) + 1 })

    keymap({ "n", "i", "v" }, "<cr>", function()
        on_confirm(api.nvim_buf_get_lines(bufnr, 0, 1, false)[1])
        vim.cmd("stopinsert")
        vim.defer_fn(function() api.nvim_win_close(0, true) end, 5)
    end, { buffer = bufnr })

    keymap("n", "<esc>", function()
        on_confirm(nil)
        vim.cmd("stopinsert")
        vim.defer_fn(function() api.nvim_win_close(0, true) end, 5)
    end, { buffer = bufnr })

    keymap("n", "q", function()
        on_confirm(nil)
        vim.cmd("stopinsert")
        vim.defer_fn(function() api.nvim_win_close(0, true) end, 5)
    end, { buffer = bufnr })
end

api.nvim_set_hl(0, "CustomPickerSelection", { link = "Visual" })

local function close_picker(picker)
    if api.nvim_win_is_valid(picker.win) then
        api.nvim_win_close(picker.win, true)
    end
    if api.nvim_buf_is_valid(picker.buf) then
        api.nvim_buf_delete(picker.buf, { force = true })
    end
end

local function update_highlight(picker)
    api.nvim_buf_clear_namespace(picker.buf, picker.ns, 0, -1)
    api.nvim_buf_add_highlight(picker.buf, picker.ns, "CustomPickerSelection", picker.selected - 1, 0, -1)
end

local function move_picker(picker, delta)
    local count = #picker.items
    local new_idx = (picker.selected - 1 + delta) % count + 1
    picker.selected = new_idx
    api.nvim_win_set_cursor(picker.win, { new_idx, 0 })
    update_highlight(picker)
end

local function pick(opts)
    local lines = {}
    local max_width = string.len(opts.title)
    for _, item in ipairs(opts.items) do
        local line = item.text or tostring(item)
        table.insert(lines, line)
    end

    local padding = 4
    local width = math.min(max_width + padding, vim.o.columns - 4)
    local height = math.min(#lines, 10)
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    local buf = api.nvim_create_buf(false, true)
    api.nvim_buf_set_lines(buf, 0, -1, false, lines)

    local win = api.nvim_open_win(buf, true, {
        relative = "editor",
        width = width,
        height = height,
        row = row,
        col = col,
        border = "rounded",
        style = "minimal",
        title = opts.title or "Select",
        title_pos = "center"
    })

    local picker = {
        buf = buf,
        win = win,
        ns = api.nvim_create_namespace("custom_picker"),
        items = opts.items,
        selected = 1,
        actions = opts.actions or {},
        on_close = opts.on_close or function() end,
    }

    update_highlight(picker)
    api.nvim_win_set_cursor(win, { 1, 0 })

    keymap("n", "j", function() move_picker(picker, 1) end, { buffer = buf, nowait = true })
    keymap("n", "k", function() move_picker(picker, -1) end, { buffer = buf, nowait = true })

    keymap("n", "<CR>", function()
        if picker.actions.confirm then
            picker.actions.confirm(picker, picker.items[picker.selected])
        else
            close_picker(picker)
        end
    end, { buffer = buf })

    local function cancel()
        close_picker(picker)
        picker.on_close()
    end

    keymap("n", "q", cancel, { buffer = buf })
    keymap("n", "<Esc>", cancel, { buffer = buf })

    return picker
end

vim.ui.select = function(items, opts, on_choice)
    opts = opts or {}

    local formatted_items = {}

    for idx, item in ipairs(items) do
        local text = (opts.format_item and opts.format_item(item)) or tostring(item)
        table.insert(formatted_items, {
            text = text,
            item = item,
            idx = idx,
        })
    end

    local completed = false

    pick({
        title = opts.prompt or "Select",
        items = formatted_items,
        actions = {
            confirm = function(picker, picked)
                if completed then return end
                completed = true
                close_picker(picker)
                vim.schedule(function()
                    on_choice(picked.item, picked.idx)
                end)
            end,
        },
        on_close = function()
            if completed then return end
            completed = true
            vim.schedule(function()
                on_choice(nil, nil)
            end)
        end,
    })
end
