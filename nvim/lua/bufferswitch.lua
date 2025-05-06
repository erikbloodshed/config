-- Simple buffer switcher with tabs display
-- This script provides:
-- 1. Arrow key mappings to switch buffers
-- 2. A simple buffer line display at the top of the screen that appears temporarily

local M = {}

-- Store the timer reference globally to avoid garbage collection
local hide_timer = nil

-- Function to format the buffer name for display
local function format_buffer_name(bufnr)
    local name = vim.fn.bufname(bufnr)
    if name == '' then
        return '[No Name]'
    else
        return vim.fn.fnamemodify(name, ':t') -- Show only the filename
    end
end

-- Function to draw the buffer line
local function draw_buffer_line()
    local buffers = vim.api.nvim_list_bufs()
    local current_buf = vim.api.nvim_get_current_buf()
    local line = ""

    for _, bufnr in ipairs(buffers) do
        -- Only show listed buffers
        if vim.fn.buflisted(bufnr) == 1 then
            local buf_name = format_buffer_name(bufnr)
            -- Highlight the current buffer
            if bufnr == current_buf then
                line = line .. "%#TabLineSel# " .. buf_name .. " %#TabLine#"
            else
                line = line .. "%#TabLine# " .. buf_name .. " "
            end
        end
    end

    -- Set the tabline
    vim.o.tabline = line
end

-- Function to manage tabline visibility
local function manage_tabline()
    -- Ensure tabline is visible
    if vim.o.showtabline ~= 2 then
        vim.o.showtabline = 2
    end

    -- Clear any pending timer
    if hide_timer and hide_timer > 0 then
        vim.fn.timer_stop(hide_timer)
        hide_timer = nil
    end

    -- Update the buffer line display
    draw_buffer_line()

    -- Set up the timer to hide the tabline after delay
    hide_timer = vim.fn.timer_start(2000, function()
        -- We need to use vim.schedule to modify vim options from a timer callback
        vim.schedule(function()
            vim.o.showtabline = 0
        end)
    end)
end

-- Function to switch to the next buffer
local function next_buffer()
    vim.cmd('bnext')
    manage_tabline()
end

-- Function to switch to the previous buffer
local function prev_buffer()
    vim.cmd('bprevious')
    manage_tabline()
end

-- Setup function to initialize the buffer switcher
function M.setup()
    -- Default to hidden tabline
    vim.o.showtabline = 0

    -- Create an autocommand group
    local augroup = vim.api.nvim_create_augroup("BufferSwitcher", { clear = true })

    -- Update tabline when buffers change (if it's visible)
    vim.api.nvim_create_autocmd({ "BufEnter", "BufAdd", "BufDelete" }, {
        group = augroup,
        callback = function()
            if vim.o.showtabline == 2 then
                draw_buffer_line()
            end
        end,
    })

    -- Map keys for buffer navigation
    vim.keymap.set('n', '<Right>', next_buffer, { noremap = true, silent = true })
    vim.keymap.set('n', '<Left>', prev_buffer, { noremap = true, silent = true })
end

return M
