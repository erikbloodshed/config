M = {}

function M.setup(opts)
    vim.opt_local.cinkeys:remove(":")
    vim.opt_local.cindent = true

    local config = require("cpp-tools.config").new()
    config:setup(opts)

    local build = require("cpp-tools.build").new(config)
    local arg = { buffer = vim.api.nvim_get_current_buf(), noremap = true }
    vim.keymap.set("n", "<leader>rc", function() build:compile() end, arg)
    vim.keymap.set("n", "<leader>rr", function() build:run() end, arg)
    vim.keymap.set("n", "<leader>ra", function() build:show_assembly() end, arg)
    vim.keymap.set("n", "<leader>fa", function() build:add_data_file() end, arg)
    vim.keymap.set("n", "<leader>fr", function() build:remove_data_file() end, arg)
end

return M
