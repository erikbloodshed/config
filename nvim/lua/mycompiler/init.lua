local config = require('mycompiler.config')
local BuildTask = require('mycompiler.build_task')
local data_selector = require('mycompiler.data_selector')

local buffer_tasks = {}

local function get_buffer_task(bufnr)
    bufnr = bufnr or 0
    if not buffer_tasks[bufnr] then
        buffer_tasks[bufnr] = BuildTask.new()
    end
    return buffer_tasks[bufnr]
end

config.setup({})

vim.api.nvim_create_autocmd("Filetype", {
    pattern = config.config.filetypes,
    callback = function(args)
        local task = get_buffer_task(args.buf)

        vim.opt_local.cinkeys:remove(":")
        vim.opt_local.cindent = true

        vim.keymap.set("n", "<leader>rc", function() task:compile() end, { buffer = args.buf, noremap = true })
        vim.keymap.set("n", "<leader>rr", function() task:run() end, { buffer = args.buf, noremap = true })
        vim.keymap.set("n", "<leader>ra", function() task:show_assembly() end, { buffer = args.buf, noremap = true })
        vim.keymap.set("n", "<leader>fa", function() data_selector.add(task) end, { buffer = args.buf, noremap = true })
        vim.keymap.set("n", "<leader>fr", function() data_selector.remove(task) end, { buffer = args.buf, noremap = true })
    end,
})
