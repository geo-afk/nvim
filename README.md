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

### Go-specific optional tools

These are checked by [`ftplugin/go.lua`](./ftplugin/go.lua) when a Go buffer is
opened:

- Required by the Go workflow:
  - `gotests`
  - `gomodifytags`
  - `iferr`
  - `gotestsum`
- Optional:
  - `fillstruct`
  - `fillswitch`
  - `dlv`
  - `govulncheck`

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
    ├── plugins/
    └── utils/
```

## Startup Flow

`init.lua` loads modules in this order:

1. `config.options`
2. `plugins` (plugin registration)
3. `config.keymaps`
4. `config.autocmds`
5. `custom.statusline`
6. `custom.tabline`
7. `custom.session`
8. `config.lsp`
9. `config.ui`
10. custom modules:
    - `custom.explorer`
    - `custom.lazygit`
    - `custom.cmdline`
    - `custom.code_action`
    - `custom.lsp_keymapper`
    - `custom.autoclose`
    - `custom.glow`
    - `custom.image_view`
    - `custom.pack_manager`
    - `custom.terminal_manager`

## Custom Modules

### `custom.explorer`

> [!TIP]
> **File Explorer Image Placeholder**
> _Insert screenshot showing the explorer with Git icons and project pinning._

A custom file explorer with:

- toggle command: `:Explorer`
- reveal command: `:ExplorerReveal`
- project switcher: `:ExplorerProjects`
- filesystem watching with debounced rerendering
- Git status indicators
- follow-current-file behavior
- hidden-file toggle
- project pinning / recent roots support
- safer target-window selection when opening files from the tree
- popup inputs for create / rename / copy support clipboard paste
- file copy operations implemented in Lua for Windows-friendly behavior

### `custom.cmdline`

> [!TIP]
> **Cmdline Image Placeholder**
> _Insert screenshot showing the floating cmdline with completion._

Replaces the default command line and search UI with a floating interface.

Features:

- replaces `:`
- replaces `/` and `?`
- supports visual range command entry
- animated UI
- optional completion popup
- search live preview and range preview
- custom highlight groups that re-apply on `ColorScheme`

### `custom.code_action`

> [!TIP]
> **Code Action Image Placeholder**
> _Insert screenshot showing the code action menu._

A custom floating code action picker with:

- normal and visual mode support
- range-aware code actions
- source-specific highlights and icons
- cursor-navigable popup UI

### `custom.lsp_keymapper`

A custom LSP capability browser and keymap persistence layer.

Features:

- inspects the active LSP client
- lets you browse available capabilities
- persists custom bindings per LSP client
- reapplies saved bindings on future attaches

### `custom.statusline`

> [!TIP]
> **Statusline Image Placeholder**
> _Insert close-up screenshot of the statusline._

A hand-rolled statusline with component-level dirty tracking.

Displayed components:

- mode
- file
- git
- LSP / diagnostics / progress
- system state
- cursor position

### `custom.tabline`

> [!TIP]
> **Tabline Image Placeholder**
> _Insert close-up screenshot of the tabline/bufferline._

A custom tabline / bufferline with:

- next / previous buffer navigation
- close current buffer
- move buffer left / right

### `custom.session`

A dedicated session manager for persistent workflows.

Features:

- per-directory session persistence
- automatic session restore on startup when launched without file arguments
- captures state of custom modules like the file explorer
- powers the Neovim restart functionality

Commands:

- `:SessionSave`
- `:SessionRestore`
- `:SessionDelete`
- `:SessionRestart`

### `custom.pack_manager`

> [!TIP]
> **Pack Manager Image Placeholder**
> _Insert screenshot of the GUI plugin manager._

A custom GUI for managing `vim.pack` plugins, inspired by `lazy.nvim`.

Features:

- browse installed and active plugins
- check for lockfile drift
- update individual or all plugins
- view plugin config snippets directly in the UI
- offline update review support

### `custom.terminal_manager`

> [!TIP]
> **Terminal Manager Image Placeholder**
> _Insert screenshot of the managed terminal panel and sidebar._

A VS Code-style managed terminal panel with:

- a sidebar terminal list plus terminal pane
- colored terminal state indicators and a titled winbar
- profile-based terminal creation with per-profile shell, args, env, cwd, icon, and color
- virtual environment detection (Python, Node, Go, Rust, etc.)
- search within terminal output

### `custom.glow`

> [!TIP]
> **Glow Preview Image Placeholder**
> _Insert screenshot showing a markdown preview float._

Integration for [Charmbracelet Glow](https://github.com/charmbracelet/glow).

- Preview current buffer in a floating window
- Preview visual selection
- Preview markdown URLs
- Toggle auto-preview on save

### `custom.autoclose`

Local auto-pair / auto-close behavior implemented in Lua.

## LSP Setup

Configured in [`lua/config/lsp.lua`](./lua/config/lsp.lua).

### Explicitly configured servers

- `gopls`
- `html`
- `sqls`
- `lua_ls`
- `typos_lsp`
- `vtsls`
- `angularls`
- `tailwindcss`

### Additional servers prepared via Mason tooling

The Mason setup also knows about:

- `emmet_language_server`
- `pyright`
- `rust_analyzer`
- `yamlls`
- `bashls`
- `marksman`
- `taplo`
- `clangd`
- `jsonls`
- `cssls`

The catch-all Mason handler enables installed servers that are not already
covered by explicit config.

### LSP UX extras

- rounded diagnostic floats
- custom diagnostic signs
- `blink.cmp` capabilities merged into LSP client capabilities
- inlay hints enabled globally on first attach
- document color decorations when supported
- code lens refresh on write / cursor hold
- linked editing range support
- workspace diagnostics keymaps
- custom peek windows for:
  - definitions
  - implementations
  - diagnostics

Useful commands:

- `:LspConfigs`
- `:LspIsEnabled [name]`
- `:DiagStatus`
- `:LspInfo`
- `:LspRestart`
- `:LspStop`
- `:LspLog`

## Completion and Snippets

Configured in [`lua/plugins/completion.lua`](./lua/plugins/completion.lua).

Highlights:

- `blink.cmp` replaces Neovim native autocomplete
- documentation popup auto-opens
- menu uses rounded borders
- special rendering for:
  - completion kind icons
  - colorful labels
  - inline color previews
- Lua completion gets `lazydev` source integration
- snippets are powered by LuaSnip

## Formatting

Configured in [`lua/plugins/formatting.lua`](./lua/plugins/formatting.lua).

### Format on save

Enabled for most filetypes, disabled for `c` and `cpp`.

### Manual formatting

- `<leader>fi` open `:ConformInfo`

### Configured formatters

- Lua: `stylua`
- JavaScript / TypeScript / JSX / TSX: `prettierd`
- Go: `gofumpt`, `goimports`, `golines`
- SQL: `sleek`
- CSS / HTML / JSON / YAML / Markdown: `prettierd`
- Python: `ruff format`
- Shell: `shfmt`

## Linting

Configured in [`lua/plugins/linting.lua`](./lua/plugins/linting.lua).

### Configured linters

- SQL: `sqruff`
- HTML: `htmlhint`
- TypeScript / JavaScript: `biome`
- Lua: `typos`
- Python: `ruff`
- Go: `staticcheck`

Linting is triggered on:

- `BufEnter`
- `BufWritePost`
- `InsertLeave`

with a small debounce.

## Treesitter

Configured in [`lua/plugins/treesitter.lua`](./lua/plugins/treesitter.lua).

### Installed parsers

- `lua`
- `typescript`
- `tsx`
- `javascript`
- `go`
- `json`
- `jsonc`
- `html`
- `css`
- `scss`
- `markdown`
- `markdown_inline`
- `regex`
- `vim`
- `vimdoc`
- `query`
- `toml`
- `sql`
- `angular`

### Extra behavior

- parser auto-install enabled
- Treesitter incremental selection enabled
- Angular HTML buffers can switch to the Angular parser when the file appears
  inside an Angular project

## Search, Navigation, Diagnostics, and Git

### Telescope

Configured keymaps include:

- `<leader>sf` find files
- `<leader>sg` live grep
- `<leader>sw` grep current word
- `<leader>sd` diagnostics
- `<leader>sk` keymaps
- `<leader>sh` help tags
- `<leader>sn` search Neovim config files
- `<leader>si` search hidden files
- `<leader><leader>` fuzzy search current buffer

### Trouble

- `<leader>xx` diagnostics
- `<leader>xX` buffer diagnostics
- `<leader>xs` document symbols
- `<leader>xl` LSP references / definitions
- `<leader>xL` location list
- `<leader>xQ` quickfix list

### Flash

- `s` jump
- `S` Treesitter jump
- `r` remote flash in operator-pending mode
- `R` Treesitter search
- `<C-s>` toggle flash search in command-line mode

### Gitsigns

Configured features include:

- hunk navigation
- stage / reset hunk
- stage / reset buffer
- preview hunk
- blame line
- toggle line blame
- diff against worktree or staged state
- hunk text object

## Terminal and Dev Server Workflow

### ToggleTerm

Configured in [`lua/plugins/toggleterm.lua`](./lua/plugins/toggleterm.lua).

Features:

- default terminal plus numbered terminals `1` through `5`
- dynamic working directory based on previous buffer
- terminal-mode navigation mappings
- Scooter integration

Keymaps:

- `<C-/>` toggle terminal
- `<leader>tf` floating terminal
- `<leader>th` horizontal terminal
- `<leader>tv` vertical terminal

### Dev server plugin

Configured in [`lua/plugins/dev-server.lua`](./lua/plugins/dev-server.lua).

Currently documented server preset:

- Angular: `ng serve`

Configured dev-server keymaps:

- `<leader>rt` toggle server window
- `<leader>rr` restart server
- `<leader>rs` stop server
- `<leader>rS` show server status
- `<leader>ri` open `:DevServerStatus`

## Language-Specific Workflow

### Go

Go support is one of the most customized parts of the repo.

Implemented in [`ftplugin/go.lua`](./ftplugin/go.lua):

- Go-specific indentation and text width
- startup check for external Go CLI tools
- floating terminal integration for Go commands
- auto organize imports on save through `gopls`
- test-file / implementation-file switching
- `go doc` floating window
- `govulncheck`
- Delve integration with DAP fallback when available
- helpers for `gotests`, `gomodifytags`, `iferr`, `fillstruct`, `fillswitch`, `go mod tidy`, `go generate`
- project run and targeted test execution

Go commands:

- `:GoTests`, `:GoModifyTags`, `:GoIfErr`, `:GoOrganizeImports`
- `:GoRun`, `:GoTestRun`, `:GoTestRunCurrent`, `:GoAlternate`
- `:GoModTidy`, `:GoGenerate`, `:GoFillStruct`, `:GoFillSwitch`
- `:GoDoc`, `:GoDocBrowser`, `:GoVulnCheck`
- `:GoDlvDebug`, `:GoDlvTest`, `:GoDlvBreakpoint`, etc.

### Markdown

Implemented in [`after/ftplugin/markdown.lua`](./after/ftplugin/markdown.lua).

Features:

- `textwidth = 80`
- spell checking enabled
- heading highlight customization
- list manipulation helpers and heading toggles
- integrated preview via `custom.glow`

Keymaps:

- `<leader>ip` preview current file (Glow)
- `<leader>iv` preview selection (Glow)
- `<leader>it` open Glow TUI
- `tn` toggle numbered list
- `tb` toggle bullets
- `tc` toggle checkbox
- `tt` toggle task state
- `tl` smart list conversion
- `<leader>tc` mark all tasks done

### Angular

Angular-specific behavior appears in multiple places:

- Angular project detection in utilities
- Angular HTML parser selection in Treesitter
- filetype autocmd that allows toggling between `.ts` and `.html` in Angular
- dev server preset using `ng serve`
- explicit `angularls` LSP config

## Notable Global Keymaps

### Editor Essentials

- `<leader>ww` or `<C-s>` save current file
- `<leader>wa` save all (creating parent directories if needed via `++p`)
- `<leader>P` paste without replacing clipboard (visual mode)
- `<A-j>` / `<A-k>` move current line or selection down / up
- `<C-h/j/k/l>` window navigation
- `<C-Up/Down/Left/Right>` resize windows
- `<leader>uu` open built-in undo tree
- `<leader>nd` open built-in DiffTool
- `<leader>nr` restart Neovim (powered by `custom.session`)

### UI & Custom Modules

- `<leader>e` toggle file explorer
- `<leader>pp` open Pack Manager GUI
- `<leader>ca` open Code Action picker
- `<leader>zt` toggle managed terminal panel
- `<leader>gg` open LazyGit
- `<leader>ii` preview current image
- `<leader>ni` open Neovim 0.12 info float

### LSP & Diagnostics

- `gd` / `gD` definition / declaration
- `gi` peek implementation
- `gm` peek diagnostics
- `<S-j>` peek definition
- `<leader>cr` rename all instances
- `<leader>ch` toggle inlay hints
- `<leader>ck` open LSP keymapper
- `<leader>df` diagnostic float
- `[d` / `]d` previous / next diagnostic
- `<leader>dq` diagnostics to quickfix
- `<leader>ds` diagnostic summary
- `<leader>dw` workspace diagnostics

## Useful Demo Commands for Neovim 0.12 APIs

From [`lua/config/ui.lua`](./lua/config/ui.lua):

- `:NvimInfo`
- `:FloatToTab`
- `:DiffExample`
- `:UniqueExample`
- `:BisectExample`
- `:FsExtExample`
- `:VersionExample`
- `:IterExample`
- `:JsonExample`
- `:HlRangeDemo`
- `:ProgressDemo`

These are not core productivity features; they are examples / experiments that
show off newer Neovim 0.12 APIs and UI features.

## Lockfile

Plugin revisions are pinned in [`nvim-pack-lock.json`](./nvim-pack-lock.json).

Use:

- `<leader>pu` to update plugins

After updating, review the lockfile changes before committing.

## Maintenance Notes

- This config assumes a Windows-friendly shell environment and may need
  adjustments on Linux or macOS if you want identical shell behavior.
- Mason handles many tools, but not all external commands used by the config.
- The Go and SQL workflows depend on extra CLIs that are not purely “plugin
  install and forget”.
- Some experimental Neovim 0.12 features are intentionally kept in the config,
  especially around `ui2`, progress reporting, and command-line behavior.

## Summary

This is best understood as a **custom Neovim distribution for one user's daily
workflow**, not a minimal starter config. The biggest pieces to understand are:

- `lua/config/*` for editor-wide behavior
- `lua/plugins/*` for plugin setup
- `lua/custom/*` for the bespoke UI systems
- `ftplugin/go.lua` and `after/ftplugin/markdown.lua` for language-specific UX

If you are changing this repo, the README should be updated whenever you:

- add or remove a custom module
- add or remove an external CLI dependency
- change top-level keymaps or commands
- change the supported LSP / formatter / linter toolchain
