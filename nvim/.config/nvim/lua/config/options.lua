-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- OPTIONS
local set = vim.opt

--line nums
set.relativenumber = true
set.number = true

-- keep cursor at least 8 rows from top/bot
vim.scrolloff = 8

-- indentation and tabs
set.tabstop = 4
set.shiftwidth = 4
set.autoindent = true
set.expandtab = true

-- search settings
set.ignorecase = true
set.smartcase = true

-- cursor line
set.cursorline = true

--80th column
--set.colorcolumn = "80"
