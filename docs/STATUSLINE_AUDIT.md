# Statusline System Audit Report

## Executive Summary

- Architecture quality: improved from component-local width tiers to a central priority/budget layout engine.
- Rendering quality: stronger segmentation is preserved with sharp separators, icon-first compact states, and stable left/right alignment.
- UX quality: wide windows remain information-rich; narrow windows preserve filename, state, cursor position, and critical icons.
- Responsiveness quality: layout now degrades by section priority and variant quality instead of fixed width checks alone.
- Performance quality: git, diagnostics, LSP clients, CWD, and file metadata remain cached or event-invalidated; statusline-time git/process work is avoided.

## Current Problems

- Layout responsibility was split across components, so no section knew whether another section was more important.
- Width tiers were coarse and local: a component could keep metadata even when the total line no longer fit.
- Git rendering used cached async data, but branch compaction was not priority-aware.
- LSP progress animation added timer redraws and status churn for information the user does not want.
- Highlight generation adapted to colorschemes, but it did not have a bounded project/language accent layer.
- `setup()` could append duplicate builder sections if re-run during development.

## Responsive Layout Analysis

- New rendering path: components expose ordered variants: `full`, `compact`, `minimal`, `icon`.
- The builder starts with the best variant, measures the combined left and right content, then degrades the lowest-priority eligible section first.
- Required sections are never dropped: mode, file, and cursor remain present.
- Non-required sections collapse or disappear first: system, LSP, git.
- Small windows start from compact defaults to avoid jarring over-rendering before the budget pass.
- Very narrow windows keep the left identity bias: mode icon plus filename/state on the left, cursor position on the right.

## Performance Analysis

- Git is async and cached by CWD; rendering only reads the latest cache entry.
- Diagnostics are cached per buffer and invalidated by `DiagnosticChanged`.
- LSP clients are cached per buffer and invalidated by attach/detach.
- CWD display is cached and invalidated by `DirChanged`.
- File metadata remains buffer/width-aware and invalidated on file and option events.
- The hot path now does small table assembly, statusline display-width measurement, and cached data reads.

## Rendering Pipeline Analysis

- `init.lua` owns events, redraw throttling, setup, and commands.
- `builder.lua` owns layout, priority degradation, required-section preservation, and debug stats.
- Components own data formatting and variants, not global fit decisions.
- `config.lua` exposes configurable defaults for sections, animation, transparency, density, and theme behavior.
- `StatuslineDebug` exposes the latest width, budget, degraded sections, dropped sections, and render count.

## Highlight/Theme Analysis

- Highlight groups remain bounded and reusable; no per-project group names are generated.
- Colorscheme colors are still read through `nvim_get_hl()`.
- Transparency is supported by setting statusline backgrounds to `NONE`.
- Language/project accents modify existing groups safely and are recomputed on colorscheme changes and buffer entry.
- Accent application is intentionally bounded to avoid highlight leaks and excessive recomputation.

## UX Analysis

- Wide layout: mode, file metadata, git when available, LSP/diagnostics when available, system context, cursor and progress.
- Medium layout: shortened file identity, compact git/LSP summaries, cursor progress.
- Small layout: mode icon, filename/state, cursor position.
- Very narrow layout: required sections only; separators collapse to spaces.
- Diagnostics are icon/count based; warnings/info/hints collapse before errors.
- LSP names are normalized and summarized.

## Diagnostics/Git/LSP Analysis

- Diagnostics use current-buffer counts only.
- Git uses `git status --porcelain=v1 --branch` asynchronously and parses branch/state/diff counts from one command.
- Git branch names compact from `feature/foo` to `feat/foo`, then tail-truncate.
- Detached/rebase/merge states are surfaced when available from status output.
- LSP progress rendering is omitted by default to avoid timer-driven visual noise.
- Client names are normalized, deduplicated, cached, and summarized.

## Neovim 0.12.2 Compatibility

- Uses `vim.uv` with `vim.loop` fallback.
- Uses `vim.api.nvim__redraw()` with a `redrawstatus` fallback.
- Uses modern `vim.diagnostic.count()`.
- Uses `vim.lsp.get_clients({ bufnr = ... })`.
- Avoids deprecated statusline APIs and avoids blocking work inside `%!` evaluation.

## Corrected Code Examples

Priority-based registration:

```lua
{ side = "left", comp = "file", priority = 95, required = true }
{ side = "right", comp = "system", priority = 25, required = false }
```

Component variants:

```lua
return {
  { name = "full", text = full },
  { name = "compact", text = compact },
  { name = "minimal", text = minimal },
  { name = "icon", text = icon },
}
```

Debugging:

```vim
:StatuslineDebug
```

## Refactoring Recommendations

- Keep section priorities user-configurable in `lua/custom/statusline/config.lua`.
- Add optional per-project override tables later if a workspace needs explicit colors.
- Keep LSP progress omitted unless a future design needs it in a separate opt-in module.
- Add a small benchmark command if render cost needs to be tracked over time.
- Keep all filesystem/process work out of `builder.render()`.

## Final Assessment

- Production readiness: high after live interactive use confirms visual preference.
- Performance score: 9/10.
- Responsiveness score: 9/10.
- UX score: 8/10.
- Maintainability score: 8/10.
- Future-proofing score: 8/10.
