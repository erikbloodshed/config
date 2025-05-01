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

vim.cmd.colorscheme("tokyonight")

require("options")
require("autocmds")
require("ui")
-- Load the plugin module (if saved in lua/basic-diagnostics/init.lua)
-- If you saved it directly in the plugin/ directory, Neovim loads it automatically.
local basic_diagnostics = require('basic-diagnostics')

-- Create user commands for easier access
vim.api.nvim_create_user_command(
  'BasicDiagnosticsToggle',
  function() basic_diagnostics.toggle() end,
  { desc = 'Toggle Basic Diagnostics window' }
)
vim.api.nvim_create_user_command(
  'BasicDiagnosticsOpen',
  function() basic_diagnostics.open() end,
  { desc = 'Open Basic Diagnostics window' }
)
vim.api.nvim_create_user_command(
  'BasicDiagnosticsClose',
  function() basic_diagnostics.close() end,
  { desc = 'Close Basic Diagnostics window' }
)

-- Example keymap to toggle the window (customize as needed)
-- <leader> usually maps to '\' or ' ' (space)
vim.keymap.set('n', '<leader>dd', '<Cmd>BasicDiagnosticsToggle<CR>', { desc = '[D]iagnostics [D]isplay Toggle' })

print("Basic Diagnostics plugin loaded and mapped.") -- Optional confirmation

vim.lsp.enable({"basedpyright", "clangd", "luals"})
