return {
    "L3MON4D3/LuaSnip",
    event = "InsertEnter",
    build = "make install_jsregexp",

    config = function()
        local luasnip_loaders = require("luasnip.loaders.from_lua")
        local luasnip = require("luasnip")

        luasnip_loaders.lazy_load({
            paths = { vim.fn.stdpath("config") .. "/luasnippets" },
        })

        vim.api.nvim_create_user_command("LuaSnipEdit", function()
            require("luasnip.loaders").edit_snippet_files()
        end, {})

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
