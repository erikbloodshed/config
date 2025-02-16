return {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    opts = {
        ensure_installed = {
        "bash",
        "cpp",
        "fish",
        "python",
        "rust",
        "toml",
        },
        sync_install = false,
        indent = { enable = false },
    },
}
