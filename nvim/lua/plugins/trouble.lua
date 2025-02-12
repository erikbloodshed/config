return {
    "folke/trouble.nvim",
    event = "LspAttach",
    config = function()
        local trouble = require("trouble")
        require("trouble").setup({
            auto_close = true, -- auto close when there are no items
            auto_open = false, -- auto open when there are items
            win = {
                size = {
                    height = 5,
                },
            }, -- window options for the results window. Can be a split or a floating window.
        })
        vim.keymap.set("n", "<leader>xx", function() trouble.toggle("diagnostics") end)
    end,
}
