return {
    "L3MON4D3/LuaSnip",
    config = function()
        local luasnip_loaders = require("luasnip.loaders.from_vscode")
        local luasnip = require("luasnip")

        luasnip_loaders.lazy_load({ paths = vim.fn.stdpath("config") .. "/snippets" })

        vim.keymap.set({ "i", "s" }, "<C-j>", function()
            if luasnip.jumpable(1) then
                luasnip.jump(1)
            end
        end)

        vim.keymap.set({ "i", "s" }, "<C-k>", function()
            if luasnip.jumpable(-1) then
                luasnip.jump(-1)
            end
        end)
    end,
}
