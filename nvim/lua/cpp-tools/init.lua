local Config = require('cpp-tools.config')
local BuildTask = require('cpp-tools.build_task')

local buffer_tasks = {}
local config_instance = Config.new({}) -- Create a Config instance

local function get_buffer_task(bufnr)
    bufnr = bufnr or 0
    if not buffer_tasks[bufnr] then
        buffer_tasks[bufnr] = BuildTask.new(config_instance)
    end
    return buffer_tasks[bufnr]
end

M = {}

function M.setup(opts)
    vim.opt_local.cinkeys:remove(":")
    vim.opt_local.cindent = true

    config_instance:setup(opts) -- Use the instance's setup method

    local bufid = vim.api.nvim_get_current_buf()
    local task = get_buffer_task(bufid)
    local arg = { buffer = bufid, noremap = true }

    vim.keymap.set("n", "<leader>rc", function()
        task:compile()
    end, arg)
    vim.keymap.set("n", "<leader>rr", function()
        task:run()
    end, arg)
    vim.keymap.set("n", "<leader>ra", function()
        task:show_assembly()
    end, arg)
    vim.keymap.set("n", "<leader>fa", function()
        task:add_data_file()
    end, arg)
    vim.keymap.set("n", "<leader>fr", function()
        task:remove_data_file()
    end, arg)
end

return M
