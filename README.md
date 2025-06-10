# 💤 My LazyVim Configuration

This repository contains my personalized setup for [LazyVim](https://www.lazyvim.org/), a modern Neovim configuration framework built on top of [lazy.nvim](https://github.com/folke/lazy.nvim).

## 🔧 Overview

This configuration is designed to be modular, clean, and extendable. It builds on top of LazyVim and adds extra language support, editor enhancements, and customized behavior through Lua modules and plugin configurations.

### Core Files

- **`init.lua`**: The main entry point for Neovim. It bootstraps LazyVim and loads the custom configuration.
- **`lazyvim.json`**: Defines extra modules and features enabled in this setup, such as support for specific languages (Python, Go, SQL, etc.), editor tools (FZF, Telescope), and UI enhancements.
- **`lazy-lock.json`**: Automatically generated file that locks plugin versions for consistent installs.
- **`.neoconf.json`**: Stores Neoconf settings for workspace-specific configuration.
- **`stylua.toml`**: Configuration for formatting Lua code with StyLua.

### Lua Configuration Modules

All custom logic is organized under the `lua/` directory:

- **`config/`**:
  - `autocmds.lua`: Contains autocommands to automate behavior (e.g., auto formatting, highlighting).
  - `keymaps.lua`: Defines custom keybindings for improved workflow.
  - `lazy.lua`: Sets up LazyVim's plugin manager.
  - `options.lua`: Configures core Neovim options (e.g., line numbers, tab width).

- **`plugins/`**:
  - Each file corresponds to a specific plugin or plugin group, such as LSP support, additional language integrations, or interface tweaks.
  - Examples include configurations for `gopls`, `nvim-nu`, and more.

## 🌟 Features Enabled

This setup includes:

- **Editor tools**: FZF, Telescope, Prettier, Git integrations.
- **Language support**: Python, Go, SQL, Nushell.
- **UI and utility enhancements**: Dashboard.nvim, mini-hipatterns, VSCode compatibility.

## 🚀 Usage

1. Clone this repo to your Neovim config directory:
   ```bash
   git clone https://github.com/geo-afk/nvim/

