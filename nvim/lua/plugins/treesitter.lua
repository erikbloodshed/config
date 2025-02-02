return {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
        require("nvim-treesitter.configs").setup({
            ensure_installed = {
                "bash",
                "c",
                "cpp",
                "fish",
                "rust",
                "lua",
                "markdown",
                "python",
                "query",
                "rust",
                "toml",
                "vim",
                "vimdoc",
            },
            ignore_install = { "javascript" },
            highlight = { enable = true },
            indent = { enable = false },
        })
    end,
}
