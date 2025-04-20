return {
    "erikbloodshed/dressing.nvim",
    events = "VeryLazy",
    opts = {
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
            enabled = false,
            backend = { "nui" },
        },
    },
}
