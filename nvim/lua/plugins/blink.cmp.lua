return {
    "saghen/blink.cmp",
    event = { "InsertEnter", "CmdLineEnter" },
    build = "cargo +nightly build --release",
    dependencies = "LuaSnip",

    ---@module 'blink.cmp'
    ---@type blink.cmp.Config
    opts = {
        completion = {
            accept = {
                auto_brackets = { enabled = false },
            },
            list = { selection = { preselect = false, auto_insert = false } },
            menu = {
                border = "rounded",
                scrollbar = false,
                draw = {
                    align_to = "label", -- or 'none' to disable
                    padding = 1,
                    gap = 4,
                    columns = { { "kind_icon" }, { "label" }, { "kind" }, { "source_name" } },
                },
            },
            ghost_text = {
                enabled = true,
            },
        },
        keymap = {
            preset = "none",
            ["<Tab>"] = { "select_next", "snippet_forward", "fallback" },
            ["S-<Tab>"] = { "select_prev", "snippet_backward", "fallback" },
            ["<CR>"] = { "accept" , "fallback" },
            ["<Up>"] = { "select_prev", "fallback" },
            ["<Down>"] = { "select_next", "fallback" },
            ["<C-p>"] = { "select_prev", "fallback" },
            ["<C-n>"] = { "select_next", "fallback" },
        },

        snippets = { preset = "luasnip" },

        appearance = {
            -- Sets the fallback highlight groups to nvim-cmp's highlight groups
            -- Useful for when your theme doesn't support blink.cmp
            -- Will be removed in a future release
            use_nvim_cmp_as_default = false,
            -- Set to 'mono' for 'Nerd Font Mono' or 'normal' for 'Nerd Font'
            -- Adjusts spacing to ensure icons are aligned
            nerd_font_variant = "mono",
        },

        -- Default list of enabled providers defined so that you can extend it
        -- elsewhere in your config, without redefining it, due to `opts_extend`
        sources = {
            default = { "lsp", "snippets", "path" },
        },
    },
}
