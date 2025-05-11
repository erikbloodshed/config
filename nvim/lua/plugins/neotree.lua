local hl = vim.api.nvim_get_hl(0, { name = "Cursor", link = false })

local function hide_cursor()
    vim.api.nvim_set_hl(0, "Cursor", { blend = 100, fg = hl.fg, bg = hl.bg })
    vim.opt.guicursor:append("a:Cursor/lCursor")
end

local function show_cursor()
    vim.api.nvim_set_hl(0, "Cursor", { blend = 0, fg = hl.fg, bg = hl.bg })
    vim.opt.guicursor:remove("a:Cursor/lCursor")
end

return {
    "nvim-neo-tree/neo-tree.nvim",
    dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-tree/nvim-web-devicons",
        "MunifTanjim/nui.nvim",
    },
    opts = {
        source_selector = {
            winbar = false,
            statusline = false,
        },
        close_if_last_window = true,
        popup_border_style = "rounded",
        filesystem = {
            bind_to_cwd = false,
            follow_current_file = { enabled = true },
            filtered_items = {
                hide_by_pattern = { "*.out" },
            },
            use_libuv_file_watcher = false,
        },
        event_handlers = {
            {
                event = "neo_tree_buffer_enter",
                handler = hide_cursor,
            },
            {
                event = "neo_tree_buffer_leave",
                handler = show_cursor,
            },
            {
                event = "file_opened",
                handler = function()
                    require("neo-tree.command").execute({ action = "close" })
                end,
            },
            {
                event = "neo_tree_popup_input_ready",
                handler = function(args)
                    show_cursor()
                    vim.keymap.set("i", "<esc>", vim.cmd.stopinsert, { buffer = args.bufnr })
                end,
            },
            {
                event = "neo_tree_popup_buffer_enter",
                handler = function(args)
                    show_cursor()
                    vim.keymap.set("i", "<esc>", vim.cmd.startinsert, { buffer = args.bufnr })
                end,
            },
        },
    },
    keys = {
        {
            "<leader>ef",
            function()
                local exclude_ft = { query = true, checkhealth = true, help = true }
                require("neo-tree.command").execute({
                    toggle = true,
                    dir = exclude_ft[vim.bo.filetype] and vim.fn.getcwd() or vim.fn.expand("%:p:h"),
                })
            end,
        },
        {
            "<leader>ec",
            function()
                require("neo-tree.command").execute({
                    toggle = true,
                    dir = vim.fn.stdpath("config"),
                })
            end,
        },
    },
}
