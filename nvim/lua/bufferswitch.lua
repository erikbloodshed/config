-- BufferSwitcher: buffer switcher using NerdFont icons and temporary tabline
local M = {}

-- Timer handle for hiding the tabline
local hide_timer = nil

-- Attempt to load nvim-web-devicons for NerdFont icons
local has_devicons, devicons = pcall(require, 'nvim-web-devicons')

-- Table to store the order of listed buffers
local buffer_order = {}

-- Function to add a buffer to the order if it's not already present
local function add_buffer_to_order(bufnr)
    if vim.api.nvim_buf_is_valid(bufnr) and vim.fn.buflisted(bufnr) == 1 then
        local found = false
        for _, existing_bufnr in ipairs(buffer_order) do
            if existing_bufnr == bufnr then
                found = true
                break
            end
        end
        if not found then
            table.insert(buffer_order, bufnr)
        end
    end
end

-- Function to remove a buffer from the order
local function remove_buffer_from_order(bufnr)
    for i, existing_bufnr in ipairs(buffer_order) do
        if existing_bufnr == bufnr then
            table.remove(buffer_order, i)
            break
        end
    end
end

-- Format buffer name with NerdFont icon
local function format_buffer_name(bufnr)
    if not vim.api.nvim_buf_is_valid(bufnr) then
        return '[Invalid]'
    end

    local name = vim.fn.bufname(bufnr)
    local display_name = vim.fn.fnamemodify(name, ':t')
    local buf_type = vim.bo[bufnr].buftype

    -- Handle different buffer types
    if buf_type == 'help' then
        display_name = "[Help] " .. (display_name ~= '' and display_name or 'help')
    elseif display_name == '' then
        display_name = '[No Name]'
    end

    local ext = display_name:match('%.([^%.]+)$') or ''
    local icon = ''
    if has_devicons then
        icon = devicons.get_icon(display_name, ext, { default = true }) or ''
    end

    return (icon ~= '' and icon .. ' ' or '') .. display_name
end

-- Update the tabline with buffer names, handling abbreviation and width
local function update_tabline_display()
    local current = vim.api.nvim_get_current_buf()
    local parts = {}
    local max_width = vim.o.columns
    local num_listed_buffers = #buffer_order
    local initial_max_tab_width = 15
    local min_width_per_tab = 5
    local separator_width = 1

    -- First pass: Calculate the desired width of each tab
    local tab_widths = {}
    local total_desired_width = 0

    for _, bufnr in ipairs(buffer_order) do
        local buf_label_full = format_buffer_name(bufnr)
        local desired_width = math.min(vim.fn.strwidth(buf_label_full), initial_max_tab_width) + 2 * 1 -- Minimal padding
        tab_widths[bufnr] = { full = buf_label_full, desired = desired_width, current_width = desired_width }
        total_desired_width = total_desired_width + desired_width
    end

    local available_width_for_labels = max_width - (num_listed_buffers - 1) * separator_width -
    num_listed_buffers * 2 * 1                                                                                             -- Separators and padding

    -- Second pass: Generate tabline parts, abbreviating if needed
    for _, bufnr in ipairs(buffer_order) do
        local tab_info = tab_widths[bufnr]
        local buf_label = tab_info.full
        local display_width = tab_info.current_width

        if total_desired_width > available_width_for_labels then
            -- Abbreviate if total desired width exceeds available space
            local target_width_per_tab = math.floor(available_width_for_labels / num_listed_buffers)
            display_width = math.max(target_width_per_tab, min_width_per_tab)
            if vim.fn.strwidth(buf_label) > display_width then
                buf_label = string.sub(buf_label, 1, display_width - 1) .. "…"
                display_width = vim.fn.strwidth(buf_label)
            end
        elseif vim.fn.strwidth(buf_label) > initial_max_tab_width then
            buf_label = string.sub(buf_label, 1, initial_max_tab_width) .. "…"
            display_width = initial_max_tab_width
        end

        local label = string.format(' %-' .. display_width .. 's ', buf_label)
        if bufnr == current then
            table.insert(parts, '%#TabLineSel#' .. label)
        else
            table.insert(parts, '%#TabLine#' .. label)
        end
    end

    if #parts > 0 then
        vim.o.tabline = table.concat(parts, '%#TabLine#|') .. '%#TabLineFill#%='
    else
        vim.o.tabline = '%#TabLineFill#%='
    end
end

-- Get a list of valid, listed buffers (now obsolete, using buffer_order)
--local function get_listed_buffers()
--    local result = {}
--    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
--        if vim.api.nvim_buf_is_valid(bufnr) and vim.fn.buflisted(bufnr) == 1 then
--            table.insert(result, bufnr)
--        end
--    end
--    return result
--end

-- Show the tabline and schedule it to hide after timeout
local function manage_tabline()
    -- Stop any existing timer
    if hide_timer then
        if not hide_timer:is_closing() then
            hide_timer:stop()
            hide_timer:close()
        end
        hide_timer = nil
    end

    -- Update and show the tabline
    vim.o.showtabline = 2
    update_tabline_display()

    -- Create a new timer
    local timer = vim.loop.new_timer()
    if timer then
        hide_timer = timer
        hide_timer:start(1500, 0, vim.schedule_wrap(function()
            -- Only hide if still valid
            if vim.o.showtabline == 2 then
                vim.o.showtabline = 0
            end

            -- Clean up timer
            if hide_timer and not hide_timer:is_closing() then
                hide_timer:stop()
                hide_timer:close()
                hide_timer = nil
            end
        end))
    end
end

-- Safe command execution
local function safe_command(cmd)
    local status, _ = pcall(vim.api.nvim_command, cmd)
    return status
end

-- Navigate buffers safely
local function next_buffer()
    local current_buf = vim.api.nvim_get_current_buf()

    -- Use buffer_order instead of get_listed_buffers()
    --local listed_buffers = get_listed_buffers()
    local listed_buffers = buffer_order

    -- If we have multiple buffers
    if #listed_buffers > 1 then
        -- Try standard command first
        if not safe_command("silent! bnext") then
            -- If that fails, try to find next buffer manually
            local found_current = false
            local next_buf = nil

            for _, bufnr in ipairs(listed_buffers) do
                if found_current then
                    next_buf = bufnr
                    break
                end
                if bufnr == current_buf then
                    found_current = true
                end
            end

            -- Wrap around if needed
            if not next_buf and #listed_buffers > 0 then
                next_buf = listed_buffers[1]
            end

            -- Switch to the buffer if found
            if next_buf and next_buf ~= current_buf then
                vim.api.nvim_set_current_buf(next_buf)
            end
        end
    else
        vim.notify("No other buffers to navigate to", vim.log.levels.INFO)
    end

    -- Always update tabline
    manage_tabline()
end

local function prev_buffer()
    local current_buf = vim.api.nvim_get_current_buf()

    -- Use buffer_order instead of get_listed_buffers()
    --local listed_buffers = get_listed_buffers()
    local listed_buffers = buffer_order

    -- If we have multiple buffers
    if #listed_buffers > 1 then
        -- Try standard command first
        if not safe_command("silent! bprevious") then
            -- If that fails, try to find previous buffer manually
            local prev_buf = nil
            local found_index = nil

            -- Find current buffer index
            for i, bufnr in ipairs(listed_buffers) do
                if bufnr == current_buf then
                    found_index = i
                    break
                end
            end

            -- Get previous with wrap-around
            if found_index then
                if found_index > 1 then
                    prev_buf = listed_buffers[found_index - 1]
                else
                    prev_buf = listed_buffers[#listed_buffers]
                end
            end

            -- Switch to the buffer if found
            if prev_buf and prev_buf ~= current_buf then
                vim.api.nvim_set_current_buf(prev_buf)
            end
        end
    else
        vim.notify("No other buffers to navigate to", vim.log.levels.INFO)
    end

    -- Always update tabline
    manage_tabline()
end

local debounce_timer = nil
local debounce_delay = 100 -- milliseconds

local function debounced_update_tabline()
    if debounce_timer then
        debounce_timer:stop()
        debounce_timer:close()
    end
    debounce_timer = vim.uv.new_timer()
    if debounce_timer then
        debounce_timer:start(debounce_delay, 0, vim.schedule_wrap(function()
            update_tabline_display()
            debounce_timer = nil
        end))
    end
end

-- Setup function to initialize plugin
function M.setup(config)
    M.config = vim.tbl_deep_extend('force', {
        hide_timeout = 1500,
        show_tabline = true,
        next_key = '<Right>',
        prev_key = '<Left>',
    }, config or {})

    if M.config.show_tabline then
        vim.o.showtabline = 0
    end

    local ag = vim.api.nvim_create_augroup('BufferSwitcher', { clear = true })

    -- Update buffer order and tabline on relevant events
    vim.api.nvim_create_autocmd({ 'BufEnter' }, {
        group = ag,
        callback = function()
            local current_buf = vim.api.nvim_get_current_buf()
            add_buffer_to_order(current_buf)
            -- Move the current buffer to the end of the order
            local found_index = nil
            for i, bufnr in ipairs(buffer_order) do
                if bufnr == current_buf then
                    found_index = i
                    break
                end
            end
            if found_index and found_index < #buffer_order then
                table.remove(buffer_order, found_index)
                table.insert(buffer_order, current_buf)
            end
            if M.config.show_tabline and vim.o.showtabline == 2 then
                debounced_update_tabline()
            end
        end,
    })

    vim.api.nvim_create_autocmd({ 'BufAdd' }, {
        group = ag,
        callback = function(ev)
            add_buffer_to_order(ev.buf)
            if M.config.show_tabline and vim.o.showtabline == 2 then
                debounced_update_tabline()
            end
        end,
    })

    vim.api.nvim_create_autocmd({ 'BufDelete', 'BufWipeout' }, {
        group = ag,
        callback = function(ev)
            remove_buffer_from_order(ev.buf)
            if M.config.show_tabline and vim.o.showtabline == 2 then
                debounced_update_tabline()
            end
        end,
    })

    vim.keymap.set('n', M.config.next_key, next_buffer, { noremap = true, silent = true })
    vim.keymap.set('n', M.config.prev_key, prev_buffer, { noremap = true, silent = true })
end

return M
