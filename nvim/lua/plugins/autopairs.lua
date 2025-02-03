return {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    config = function()
        if pcall(require, "cmp") then
            local autopairs = require("nvim-autopairs")
            local cmp_autopairs = require("nvim-autopairs.completion.cmp")
            local cmp = require("cmp")

            autopairs.setup({
                map_cr = true,
            })

            -- cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done())
            local handlers = require("nvim-autopairs.completion.handlers")

            cmp.event:on(
                "confirm_done",
                cmp_autopairs.on_confirm_done({
                    filetypes = {
                        -- "*" is a alias to all filetypes
                        ["*"] = {
                            ["("] = {
                                kind = {
                                    cmp.lsp.CompletionItemKind.Function,
                                    cmp.lsp.CompletionItemKind.Method,
                                },
                                handler = handlers["*"],
                            },
                        },
                    },
                })
            )
        else
            require("nvim-autopairs").setup({ map_cr = true })
        end
    end,
}
