M = {}

function M.setup(opts)
    vim.opt_local.cinkeys:remove(":")
    vim.opt_local.cindent = true

    local config = require("cpp-tools.config").new() -- Create a Config instance
    config:setup(opts) -- Use the instance's setup method

    local task = require("cpp-tools.build_task").new(config)
    local arg = { buffer = vim.api.nvim_get_current_buf(), noremap = true }

    vim.keymap.set("n", "<leader>rc", function() task:compile() end, arg)
    vim.keymap.set("n", "<leader>rr", function() task:run() end, arg)
    vim.keymap.set("n", "<leader>ra", function() task:show_assembly() end, arg)
    vim.keymap.set("n", "<leader>fa", function() task:add_data_file() end, arg)
    vim.keymap.set("n", "<leader>fr", function() task:remove_data_file() end, arg)
end

return M
