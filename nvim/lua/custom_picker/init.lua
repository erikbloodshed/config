vim.api.nvim_set_hl(0, "CustomPickerSelection", { link = "Visual" })

local M = {}

---@class CustomPicker
---@field items table[]
---@field win integer
---@field buf integer
---@field selected integer
---@field actions table
---@field on_close function
local Picker = {}
Picker.__index = Picker

function Picker:close()
    if vim.api.nvim_win_is_valid(self.win) then
        vim.api.nvim_win_close(self.win, true)
    end
    if vim.api.nvim_buf_is_valid(self.buf) then
        vim.api.nvim_buf_delete(self.buf, { force = true })
    end
end

function Picker:update_highlight()
    vim.api.nvim_buf_clear_namespace(self.buf, self.ns, 0, -1)
    vim.api.nvim_buf_add_highlight(self.buf, self.ns, "CustomPickerSelection", self.selected - 1, 0, -1)
end

function Picker:move(delta)
    local old_idx = self.selected
    local new_idx = math.max(1, math.min(old_idx + delta, #self.items))
    self.selected = new_idx
    vim.api.nvim_win_set_cursor(self.win, { new_idx, 0 })
    self:update_highlight()
end

---@param opts {items: table[], title: string, actions: table, on_close: function}
function M.pick(opts)
    local lines = {}
    local max_width = 0
    for _, item in ipairs(opts.items) do
        local line = item.text or tostring(item)
        table.insert(lines, line)
        max_width = math.max(max_width, vim.fn.strdisplaywidth(line))
    end

    local padding = 2
    local width = math.min(max_width + padding, vim.o.columns - 4)
    local height = math.min(#lines, 10)
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

    local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = width,
        height = height,
        row = row,
        col = col,
        border = "rounded",
        style = "minimal",
        title = opts.title or "Select",
    })

    local picker = setmetatable({
        buf = buf,
        win = win,
        ns = vim.api.nvim_create_namespace("custom_picker"),
        items = opts.items,
        selected = 1,
        actions = opts.actions or {},
        on_close = opts.on_close or function() end,
    }, Picker)

    picker:update_highlight()

    vim.api.nvim_win_set_cursor(win, { 1, 0 })

    vim.keymap.set("n", "j", function() picker:move(1) end, { buffer = buf, nowait = true })
    vim.keymap.set("n", "k", function() picker:move(-1) end, { buffer = buf, nowait = true })
    vim.keymap.set("n", "<CR>", function()
        if picker.actions.confirm then
            picker.actions.confirm(picker, picker.items[picker.selected])
        else
            picker:close()
        end
    end, { buffer = buf })

    vim.keymap.set("n", "q", function()
        picker:close()
        picker.on_close()
    end, { buffer = buf })

    vim.keymap.set("n", "<Esc>", function()
        picker:close()
        picker.on_close()
    end, { buffer = buf })

    return picker
end

return M
