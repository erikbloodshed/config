return {
    "folke/trouble.nvim",
    event = "LspAttach",
    opts = {
        auto_close = true, -- auto close when there are no items
        auto_open = false, -- auto open when there are items
        win = {
            size = {
                height = 5,
            },
        }, -- window options for the results window. Can be a split or a floating window.
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
