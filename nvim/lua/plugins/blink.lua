return {
    "saghen/blink.cmp",
    event = { "InsertEnter", "CmdLineEnter" },
    build = "cargo +nightly build --release",

    ---@module 'blink.cmp'
    ---@type blink.cmp.Config
    opts = {
        completion = {
            accept = { auto_brackets = { enabled = false } },
            list = { selection = { preselect = true, auto_insert = false } },
            menu = {
                border = "rounded",
                scrollbar = false,
                draw = {
                    align_to = "label",
                    padding = 1,
                    gap = 4,
                    columns = { { "kind_icon" }, { "label" }, { "kind" }, { "source_name" } },
                },
            },
        },

        keymap = {
            preset = "none",
            ["<Tab>"] = { "select_and_accept", "snippet_forward", "fallback" },
            ["<S-Tab>"] = { "snippet_backward", "fallback" },
            ["<Up>"] = { "select_prev", "fallback" },
            ["<Down>"] = { "select_next", "fallback" },
            ["<C-p>"] = { "select_prev", "fallback" },
            ["<C-n>"] = { "select_next", "fallback" },
        },

        snippets = { preset = "default" },
        appearance = { use_nvim_cmp_as_default = false },
        sources = {
            default = { "lsp", "snippets", "path" },
            providers = {
                lsp = {
                    transform_items = function(_, items)
                        return vim.tbl_filter(function(item)
                            return not item.deprecated
                        end, items)
                    end,
                },
            },
        },
    },
}
