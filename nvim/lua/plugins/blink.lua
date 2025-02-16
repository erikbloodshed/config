return {
    "saghen/blink.cmp",
    event = "InsertEnter",
    build = "cargo +nightly build --release",
    dependencies = {
        {
            "L3MON4D3/LuaSnip",
            version = "v2.*",
            build = "make install_jsregexp",
            config = function()
                require("luasnip.loaders.from_vscode").lazy_load({
                    paths = { vim.fn.stdpath("config") .. "/snippets" },
                })
            end,
        },
    },

    ---@module 'blink.cmp'
    ---@type blink.cmp.Config
    opts = {
        completion = {
            accept = { auto_brackets = { enabled = true } },
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
        snippets = { preset = "luasnip" },
        appearance = { use_nvim_cmp_as_default = false },
        sources = {
            default = { "lazydev", "lsp", "snippets", "path" },
            providers = {
                lsp = {
                    transform_items = function(_, items)
                        return vim.tbl_filter(function(item)
                            return not item.deprecated
                        end, items)
                    end,
                },
                lazydev = {
                    name = "LazyDev",
                    module = "lazydev.integrations.blink",
                    score_offset = 100,
                },
            },
        },
    },
}
