local compiler = require("cpp-tools.compiler")

local function get_buffer_hash()
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
    local content = table.concat(lines, "\n")
    return vim.fn.sha256(content)
end

local M = {}

function M.run(opts)
    local hash = get_buffer_hash()
    if vim.b.last_compiled_hash ~= hash then
        local success = compiler.compile(opts.compiler, opts.flags, opts.outfile, opts.infile, opts.ext)
        if not success then return end
        vim.b.last_compiled_hash = hash
    end

    vim.cmd.terminal()
    vim.defer_fn(function()
        local out = opts.outfile
        if opts.data_ref[1] then
            out = out .. " < " .. opts.data_ref[1]
        end
        if vim.b.terminal_job_id then
            vim.api.nvim_chan_send(vim.b.terminal_job_id, out .. "\n")
        end
    end, 50)
end

return M
