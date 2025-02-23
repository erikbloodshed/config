vim.g.loaded_node_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_python3_provider = 0
vim.g.loaded_ruby_provider = 0

if vim.fn.has("wsl") == 1 then
    vim.g.clipboard = {
        name = "WslClipboard",
        copy = {
            ["+"] = "clip.exe",
            ["*"] = "clip.exe",
        },
        paste = {
            ["+"] = 'powershell.exe -c [Console]::Out.Write($(Get-Clipboard -Raw).tostring().replace("`r", ""))',
            ["*"] = 'powershell.exe -c [Console]::Out.Write($(Get-Clipboard -Raw).tostring().replace("`r", ""))',
        },
        cache_enabled = false,
    }
else
    vim.o.clipboard = "unnamedplus"
end

vim.o.updatetime = 300
vim.o.timeoutlen = 500
vim.o.ttimeoutlen = 10
vim.o.swapfile = false
vim.o.hidden = true
vim.o.history = 100
vim.o.number = true
vim.o.showtabline = 0
vim.o.splitright = true
vim.o.synmaxcol = 128
vim.o.autowrite = true
vim.wo.signcolumn = "yes"
vim.wo.cursorlineopt = "both"
vim.wo.cursorline = true

vim.o.expandtab = true
vim.o.shiftwidth = 4
vim.o.smartindent = false
vim.o.smarttab = false
vim.o.softtabstop = 4
vim.o.tabstop = 4
vim.o.wrap = false

vim.opt.viewoptions:append({ options = true })
vim.opt.shortmess:append({ c = true, C = true })
vim.opt.formatoptions:remove({ "c", "r", "o" })
