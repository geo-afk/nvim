# Neovim 0.12 Configuration

This repository is a personal Neovim setup built around **Neovim 0.12**, the
native **`vim.pack`** plugin manager, and a fairly large set of **custom UI
modules** that replace or extend the stock editor experience.

## At a Glance

> [!IP]
> **Main UI Overview Image Placeholder**
> _Insert a screenshot showing the dashboard/editor with explorer, statusline, and tabline visible._

- Requires **Neovim >= 0.12**
- Replaces `lazy.nvim` or `packer.nvim`
- Uses **Mason** for installing many LSP servers and CLI tools
- Uses **native `vim.lsp.config()` / `vim.lsp.enable()`**
- **Integrated Task Runner:** [overseer.nvim](https://github.com/stevearc/overseer.nvim) with custom templates for Go, Node, and Angular.
- **Full Debugging Suite:** [nvim-dap](https://github.com/mfussenegger/nvim-dap) with UI, virtual text, and language-specific adapters.
- Ships several custom UI modules:
  - file explorer
  - floating command line / search UI
  - custom code action picker
  - custom statusline with partial invalidation
  - custom tabline (bufferline)
  - persistent session manager
  - GUI plugin manager for `vim.pack`
  - managed terminal panel with profile support
  - floating terminal wrapper used by LazyGit and Go tools
  - Markdown preview via Glow
- Includes language-specific extras for:
  - Go
  - Markdown
  - Angular templates / Angular project detection

## Requirements

### Hard requirements

- Neovim `0.12.x` or newer
- `git`
- A Nerd Font-enabled terminal

### Strongly recommended

- `make`
  - used to build `telescope-fzf-native.nvim`
- `pwsh` or `nu`
  - the config has Windows-oriented shell setup and will prefer `nu`, then `pwsh`
- `lazygit`
  - required for `<leader>gg`
- `chafa`
  - optional image preview backend used by `<leader>ii` / `:ChafaImage`
- `glow`
  - required for Markdown preview features (`<leader>ip`)

### Optional but used by specific features

- `ng`
  - used by the Angular dev server preset (`ng serve`)
- `scooter`
  - used by ToggleTerm integrations for project search
- `sleek`
  - SQL formatter used by Conform
- `sqruff`
  - SQL linter used by `nvim-lint`
- `htmlhint`
  - HTML linter used by `nvim-lint`

### Debugging & Task Runner Tools

- **Go (Delve):** `go install github.com/go-delve/delve/cmd/dlv@latest`
- **Node / TS / Angular:** [vscode-js-debug](https://github.com/microsoft/vscode-js-debug) installed to `%LOCALAPPDATA%\nvim-data\vscode-js-debug`
- **Go workflow tools:** `gotests`, `gomodifytags`, `iferr`, `gotestsum`, `fillstruct`, `fillswitch`, `govulncheck`

## Installation

### 1. Install this config

Linux / macOS:

```bash
mv ~/.config/nvim ~/.config/nvim.bak
git clone https://github.com/geo-afk/nvijm ~/.config/nvim
```

Windows:

```powershell
Rename-Item $env:LOCALAPPDATA\nvim $env:LOCALAPPDATA\nvim.bak
git clone https://github.com/geo-afk/nvijkim $env:LOCALAPPDATA\nvim
```

### 2. Start Neovim

On first launch, `vim.pack` will install plugins. Mason will also begin
installing many configured language servers and tools.

### 3. Verify the basics

Inside Neovim:

```vim
:checkhealth
:checkhealth vim.lsp
:Mason
:LspConfigs
:PackManager
```

## Repository Layout

```text
.
├── init.lua
├── README.md
├── nvim-pack-lock.json
├── after/
│   ├── ftplugin/
│   │   └── markdown.lua
│   ├── queries/
│   │   └── go/
│   └── syntax/
│       ├── go.vim
│       └── qf.nvim
├── ftplugin/
│   ├── go.lua
│   └── help.lua
└── lua/
    ├── config/
    │   ├── autocmds.lua
    │   ├── keymaps.lua
    │   ├── lsp.lua
    │   ├── neovide.lua
    │   ├── options.lua
    │   └── ui.lua
    ├── custom/
    │   ├── autoclose.lua
    │   ├── glow.lua
    │   ├── image_view.lua
    │   ├── lazygit.lua
    │   ├── codelens.lua
    │   ├── cmdline/
    │   ├── code_action/
    │   ├── explorer/
    │   ├── float_term/
    │   ├── lsp_keymapper/
    │   ├── pack_manager/
    │   ├── session/
    │   ├── statusline/
    │   ├── tabline/
    │   └── terminal_manager/
    ├── overseer/                      ← task runner templates (Go, Node, Angular)
    ├── plugins/
    │   ├── dap.lua                    ← debugger config
    │   └── overseer.lua               ← task runner config
    └── utils/
```

## Startup Flow

`init.lua` loads modules in this order:

1. `config.options`
2. `plugins` (plugin registration)
3. `config.keymaps`
4. `config.autocmds`
5. `config.ui`
6. `custom.statusline`
7. `custom.tabline`
8. deferred `config.lsp`
9. trigger-loaded custom modules (Explorer, LazyGit, Cmdline, etc.)

## Tasks and Debugging

### Overseer.nvim (Task Runner)

A fully modular, production-grade **[stevearc/overseer.nvim](https://github.com/stevearc/overseer.nvim)** configuration using **native `vim.pack`**.

#### Features
- **Auto-discovery templates** for Go, Node.js (npm/pnpm), and Angular.
- **Diagnostics & Quickfix integration** for task output.
- **Persistent task list** (saves on exit).
- **Floating task output** with rounded borders.
- **DAP Integration:** Auto-run build tasks before debugging.

#### Keymaps
| Key | Action |
|-----|--------|
| `<leader>or` | Run task (Telescope or picker) |
| `<leader>ot` | Toggle task panel |
| `<leader>oo` | Open task output (float) |
| `<leader>ol` | Re-run last task |
| `<leader>ob` | Task builder (form UI) |
| `<leader>os` | Save task bundle |
| `<leader>oL` | Load task bundle |

### nvim-dap (Debugger)

Full-featured debugging via **[mfussenegger/nvim-dap](https://github.com/mfussenegger/nvim-dap)**.

#### Registered Plugins
- `rcarriga/nvim-dap-ui`: Full debug UI (scopes, stacks, watches, REPL).
- `theHamsta/nvim-dap-virtual-text`: Inline variable values while paused.
- `leoluz/nvim-dap-go`: Delve (Go) high-level wrapper.
- `mxsdev/nvim-dap-vscode-js`: vscode-js-debug wrapper (Node/TS/Angular).

#### Keymaps
| Key | Action |
|-----|--------|
| `<leader>dc` | Continue / start session |
| `<leader>dq` | Terminate session |
| `<leader>dr` | Restart session |
| `<leader>dn` | Step over |
| `<leader>di` | Step into |
| `<leader>do` | Step out |
| `<leader>dB` | Toggle breakpoint |
| `<leader>dh` | Hover variable under cursor |
| `<leader>du` | Toggle DAP UI |
| `<leader>de` | Evaluate expression |

---

## Custom Modules

### `custom.lightbulb`

A high-performance, lightweight LSP code-action indicator inspired by VSCode's lightbulb.

Features:
- **Async existence check:** Queries LSP servers without blocking the UI.
- **Smart throttling:** Uses `CursorHold` and line-change detection to minimize server load.
- **Extmark-based rendering:** Uses dedicated namespaces for clean, non-intrusive indicators in the sign column.
- **Automatic cleanup:** Clears indicators immediately on movement or mode change.

### `custom.explorer`
A custom file explorer with Git status, project pinning, and filesystem watching.
- `:Explorer`, `:ExplorerReveal`, `:ExplorerProjects`

### `custom.cmdline`
Floating command line and search UI with live preview and animated transitions.

### `custom.statusline` & `custom.tabline`
Hand-rolled, high-performance UI components with component-level dirty tracking.

### `custom.terminal_manager`
VS Code-style managed terminal panel with profiles, virtualenv detection, and sidebar list.

*(See full list in `lua/custom/` for more)*

---

## Language-Specific Workflow

### Go
- Startup check for Go CLI tools.
- Auto-organize imports on save.
- Floating terminal integration for Go commands.
- **DAP Configurations:** 9 built-in configs including package debug, test debug, and remote attach.

### Angular
- **DAP Configurations:** Chrome/Edge launch/attach, Karma test attach.
- Dev server preset using `ng serve`.
- Automatic parser switching for Angular HTML.

---

## Notable Global Keymaps

### Editor Essentials
- `<leader>ww` or `<C-s>` save current file
- `<leader>wa` save all (creating parent directories if needed)
- `<leader>P` paste without replacing clipboard
- `<C-h/j/k/l>` window navigation
- `<leader>nr` restart Neovim with the native `:restart` command

### UI & Tools
- `<leader>e` toggle file explorer
- `<leader>pp` open Pack Manager GUI
- `<leader>ca` open Code Action picker
- `<leader>zt` toggle managed terminal panel
- `<leader>gg` open LazyGit
- `<leader>ip` Markdown preview (Glow)

### LSP & Diagnostics
- `gd` / `gD` definition / declaration
- `gi` peek implementation
- `gm` peek diagnostics
- `<leader>cr` rename all instances
- `<leader>ck` open LSP keymapper
- `[d` / `]d` previous / next diagnostic

---

## Maintenance Notes
- **Lockfile:** Plugin revisions are pinned in `nvim-pack-lock.json`. Use `<leader>pu` to update.
- **Windows Focus:** This config is optimized for Windows (`pwsh`/`nu`) but compatible with Linux/macOS.
- **Experimental Features:** Leverages Neovim 0.12 `ui2` and progress reporting.
