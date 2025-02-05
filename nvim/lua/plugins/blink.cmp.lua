return {
    "saghen/blink.cmp",
    event = {"InsertEnter", "CmdLineEnter"},
    build = "cargo +nightly build --release",
    dependencies = "LuaSnip",

    ---@module 'blink.cmp'
    ---@type blink.cmp.Config
    opts = {
        completion = {
            accept = {auto_brackets = {enabled = false}},
            list = {selection = {preselect = true, auto_insert = false}},
            menu = {
                border = "rounded",
                scrollbar = false,
                draw = {
                    align_to = "label",
                    padding = 1,
                    gap = 4,
                    columns = {
                        {"kind_icon"}, {"label"}, {"kind"}, {"source_name"}
                    }
                }
            },
            ghost_text = {enabled = false}
        },
        keymap = {
            preset = "none",
            ["<Tab>"] = {"select_and_accept", "fallback"},
            ["<C-j>"] = {"snippet_forward", "fallback"},
            ["<C-k>"] = {"snippet_backward", "fallback"},
            ["<Up>"] = {"select_prev", "fallback"},
            ["<Down>"] = {"select_next", "fallback"},
            ["<C-p>"] = {"select_prev", "fallback"},
            ["<C-n>"] = {"select_next", "fallback"}
        },

        snippets = {preset = "luasnip"},

        appearance = {
            use_nvim_cmp_as_default = false,
            nerd_font_variant = "mono"
        },

        sources = {default = {"lsp", "snippets", "path"}}
    }
}
