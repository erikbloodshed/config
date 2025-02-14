return {
    "stevearc/conform.nvim",
    ft = { "c", "cpp", "lua", "python" },
    config = function()
        require("conform").setup({
            formatters_by_ft = {
                c = { "clang-format" },
                cpp = { "clang-format" },
                lua = { "stylua" },
                python = { "ruff_format" },
            },
            default_format_opts = { lsp_format = "never" },
        })
    end,
}
