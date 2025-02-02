return {
    "hrsh7th/nvim-cmp",
    event = "InsertEnter",

    dependencies = {
        "hrsh7th/cmp-nvim-lsp",
        "hrsh7th/cmp-nvim-lua",
        "saadparwaiz1/cmp_luasnip",
    },

    opts = function()
        local cmp = require("cmp")
        local compare = cmp.config.compare

        return {
            snippet = {
                expand = function(args)
                    require("luasnip").lsp_expand(args.body)
                end,
            },

            formatting = {
                fields = { "kind", "abbr", "menu" },

                format = function(entry, vim_item)
                    local symbol = {
                        Array = "󰅪",
                        Class = "󰠱",
                        Color = "󰏘",
                        Constant = "󰏿",
                        Constructor = "",
                        Enum = "",
                        EnumMember = "",
                        Event = "",
                        Field = "󰜢",
                        File = "󰈙",
                        Folder = "󰉋",
                        Function = "󰊕",
                        Interface = "",
                        Keyword = "󰌋",
                        Method = "󰆧",
                        Module = "",
                        Operator = "󰆕",
                        Property = "󰜢",
                        Reference = "",
                        Snippet = "",
                        Struct = "",
                        Text = "",
                        TypeParameter = "󰅲",
                        Unit = "",
                        Value = "󰎠",
                        Variable = "󰀫",
                    }

                    vim_item.kind = string.format("%s", symbol[vim_item.kind] or "")

                    local max_abbr = 35
                    local ellipsis = "..."
                    if vim.api.nvim_strwidth(vim_item.abbr) > max_abbr then
                        vim_item.abbr = vim.fn.strcharpart(vim_item.abbr, 0, max_abbr) .. ellipsis
                    end

                    vim_item.menu = "   " .. ({
                        buffer = "[Buffer]",
                        nvim_lsp = "[LSP]",
                        luasnip = "[LuaSnip]",
                        nvim_lua = "[Lua]"
                    })[entry.source.name]

                    return vim_item
                end,
            },

            view = {
                docs = {
                    auto_open = false,
                },
            },

            sources = {
                { name = "luasnip" },
                { name = "nvim_lua" },
                {
                    name = "lazydev",
                    group_index = 0,
                },
                {
                    name = "nvim_lsp",
                    entry_filter = function(entry)
                        return not entry:get_completion_item().deprecated
                    end,
                },
            },

            preselect = cmp.PreselectMode.Item,

            completion = {
                completeopt = "menu,menuone,noinsert",
            },

            window = {
                completion = cmp.config.window.bordered({
                    winhighlight = "Normal:Normal,FloatBorder:FloatBorder,CursorLine:PMenuSel,Search:None",
                    border = "rounded",
                    side_padding = 2,
                    scrollbar = false,
                    col_offset = -3
                }),
                documentation = cmp.config.window.bordered({
                    winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
                    border = "rounded",
                }),
            },

            mapping = {
                ["<Tab>"] = cmp.mapping.confirm({ select = false }),
                ["<C-n>"] = cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Select }),
                ["<C-p>"] = cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Select }),
            },

            sorting = {
                priority_weight = 2,
                comparators = {
                    compare.offset,
                    compare.exact,
                    compare.score,
                    compare.recently_used,
                    compare.locality,
                    compare.length,
                },
            },
        }
    end,

    config = function(_, opts)
        require("cmp").setup(opts)
        vim.keymap.set("s", "<BS>", "<C-O>s")
        vim.lsp.config("*", {
            capabilities = vim.tbl_deep_extend(
                "force",
                vim.lsp.protocol.make_client_capabilities(),
                require("cmp_nvim_lsp").default_capabilities()
            ),
        })
    end,
}
