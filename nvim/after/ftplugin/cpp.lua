local function show_assembly()
    -- Get the current file path
    local file = vim.api.nvim_buf_get_name(0)
    if file == "" then
        vim.notify("No file detected!", vim.log.levels.ERROR)
        return
    end

    -- Define the output assembly file (temporary)
    local asm_file = "/tmp/output.s"

    local cmd = string.format(
        "g++ -std=c++20 -O2 -S -masm=intel " ..
        "'%s' -o '%s' && " ..
        "sed -E '/^\\s*\\./d; /^\\s*$/d' '%s' > '%s.cleaned' && " ..
        "mv '%s.cleaned' '%s'",
        file, asm_file, asm_file, asm_file, asm_file, asm_file
    )

    -- Run the command
    local result = vim.fn.system(cmd)

    -- Check for compilation errors
    if vim.v.shell_error ~= 0 then
        vim.notify("Compilation failed:\n" .. result, vim.log.levels.ERROR)
        return
    end

    -- Read the generated assembly file
    local asm_content = vim.fn.readfile(asm_file)

    -- Create a scratch buffer
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_option_value("buftype", "nofile", { scope = "local", buf = buf })
    vim.api.nvim_set_option_value("bufhidden", "hide", { scope = "local", buf = buf })
    vim.api.nvim_set_option_value("swapfile", false, { scope = "local", buf = buf })

    -- Set the assembly content in the buffer
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, asm_content)

    -- Set filetype to enable Tree-sitter highlighting
    vim.api.nvim_set_option_value("filetype", "asm", { scope = "local", buf = buf })

    -- Open the buffer in a new window
    vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = math.floor(vim.o.columns * 0.8),
        height = math.floor(vim.o.lines * 0.8),
        row = math.floor(vim.o.lines * 0.1),
        col = math.floor(vim.o.columns * 0.1),
        style = "minimal",
        border = "rounded",
        title = "Assembly Code"
    })
end

-- Map it to a key, e.g., <leader>a
vim.keymap.set("n", "<leader>aa", show_assembly, { noremap = true, silent = true })
