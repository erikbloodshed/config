return {
    "stevearc/conform.nvim",

    keys = {
        {
            "<leader>fc",
            function()
                require("conform").format({ async = true })
            end,
        },
    },

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
