return {
    "stevearc/dressing.nvim",
    event = "VeryLazy",
    config = function()
        require("dressing").setup({
            input = {
                prompt_align = "center",
                relative = "cursor",
                start_in_insert = true,
                insert_only = false,
                mappings = {
                    n = {
                        ["<leader>q"] = "Close",
                    },
                },
            },
            select = {
                enabled = true,
                backend = { "nui" },
            },
        })
    end,
}
