local function open_terminal_in_file_directory()
    local current_file = vim.api.nvim_buf_get_name(0)
    if current_file ~= "" then
        local file_directory = vim.fn.fnamemodify(current_file, ":h")
        local original_directory = vim.fn.getcwd()

        vim.cmd("cd " .. file_directory .. " | term")

        vim.api.nvim_create_autocmd("TermClose", {
            callback = function()
                vim.cmd("cd " .. original_directory)
            end,
        })
    else
        vim.notify("No file open", vim.log.levels.WARN, { title = "Open Terminal" })
    end
end

vim.keymap.set( "n", "<leader>t", open_terminal_in_file_directory, { noremap = true, silent = true, nowait = true })
