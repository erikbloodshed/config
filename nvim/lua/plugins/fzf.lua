return {
    "ibhagwan/fzf-lua",

    keys = {
        {
            "<leader>ff",
            function()
                require("fzf-lua").files()
            end,
            { desc = "Fzf Files" }
        },
        {
            "<leader>fb",
            function()
            require("fzf-lua").buffers()
            end,
            { desc = "Fzf Buffers" }
        },
        {
        "<leader>cc",
        function()
           require("fzf-lua").files({ cwd = "~/.config/nvim" })
        end, { desc = "Neovim Config" }
        }
    },

    config = function()
        require("fzf-lua").setup({})
    end
}
