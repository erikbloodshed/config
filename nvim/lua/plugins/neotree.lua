return {
    "nvim-neo-tree/neo-tree.nvim",
    enabled = true,
    keys = {
        {
            "<leader>ef",
            function()
                require("neo-tree.command").execute({
                    toggle = true,
                    reveal_force_cwd = true,
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
    dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-tree/nvim-web-devicons",
        "MunifTanjim/nui.nvim",
    },
    config = function()
        require("neo-tree").setup({
            enable_git_status = false,
            source_selector = {
                winbar = false,
                content_layout = "center",
                tabs_layout = "equal",
                show_separator_on_edge = true,
                sources = {
                    { source = "filesystem" },
                    { source = "buffers" },
                },
            },
            close_if_last_window = true,
            popup_border_style = "rounded",
            use_popups_for_input = true,
            filesystem = {
                bind_to_cwd = false,
                follow_current_file = { enabled = true },
                filtered_items = {
                    hide_by_pattern = { "*.out" },
                },
                use_libuv_file_watcher = false,
            },
            buffers = {
                bind_to_cwd = true,
                follow_current_file = {
                    enabled = true,
                    leave_dirs_open = false,
                },
                show_unloaded = true,
            },
            event_handlers = {
                {
                    event = "file_opened",
                    handler = function()
                        require("neo-tree.command").execute({ action = "close" })
                    end,
                },
                {
                    event = "neo_tree_popup_input_ready",
                    handler = function(args)
                        vim.keymap.set("i", "<esc>", vim.cmd.stopinsert, { noremap = true, buffer = args.bufnr })
                    end,
                },
                {
                    event = "neo_tree_buffer_enter",
                    handler = function()
                        vim.cmd("highlight! Cursor blend=100")
                        vim.opt.guicursor:append("a:Cursor/lCursor")
                    end,
                },
                {
                    event = "neo_tree_buffer_leave",
                    handler = function()
                        vim.cmd("highlight! Cursor blend=0")
                        vim.opt.guicursor:remove("a:Cursor/lCursor")
                    end,
                },
            },
        })

        vim.api.nvim_set_hl(0, "NeoTreeRootName", { fg = "#e0af68", italic = false, bold = true })
    end,
}
