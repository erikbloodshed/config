return {
    "kylechui/nvim-surround",
    event = "InsertEnter",
    version = "*", -- Use for stability; omit to use `main` branch for the latest features
    ft = { "c", "cpp", "lua" },
    config = function()
        require("nvim-surround").setup({})
    end,
}
