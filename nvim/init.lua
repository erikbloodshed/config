--[[
   ▄▄▄▄    ██▓     ▒█████   ▒█████  ▓█████▄   ██████  ██░ ██ ▓█████ ▓█████▄
  ▓█████▄ ▓██▒    ▒██▒  ██▒▒██▒  ██▒▒██▀ ██▌▒██    ▒ ▓██░ ██▒▓█   ▀ ▒██▀ ██▌
  ▒██▒ ▄██▒██░    ▒██░  ██▒▒██░  ██▒░██   █▌░ ▓██▄   ▒██▀▀██░▒███   ░██   █▌
  ▒██░█▀  ▒██░    ▒██   ██░▒██   ██░░▓█▄   ▌  ▒   ██▒░▓█ ░██ ▒▓█  ▄ ░▓█▄   ▌
  ░▓█  ▀█▓░██████▒░ ████▓▒░░ ████▓▒░░▒████▓ ▒██████▒▒░▓█▒░██▓░▒████▒░▒████▓
  ░▒▓███▀▒░ ▒░▓  ░░ ▒░▒░▒░ ░ ▒░▒░▒░  ▒▒▓  ▒ ▒ ▒▓▒ ▒ ░ ▒ ░░▒░▒░░ ▒░ ░ ▒▒▓  ▒
▒░▒   ░ ░ ░ ▒  ░  ░ ▒ ▒░   ░ ▒ ▒░  ░ ▒  ▒ ░ ░▒  ░ ░ ▒ ░▒░ ░ ░ ░  ░ ░ ▒  ▒
 ░    ░   ░ ░   ░ ░ ░ ▒  ░ ░ ░ ▒   ░ ░  ░ ░  ░  ░   ░  ░░ ░   ░    ░ ░  ░
 ░          ░  ░    ░ ░      ░ ░     ░          ░   ░  ░  ░   ░  ░   ░
      ░                            ░                               ░
--]]

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not vim.uv.fs_stat(lazypath) then
    vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable",
        lazypath,
    })
end

vim.opt.rtp = vim.opt.rtp ^ lazypath

require("autocmds")
require("options")
require("picker")
require("input")
require("cpp_utils")

require("lazy").setup({
    spec = "plugins",

    ui = {
        border = "rounded",
    },

    performance = {
        rtp = {
            disabled_plugins = {
                "gzip",
                "man",
                "rplugin",
                "netrwPlugin",
                "spellfile",
                "tarPlugin",
                "tutor",
                "zipPlugin",
                "osc52",
            },
        },
    },

    change_detection = {
        enabled = false,
        notify = false,
    },
})

vim.lsp.enable({"basedpyright", "clangd", "luals"})
vim.cmd.colorscheme("tokyonight")
