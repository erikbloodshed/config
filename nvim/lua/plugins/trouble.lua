return {
    "folke/trouble.nvim",

    keys = {
        {
            "<leader>xx",
            function()
                require("trouble").toggle("diagnostics")
            end,
        },
    },

    opts = {
        auto_close = true,
        auto_open = false,
        win = {
            size = {
                height = 5,
            },
        },
    },
}
