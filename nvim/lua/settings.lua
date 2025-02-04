vim.g.loaded_node_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_python3_provider = 0
vim.g.loaded_ruby_provider = 0

vim.o.clipboard = "unnamedplus"
if vim.fn.has("wsl") == 1 then
    vim.o.clipboard = {
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
end

vim.o.updatetime = 300
vim.o.timeoutlen = 500
vim.o.ttimeoutlen = 10
vim.o.cursorline = true
vim.o.cursorlineopt = "both"
vim.o.hidden = true
vim.o.history = 100
vim.o.number = true
vim.o.showtabline = 0
vim.o.splitright = true
vim.o.swapfile = false
vim.o.synmaxcol = 128
vim.wo.signcolumn = "yes"

vim.o.expandtab = true
vim.o.shiftwidth = 4
vim.o.smartindent = false
vim.o.smarttab = false
vim.o.softtabstop = 4
vim.o.tabstop = 4
vim.o.wrap = false

vim.opt.viewoptions:append({ options = true })
vim.opt.shortmess:append({ c = true, C = true })
