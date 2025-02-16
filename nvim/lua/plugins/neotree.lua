return {
    "nvim-neo-tree/neo-tree.nvim",
    dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-tree/nvim-web-devicons",
        "MunifTanjim/nui.nvim",
    },

    config = function()
        local function hide_cursor()
            local hl = vim.api.nvim_get_hl(0, { name = "Cursor", link = false })
            vim.api.nvim_set_hl(0, "Cursor", { blend = 100, fg = hl.fg, bg = hl.bg })
            vim.opt.guicursor:append("a:Cursor/lCursor")
        end

        local function show_cursor()
            local hl = vim.api.nvim_get_hl(0, { name = "Cursor", link = false })
            vim.api.nvim_set_hl(0, "Cursor", { blend = 0, fg = hl.fg, bg = hl.bg })
            vim.opt.guicursor:remove("a:Cursor/lCursor")
        end

        require("neo-tree").setup({
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
            buffers = {
                bind_to_cwd = false,
                follow_current_file = {
                    enabled = true,
                    leave_dirs_open = false,
                },
                show_unloaded = false,
            },
            event_handlers = {
                {
                    event = "neo_tree_buffer_enter",
                    handler = function()
                        hide_cursor()
                    end,
                },
                {
                    event = "neo_tree_buffer_leave",
                    handler = function()
                        show_cursor()
                    end,
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
            },
        })

        vim.api.nvim_set_hl(0, "NeoTreeRootName", { fg = "#7aa2f7", italic = false, bold = true })
    end,

    keys = {
        {
            "<leader>ef",
            function()
                require("neo-tree.command").execute({
                    toggle = true,
                    dir = vim.fn.expand("%:p:h"),
                })
            end,
        },
        {
            "<leader>cc",
            function()
                require("neo-tree.command").execute({
                    toggle = true,
                    dir = vim.fn.stdpath("config"),
                })
            end,
        },
        {
            "<leader>eb",
            function()
                require("neo-tree.command").execute({
                    toggle = true,
                    position = "right",
                    source = "buffers",
                })
            end,
        },
    },
}
