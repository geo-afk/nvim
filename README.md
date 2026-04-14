# Neovim 0.12 Configuration

This repository is a personal Neovim setup built around **Neovim 0.12**, the
native **`vim.pack`** plugin manager, and a fairly large set of **custom UI
modules** that replace or extend the stock editor experience.

## At a Glance

- Requires **Neovim >= 0.12**
- Uses **`vim.pack`** instead of `lazy.nvim` or `packer.nvim`
- Uses **Mason** for installing many LSP servers and CLI tools
- Uses **native `vim.lsp.config()` / `vim.lsp.enable()`**
- Ships several custom UI modules:
  - file explorer
  - floating command line / search UI
  - custom code action picker
  - custom statusline with partial invalidation
  - custom tabline with session persistence
  - floating terminal wrapper used by LazyGit and Go tools
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
    │   ├── codelenjqjs.lua
    │   ├── cmdline/
    │   ├── code_action/
    │   ├── explorer/
    │   ├── float_term/
    │   ├── lazygit.lua
    │   ├── lsp_keymapper/
    │   ├── statusline/
    │   └── tabline/
    ├── plugins/
    └── utils/
```

## Startup Flow

`init.lua` loads modules in this order:

1. `plugins`
2. `config.options`
3. `config.keymaps`
4. `config.autocmds`
5. `config.lsp`
6. `config.ui`
7. custom modules:
   - `custom.explorer`
   - `custom.lazygit`
   - `custom.cmdline`
   - `custom.code_action`
   - `custom.lsp_keymapper`
   - `custom.statusline`
   - `custom.tabline`
   - `custom.autoclose`
   - `custom.image_view`

That means this config is not just “plugins plus some mappings”. A large amount
of the editor behavior is defined in local Lua modules under `lua/custom`.

## Image Preview

The Chafa-backed image preview lives in [`lua/custom/image_view.lua`](./lua/custom/image_view.lua).

- `<leader>ii`
  - preview the current image buffer, or an image path under the cursor
- `<leader>iI`
  - prompt for an image path and preview it
- `:ChafaImage [path]`
  - preview an explicit file path

## Core Editor Behavior

Configured in [`lua/config/options.lua`](./lua/config/options.lua):

- relative line numbers outside insert mode
- rounded borders for floating windows and popup menus
- global statusline
- visible listchars and custom fold characters
- `cmdheight = 0`
- `autowriteall = true`
- undo files enabled
- no swapfile / backup
- clipboard integration when not in SSH
- `exrc = true` for project-local config
- shell integration that prefers `nu`, then `pwsh`

Notable editor automation from [`lua/config/autocmds.lua`](./lua/config/autocmds.lua):

- trailing whitespace cleanup on save
- delayed auto-save on insert leave / text change / focus loss / buffer leave
- restore cursor to last position on reopen
- split equalization on resize
- spell check for text, markdown, and TeX
- yank highlighting
- smart `hlsearch` behavior
- terminal buffers marked busy
- demonstrations of new 0.12 events such as:
  - `MarkSet`
  - `SessionLoadPre`
  - `TabClosedPre`
  - `CmdlineLeavePre`
  - `LspProgress`

## Plugin Stack

Plugins are loaded from [`lua/plugins/init.lua`](./lua/plugins/init.lua).

### UI and appearance

- `folke/tokyonight.nvim`
- `echasnovski/mini.icons`
- `folke/which-key.nvim`
- `sphamba/smear-cursor.nvim`
- `geo-afk/nhc-forked` for inline color previews

### Syntax and text objects

- `nvim-treesitter/nvim-treesitter`
- `HiPhish/rainbow-delimiters.nvim`
- `windwp/nvim-ts-autotag`

### LSP, completion, snippets

- `neovim/nvim-lspconfig`
- `mason-org/mason.nvim`
- `mason-org/mason-lspconfig.nvim`
- `WhoIsSethDaniel/mason-tool-installer.nvim`
- `folke/lazydev.nvim`
- `saghen/blink.cmp`
- `xzbdmw/colorful-menu.nvim`
- `L3MON4D3/LuaSnip`
- `rafamadriz/friendly-snippets`

### Formatting, linting, diagnostics, search

- `stevearc/conform.nvim`
- `mfussenegger/nvim-lint`
- `folke/trouble.nvim`
- `nvim-telescope/telescope.nvim`
- `nvim-telescope/telescope-fzf-native.nvim`
- `nvim-telescope/telescope-ui-select.nvim`
- `folke/flash.nvim`

### Git and terminals

- `lewis6991/gitsigns.nvim`
- `akinsho/toggleterm.nvim`
- custom LazyGit wrapper via `lua/custom/lazygit.lua`

### Dev workflow

- `geo-afk/dev-server`

### Built-in Neovim optional packages enabled

These are activated with `packadd`:

- `nvim.undotree`
- `nvim.difftool`
- `nvim.tohtml`

## Custom Modules

The most important part of this config lives in `lua/custom`.

### `custom.explorer`

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

Default top-level keymaps from [`lua/custom/explorer/config.lua`](./lua/custom/explorer/config.lua):

- `<leader>e` toggle explorer
- inside the explorer buffer:
  - `<CR>` / `l` open
  - `h` close directory
  - `-` go to parent directory
  - `v` vertical split
  - `s` horizontal split
  - `t` open in tab
  - `a` add file
  - `d` delete
  - `r` rename
  - `c` copy
  - `.` toggle hidden
  - `R` refresh
  - `P` add or pin project depending on context
  - `y` copy path
  - `m` mark
  - `W` collapse all
  - `E` expand all
  - `gs` stage via Git
  - `gr` restore via Git
  - `/` search
  - `gp` open project switcher
  - `q` quit
  - `?` help

### `custom.cmdline`

Replaces the default command line and search UI with a floating interface.

Features:

- replaces `:`
- replaces `/` and `?`
- supports visual range command entry
- animated UI
- optional completion popup
- search live preview and range preview
- custom highlight groups that re-apply on `ColorScheme`

Commands:

- `:NvimCmdline`
- `:NvimCmdlineClose`

### `custom.code_action`

A custom floating code action picker with:

- normal and visual mode support
- range-aware code actions
- source-specific highlights and icons
- cursor-navigable popup UI

Keymaps / commands:

- `<leader>ca`
- `:CodeActionMenu`

### `custom.lsp_keymapper`

A custom LSP capability browser and keymap persistence layer.

Features:

- inspects the active LSP client
- lets you browse available capabilities
- persists custom bindings per LSP client
- reapplies saved bindings on future attaches

Commands:

- `:LspKeymapBrowse`
- `:LspKeymapReset`
- `:LspKeymapShow`

Default keymap:

- `<leader>ck`

### `custom.statusline`

A hand-rolled statusline with component-level dirty tracking.

Displayed components:

- mode
- file
- git
- LSP / diagnostics / progress
- system state
- cursor position

Important implementation detail:

- Neovim still redraws the full row, but this statusline caches component
  render output and only recomputes the pieces that changed.

### `custom.tabline`

A custom tabline / bufferline with:

- next / previous buffer navigation
- close current buffer
- move buffer left / right
- persistent per-directory sessions
- automatic session restore on startup when launched without file arguments

Commands:

- `:TablineNext`
- `:TablinePrev`
- `:TablineClose`
- `:TablineMoveLeft`
- `:TablineMoveRight`
- `:TablineSessionSave`
- `:TablineSessionRestore`
- `:TablineSessionDelete`
- `:TablineSessionList`

Default keymaps:

- `<Tab>` next buffer
- `<S-Tab>` previous buffer
- `<A-c>` close buffer
- `<leader>b<` move buffer left
- `<leader>b>` move buffer right

### `custom.float_term` and `custom.lazygit`

Floating terminal wrapper used by:

- LazyGit
- Go tooling commands
- other ad-hoc command runners

Keymap:

- `<leader>gg` open LazyGit in a floating terminal

### `custom.terminal`

A VS Code-style managed terminal panel with:

- a sidebar terminal list plus terminal pane
- colored terminal state indicators and a titled winbar
- `?` help inside the sidebar
- profile-based terminal creation with per-profile shell, args, env, cwd, icon, and color
- default and automation-profile support
- recovery when one side of the panel is closed externally

Keymaps and commands:

- `<leader>zt` toggle the managed terminal panel
- `<leader>zn` create a managed terminal
- `<leader>zp` create a managed terminal from a selected profile
- `<leader>zT` focus the terminal sidebar
- visual `<leader>zs` send selection to the active managed terminal
- `:TerminalNew [name]`
- `:TerminalProfiles`
- `:TerminalAutomation [name]`

### `custom.autoclose`

Local auto-pair / auto-close behavior implemented in Lua rather than via a
dedicated external plugin.

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

- `<leader>tt` toggle default terminal
- `<leader>t1` to `<leader>t5` open numbered terminals
- `<leader>ts` open Scooter
- visual `<leader>tr` search selected text in Scooter

### Dev server plugin

Configured in [`lua/plugins/dev-server.lua`](./lua/plugins/dev-server.lua).

Currently documented server preset:

- Angular: `ng serve`

Configured dev-server keymaps in the plugin file:

- `<leader>rt` toggle server window
- `<leader>rr` restart
- `<leader>rs` stop
- `<leader>rS` status
- `<leader>ri` `:DevServerStatus`

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
- helpers for:
  - `gotests`
  - `gomodifytags`
  - `iferr`
  - `fillstruct`
  - `fillswitch`
  - `go mod tidy`
  - `go generate`
  - project run
  - targeted test execution

Go commands:

- `:GoTests`
- `:GoModifyTags`
- `:GoIfErr`
- `:GoOrganizeImports`
- `:GoRun`
- `:GoTestRun`
- `:GoTestRunCurrent`
- `:GoAlternate`
- `:GoModTidy`
- `:GoGenerate`
- `:GoFillStruct`
- `:GoFillSwitch`
- `:GoDoc`
- `:GoDocBrowser`
- `:GoVulnCheck`
- `:GoDlvDebug`
- `:GoDlvTest`
- `:GoDlvBreakpoint`
- `:GoDlvCondBreakpoint`
- `:GoDlvClearBreakpoints`
- `:GoDlvAttach`
- `:GoDlvRepl`
- `:GoDlvStepOver`
- `:GoDlvStepInto`
- `:GoDlvStepOut`
- `:GoDlvTerminate`
- `:GoDlvUI`

### Markdown

Implemented in [`after/ftplugin/markdown.lua`](./after/ftplugin/markdown.lua).

Features:

- `textwidth = 80`
- spell checking enabled
- heading highlight customization
- list manipulation helpers for the current line or visual selection
- heading toggles for heading levels 1 through 6
- task completion / reopening helpers

Examples:

- `tn` toggle numbered list
- `tb` toggle bullets
- `tc` toggle checkbox
- `tt` toggle task state
- `tl` smart list conversion
- `<leader>tc` mark all tasks done
- `<leader>tu` mark all tasks undone
- `<leader>h1` through `<leader>h6` toggle heading levels

### Angular

Angular-specific behavior appears in multiple places:

- Angular project detection in utilities
- Angular HTML parser selection in Treesitter
- filetype autocmd that allows toggling between `.ts` and `.html` in Angular
- dev server preset using `ng serve`
- explicit `angularls` LSP config

## Notable Global Keymaps

From [`lua/config/keymaps.lua`](./lua/config/keymaps.lua) and plugin modules:

- `<leader>ww` save
- `<leader>wa` `:wall ++p`
- `<C-h> <C-j> <C-k> <C-l>` window navigation
- `<C-Up> <C-Down> <C-Left> <C-Right>` resize windows
- `<leader>pu` update all plugins with `vim.pack.update()`
- `<leader>pm` open Mason
- `<leader>uu` open built-in undo tree
- `<leader>nd` open built-in DiffTool
- `<leader>nr` restart Neovim
- `<leader>df` diagnostic float
- `[d` / `]d` previous / next diagnostic
- `<leader>dq` diagnostics to quickfix
- `<leader>ds` diagnostic summary
- `<leader>dw` workspace diagnostics
- `<leader>ch` toggle inlay hints
- `<leader>ck` open the LSP keymapper
- `<leader>gg` open LazyGit
- `<leader>ii` preview the current image
- `<leader>rt` toggle the dev server
- `<leader>?` show buffer-local which-key popup

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
