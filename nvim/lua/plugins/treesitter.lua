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
            sync_install = false,
            ignore_install = { "javascript" },
            highlight = { enable = true },
            indent = { enable = false },
        })
    end,
}
