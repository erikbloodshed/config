return {
    "stevearc/conform.nvim",
    ft = {"c", "cpp", "python", "lua"},
    opts = {
        formatters_by_ft = {
            c = { "clang-format" },
            cpp = { "clang-format" },
            lua = { "stylua" },
            python = { "ruff_format" },
        },
        default_format_opts = { lsp_format = "never" },
    },
}
