-- BufferSwitcher: buffer switcher using NerdFont icons and temporary tabline
local M = {}

-- Timer handle for hiding the tabline
local hide_timer = nil

-- Attempt to load nvim-web-devicons for NerdFont icons
local has_devicons, devicons = pcall(require, 'nvim-web-devicons')

-- Format buffer name with NerdFont icon
local function format_buffer_name(bufnr)
    local name = vim.fn.bufname(bufnr)
    local display_name = vim.fn.fnamemodify(name, ':t')
    if display_name == '' then
        display_name = '[No Name]'
    end

    local ext = display_name:match('%.([^%.]+)$') or ''
    local icon = ''
    if has_devicons then
        icon = devicons.get_icon(display_name, ext, { default = true }) or ''
    end

    return (icon ~= '' and icon .. ' ' or '') .. display_name
end

-- Update the tabline with buffer names separated by pipes
local function update_tabline_display()
    local buffers = vim.api.nvim_list_bufs()
    local current = vim.api.nvim_get_current_buf()
    local parts = {}

    for _, bufnr in ipairs(buffers) do
        if vim.fn.buflisted(bufnr) == 1 then
            local buf_label = format_buffer_name(bufnr)
            local label = string.format(' %s ', buf_label)
            if bufnr == current then
                table.insert(parts, '%#TabLineSel#' .. label)
            else
                table.insert(parts, '%#TabLine#' .. label)
            end
        end
    end

    -- Join with separator
    vim.o.tabline = table.concat(parts, '%#TabLine#|') .. '%#TabLineFill#'
end

-- Show the tabline and schedule it to hide after timeout
local function manage_tabline()
    if hide_timer then
        hide_timer:stop()
        hide_timer:close()
        hide_timer = nil
    end

    vim.o.showtabline = 2
    update_tabline_display()

    local timer = vim.uv.new_timer()
    if timer then
        hide_timer = timer
        hide_timer:start(1500, 0, vim.schedule_wrap(function()
            vim.o.showtabline = 0
            if hide_timer then
                hide_timer:stop()
                hide_timer:close()
                hide_timer = nil
            end
        end))
    end
end

-- Navigate buffers and show tabline
local function next_buffer()
    vim.cmd('bnext')
    manage_tabline()
end

local function prev_buffer()
    vim.cmd('bprevious')
    manage_tabline()
end

-- Setup function to initialize plugin
function M.setup()
    vim.o.showtabline = 0

    local ag = vim.api.nvim_create_augroup('BufferSwitcher', { clear = true })
    vim.api.nvim_create_autocmd({ 'BufEnter', 'BufAdd', 'BufDelete' }, {
        group = ag,
        callback = function()
            if vim.o.showtabline == 2 then
                update_tabline_display()
            end
        end,
    })

    vim.keymap.set('n', '<Right>', next_buffer, { noremap = true, silent = true })
    vim.keymap.set('n', '<Left>', prev_buffer, { noremap = true, silent = true })
end

return M
