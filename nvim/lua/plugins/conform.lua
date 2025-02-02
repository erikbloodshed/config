return {
    "stevearc/conform.nvim",
    event = "InsertEnter",
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
