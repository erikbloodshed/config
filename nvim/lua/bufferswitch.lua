-- Simple buffer switcher with tabs display
local M = {}

local hide_timer = nil

local function format_buffer_name(bufnr)
    local name = vim.fn.bufname(bufnr)
    return name == '' and '[No Name]' or vim.fn.fnamemodify(name, ':t')
end

local function draw_buffer_line()
    local buffers = vim.api.nvim_list_bufs()
    local current_buf = vim.api.nvim_get_current_buf()
    local line_parts = {}

    for _, bufnr in ipairs(buffers) do
        if vim.fn.buflisted(bufnr) == 1 then
            local buf_name = format_buffer_name(bufnr)
            local part = ""
            if bufnr == current_buf then
                part = "%#TabLineSel# " .. buf_name .. " %#TabLine#"
            else
                part = "%#TabLine# " .. buf_name .. " "
            end
            table.insert(line_parts, part)
        end
    end

    vim.o.tabline = table.concat(line_parts)
end

local function show_tabline()
    if vim.o.showtabline ~= 2 then
        vim.o.showtabline = 2
        draw_buffer_line()
    end
end

local function hide_tabline()
    vim.schedule(function()
        vim.o.showtabline = 0
    end)
end

local function manage_tabline()
    if hide_timer and hide_timer > 0 then
        vim.fn.timer_stop(hide_timer)
        hide_timer = nil
    end

    show_tabline()

    hide_timer = vim.fn.timer_start(2000, hide_tabline)
end

local function next_buffer()
    vim.cmd('bnext')
    manage_tabline()
end

local function prev_buffer()
    vim.cmd('bprevious')
    manage_tabline()
end

function M.setup()
    vim.o.showtabline = 0

    local augroup = vim.api.nvim_create_augroup("BufferSwitcher", { clear = true })

    vim.api.nvim_create_autocmd({ "BufEnter", "BufAdd", "BufDelete" }, {
        group = augroup,
        callback = function()
            if vim.o.showtabline == 2 then
                draw_buffer_line()
            end
        end,
    })

    vim.keymap.set('n', '<Right>', next_buffer, { noremap = true, silent = true })
    vim.keymap.set('n', '<Left>', prev_buffer, { noremap = true, silent = true })
end

return M
