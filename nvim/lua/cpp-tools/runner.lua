local compiler_utils = require("cpp-tools.compiler")

local M = {}

function M.run(opts)
    if compiler_utils.compile(opts.compiler, opts.flags, opts.outfile, opts.infile, opts.ext) then
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
end

return M
