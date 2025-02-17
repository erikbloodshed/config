return {
    "folke/trouble.nvim",
    lazy = true,
    opts = {
        auto_close = true,
        auto_open = false,
        win = {
            size = {
                height = 5,
            },
        },
    },
    keys = {
        {
            "<leader>xx",
            function()
                require("trouble").toggle("diagnostics")
            end,
        },
    },
}
