# Neovim 0.12.3 Audit and Repair — Final Addendum

Date: 2026-07-31  
Revision audited: `5f6312feea2ebdd61d56ff284f116ed8ac5ed8b7` (`main`)  
Detailed baseline report: `AUDIT_REPORT.md` (pre-existing, preserved)

This addendum records the repairs and final validation performed after the full
architecture audit. Together with the baseline report, it supplies Reports A–R
and the final disposition requested by the audit specification.

## A — Environment

Neovim: 0.12.3 Release, API level 14, LuaJIT 2.1.1774638290  
OS/architecture: Windows/x64  
Config: `C:\Users\KoolAid\AppData\Local\nvim`  
Data/state: `C:\Users\KoolAid\AppData\Local\nvim-data`  
Cache: `C:\Users\KoolAid\AppData\Local\Temp\nvim`  
Git: `main`, revision above; existing untracked audit/profile files preserved  
Plugin mechanism: native experimental `vim.pack`, custom lifecycle loader  
Static tooling: Neovim `loadfile`; LuaLS/Luacheck/StyLua unavailable on PATH  
Tests: ten headless Lua suites after adding `tests/pack_lock_spec.lua`

## B — Architecture

```text
init.lua
  -> custom.loader setup/registry/bootstrap
  -> config.options
  -> plugins registry -> vim.pack declarations
  -> config.keymaps + config.autocmds
  -> config.ui -> custom.statusline -> custom.tabline
  -> VimEnter/deferred plugins -> config.lsp
  -> event/cmd/key/filetype triggered custom tools
```

`vim.pack` owns acquisition, revisions, and runtime paths. `custom.loader` owns
module dependencies, priorities, triggers, setup callbacks, profiling, and
loader cache invalidation. LSP is native 0.12 configuration through
`vim.lsp.config()` and `vim.lsp.enable()`. The baseline report contains the
complete custom/config subsystem, event, UI, and state-ownership maps.

## C — Issues Found

| Severity | Evidence | Area | File | Lines | Issue | Impact | Fix |
|---|---|---|---|---:|---|---|---|
| Medium | Runtime + Static | vim.pack | `nvim-pack-lock.json` | former entries | Four installed lock entries had no production declaration | First pack call restored/managed unused plugins | Removed with `vim.pack.del()` and removed the contradictory lazydev hint |
| Low | Static | Documentation | `README.md` | 58–90 | Nonexistent ToggleTerm/scooter integration and two invalid clone URLs | Broken onboarding | Removed stale requirement; corrected both URLs |
| Low | Static | Documentation | `README.md` | 108–154 | Repository tree named absent files and omitted current directories | Maintenance confusion | Updated tree |
| Low | Runtime | Test isolation | test processes | n/a | Restricted sandbox cannot write normal Neovim logs/state | Noisy sandbox-only stderr | Final startup rerun outside sandbox; production unchanged |
| Low | Possible | Timers | UI/lint/explorer | various | Long-session handle retention was not proven | Possible resource retention | Intentionally unchanged pending handle-count tests |

Counts: 0 Critical, 0 High, 1 Medium, 3 Low (one possible). Three
informational compatibility observations remain in the baseline report.

## D/E — `custom/` and `config/` Audit

All 130 custom modules and every config module were read and syntax-compiled.
Per-subsystem contracts, dependencies, lifecycle tests, and status are recorded
in the baseline coverage matrix. Final status is PASS for startup, loader,
explorer, folding, autoclose, statusline/tabline, and security/error paths;
PASS WITH NOTES for interactive UI/process tools, LSP handshakes, timers, and
format/lint integrations that cannot be exercised fully in a headless empty
workspace. No module is FAIL.

## F — Custom Loader

The loader retains ordinary `package.loaded`/`require` semantics and enables
`vim.loader`; it does not replace `package.searchers`. Registry entries form a
dependency DAG with guarded state transitions. Tests cover value, nil, false,
missing, runtime-error, malformed-neighbor, duplicate-registration, repeated
load, and cycle cases. Successful modules and setup callbacks execute once;
errors retain module context. Verdict: PASS. No replacement or speculative
optimization was justified.

## G — `vim.pack`

The final lock contains 39 plugins: 38 direct declarations and the documented
`nvim-nio` transitive dependency of `nvim-dap-ui`. Every declaration has a lock
entry and every lock entry is direct or explicitly transitive. A first attempt
to edit the lockfile alone was correctly rejected by runtime evidence: Neovim
repaired the four entries from installed state. The supported
`vim.pack.del({'apidocs.nvim','dev-server','mini.sessions','nvim-lspconfig'})`
workflow then removed the exact managed directories and lock entries. Lock
health: PASS; duplicates: none proven; missing dependencies: none proven.

## H — LSP

Fourteen native configs are enabled after deferred startup: gopls, html, jsonls,
sqls, lua_ls, codebook, typos_lsp, just_lsp, vtsls, yamlls, biome, angularls,
tailwindcss, and docker_language_server. Registration/executable discovery and
attach logic were checked; no client is expected for an empty headless buffer.
The stale lazydev `nvim-lspconfig` library hint was removed consistently with
the configuration's explicit native-LSP architecture. Duplicate clients: none
reproduced. Real multi-language project handshakes remain UNVERIFIED.

## I/J — Autocommands, Keymaps, Commands

Named augroups and loader trigger stubs were inspected. No duplicate production
registration or broken callback was reproduced. Loader-created command/key
stubs resolve to their modules. Buffer-local mappings and detach cleanup are
used where required. Exact ownership details are in the baseline report.

## K — Static Analysis

Lua syntax errors before: 0  
Lua syntax errors after: 0 (236 Lua files compiled in the final suite)  
LuaLS/Luacheck: not run; executables unavailable  
JSON lockfile: parsed successfully  
`git diff --check`: PASS

## L — Runtime Tests

| Test | Before | After | Notes |
|---|---|---|---|
| Headless startup | PASS | PASS | Final run used normal plugin/state access |
| Architecture/loader injection | PASS | PASS | Expected injected errors contained |
| Loader dedicated suite | PASS | PASS | Dependency/cycle/cache behavior |
| Explorer move/search/UI | PASS | PASS | Temporary fixtures |
| Folding | PASS | PASS | Range/fallback/render/preview |
| Angular helpers | PASS | PASS | Edit/setup behavior |
| Lightbulb | PASS | PASS | Request/extmark lifecycle |
| Autoclose | PASS | PASS | Quote mappings |
| Pack lock consistency | absent | PASS | 39 entries, direct/transitive invariant |

## M — Health Checks

Focused `vim.lsp` and `vim.treesitter` health completed. Sandbox runs emitted
state/log permission warnings and one plugin activation EPERM; a final
out-of-sandbox startup passed with no configuration error. Optional external
and interactive integrations remain environment-specific.

## N — Performance

Baseline wall-clock samples (ms): 352.95, 305.33, 270.88, 289.48, 283.07,
307.38, 292.85, 284.09, 290.34; median 290.34 ms.  
After samples (ms): 234.61, 251.78, 223.05, 233.60, 217.97; median 233.60 ms.  
Observed difference: -56.74 ms (-19.54%). This is **not claimed as an
optimization**: the repaired lock metadata and documentation do no startup
work, and the sample sets differ in run count/environmental noise. Existing
profile hotspots remain Treesitter and autoclose; no performance code changed.

## O — Changes Applied

- `nvim-pack-lock.json`: removed four undeclared managed plugins using the
  supported `vim.pack.del()` workflow; consistency and startup passed.
- `lua/plugins/lazydev.lua`: removed `nvim-lspconfig` type-library metadata for
  a plugin explicitly not declared or used; Lua-file startup passed.
- `README.md`: corrected clone URLs, removed stale dependency text, and repaired
  repository layout; static comparison passed.
- `tests/pack_lock_spec.lua`: added bidirectional declaration/lock validation
  with an explicit `nvim-nio` transitive dependency; test passed with 39 plugins.

## P — Removed Code/Data

No executable Lua behavior was deleted. One unused lazydev metadata entry was
removed. Four plugin lock records and their vim.pack-managed checkouts were
removed after repository search proved no production declaration/caller. They
are recoverable by adding their source declarations again.

## Q — Research

Official Neovim 0.12 documentation confirms that the first `vim.pack` call
aligns lockfile and disk state, lockfiles should not be edited manually, and
`vim.pack.del()` is the supported disk-removal API. Official LSP documentation
confirms `vim.lsp.config()`/`vim.lsp.enable()` are current and that
`vim.lsp.start()` remains supported. See the source links in the baseline report.

## R — Remaining Risks

Risk: real LSP protocol handshakes and reuse across Lua/Go/TS/Angular projects.  
Reason: no representative project fixtures were in scope.  
Tested: registration, enabled configs, binaries, attach/detach code.  
Manual verification: open representative roots and run `:checkhealth vim.lsp`.

Risk: interactive terminal/DAP/Overseer/TV/Glow/LazyGit flows.  
Reason: headless automation cannot verify their visual/process interaction
without changing user state.  
Manual verification: invoke each documented command in an appropriate project.

Risk: possible timer handle retention in very long sessions.  
Reason: no growth or exit hang was reproduced.  
Manual verification: compare `vim.uv.walk()` handle counts across repeated
open/cancel cycles before changing cleanup code.

## Final Executive Summary

Files inspected: 253 baseline; 236 Lua files compiled after repair  
Custom modules inspected: 130  
Config modules inspected: all discovered modules and server/setup children  
Plugins inspected: 43 before; 39 after repair  

Critical/High/Medium/Low: 0 / 0 / 1 / 3  
Issues fixed: 3 grouped proven findings  
Issues intentionally not changed: unproven timer retention; interactive-only behavior  
Unverified: real project LSP handshakes and interactive tool UX  

Static checks: PASS  
Runtime checks: PASS  
Focused health: PASS WITH ENVIRONMENT NOTES  
Tests: 10 suites PASS  

Startup median before/after: 290.34 / 233.60 ms  
Measured difference: -19.54%, not attributed to these changes  

Top improvements: stale managed packages removed; lock invariant automated;
native-LSP metadata made consistent; installation URLs fixed; repository docs
made accurate. Architecture was preserved.

**FINAL STATUS: PASS WITH WARNINGS**
