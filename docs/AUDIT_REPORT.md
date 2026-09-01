# Neovim 0.12.3 Configuration Audit

Audit date: 2026-07-31  
Repository revision: `5f6312feea2ebdd61d56ff284f116ed8ac5ed8b7` (`main`)

## Executive summary

The configuration starts successfully on its exact target, Neovim 0.12.3, and its custom loader, core UI spine, deferred plugin stack, Treesitter installation, and native LSP registration all function in runtime verification. The audit read all 253 discovered non-Git files, compiled all 235 Lua files twice, inspected 221 local Lua modules (130 under `lua/custom`), checked 43 locked plugins, and exercised the nine automated Lua suites twice (18 successful executions).

No Critical or High correctness defect was confirmed. Findings: 0 Critical, 0 High, 1 Medium, 3 Low, and 3 Informational. The principal maintainability issue is lockfile drift: four entries are not declared by production plugin modules, although Neovim still manages every lockfile entry on the first `vim.pack` call. Documentation also contains stale names and integrations. Real language-server handshakes were only partially verified because the audit opened no representative external project buffers; registration and executable availability were verified.

Measured wall-clock headless startup across nine samples: minimum 270.88 ms, median 290.34 ms, maximum 352.95 ms. The repository's existing loader profile identifies `plugins.treesitter` (187.80 ms), `custom.autoclose` (111.18 ms), `plugins.lazydev` (79.03 ms), and `plugins.colorscheme` (44.04 ms) as its largest recorded module costs. That profile is an existing untracked artifact and was not treated as a controlled fresh benchmark.

Counts: 253 files inspected; 221 local Lua modules; 43 plugins; 16 top-level custom subsystem directories; 9 test files executed; 18/18 executions passed; one audit test created; no production configuration changed.

### Top 10 changes by impact

1. Remove or deliberately redeclare four stale lock entries. Impact: reproducibility/disk/network; risk: low; difficulty: low; reason: the lockfile currently manages undeclared plugins.
2. Add project-fixture LSP handshake tests for Lua, Go, TypeScript, and Angular. Impact: high confidence in lifecycle behavior; risk: low; difficulty: medium.
3. Make tests redirect log/state paths to a writable temporary root. Impact: clean deterministic CI; risk: low; difficulty: low.
4. Add a single test runner that preserves per-suite exit status. Impact: test reliability; risk: low; difficulty: low.
5. Correct README clone URLs and repository tree. Impact: onboarding; risk: low; difficulty: low.
6. Remove the stale ToggleTerm/scooter claim. Impact: documentation accuracy; risk: none; difficulty: trivial.
7. Add automated lockfile-declaration consistency validation. Impact: prevents repeat drift; risk: low; difficulty: low.
8. Benchmark Treesitter and autoclose from fresh controlled profiles. Impact: startup decisions; risk: none; difficulty: medium.
9. Add close/cancel tests around persistent timers and filesystem watchers. Impact: resource confidence; risk: low; difficulty: medium.
10. Document that deferred LSP state must be inspected after `VimEnter`. Impact: diagnostic clarity; risk: none; difficulty: trivial.

## A. Environment

| Field | Value |
|---|---|
| OS | Windows, amd64 |
| Shell | PowerShell 7.6.3 |
| Neovim | NVIM v0.12.3 Release, API level 14 |
| Lua | LuaJIT 2.1.1774638290 |
| Config root | `C:\Users\KoolAid\AppData\Local\nvim` |
| Data root | `C:\Users\KoolAid\AppData\Local\nvim-data` |
| State root | `C:\Users\KoolAid\AppData\Local\nvim-data` |
| Cache root | `C:\Users\KoolAid\AppData\Local\Temp\nvim` |
| runtimepath | config, data/site, five active early plugins, Neovim runtime, site/after, config/after (full value captured at runtime) |
| packpath | config, data/site, Neovim runtime/lib, site/after, config/after |
| Git | 2.55.0.windows.3; branch `main`; revision above |
| Existing dirty files | untracked `profile_dump.txt`, `startup.log` (preserved) |

Important executables: rg 14.1.0, fd 10.3.0, fzf 0.67.0, Node 24.16.0, Go 1.26.4, Nu 0.113.1, Glow 2.1.2, GNU Make 4.4.1, plus `git`, `pwsh`, and `lazygit`. Mason exposes gopls, lua-language-server, ngserver, vtsls, biome, codebook-lsp, just-lsp, sqls, tailwindcss, Docker, JSON/HTML/YAML servers, and formatter binaries.

## B. Architecture

Startup is `init.lua` → `custom.loader.setup()` (enables experimental `vim.loader`) → registration of startup/custom specs → eager `plugins` registry load → loader bootstrap. Critical order is options → plugin registry and keymaps/autocmds → colors/UI → statusline → tabline. After `VimEnter` plus 100 ms, deferred modules load in dependency order, including completion/snippets/lazydev, LSP, formatting, linting, flash, rainbow, cmdline, and visual helpers. Trigger specs remain registered for commands, keys, filetypes, or LSP events; two idle modules remain queued until `CursorHold`.

The loader is a state machine split across registry/modules, dependency DAG, core require/config execution, event/command/key stubs, scheduler, cache invalidation, profiler, and UI. It uses ordinary `package.loaded` semantics plus `vim.loader` bytecode caching; no replacement `package.searcher` was found. Runtime state after `VimEnter`: critical/deferred modules loaded as designed, deferred queue zero, idle queue two.

Plugins are declared in 28 `vim.pack.add()` call sites. The lockfile contains 43 plugins; runtime `vim.pack.get()` returned 43, 19 active in the measured startup. Default `vim.pack.add()` loading is false while `init.lua` is sourced; plugin Lua modules call `require` directly after add where needed, and trigger-loaded plugin modules call add later when normal loading is enabled.

LSP uses native `vim.lsp.config()` and `vim.lsp.enable()`. Fourteen configurations were enabled after deferred startup. Capabilities are merged with blink.cmp and folding/color extensions. One shared `LspAttach` group owns navigation, diagnostics, code action, inlay hint, color, codelens, linked-editing, semantic-token, TypeScript, Go, and Angular hooks. Buffer-local document-highlight groups are deleted at detach. No active client exists in an empty headless buffer, as expected.

Custom tooling sectors: autoclose; floating cmdline/search/completion; code-action picker; explorer/projects/git/search/move/watchers; floating terminal; folding; Go Swagger helpers; loader/profiler; LSP key mapper/store; pack manager; context menu; statusline; tabline; managed terminal/profiles/environment/search; Television channel wrapper; shared UI components. DAP and Overseer add debugger/task orchestration; Conform/nvim-lint handle formatting/linting.

Event architecture is predominantly named augroups plus trigger stubs. Async paths use `vim.system`, `jobstart`, `vim.schedule`, timers, and one explorer filesystem watcher. External commands are passed as argv tables in the reviewed high-risk explorer/TV/terminal paths; no confirmed filename-to-shell injection was reproduced.

## C. Automated tests created and run

Exact form: `nvim --headless -u NONE -i NONE --cmd "set rtp^=C:/Users/KoolAid/AppData/Local/nvim" -l <test>`.

| Test | File | What it verifies | Result (twice) |
|---|---|---|---|
| Audit architecture | `tests/audit_architecture_spec.lua` | all Lua compiles; loader value/nil/false/error/missing/cycle/duplicate/malformed/repeat behavior | PASS |
| Loader | `tests/loader_spec.lua` | dependencies, cached setup, cycle failure | PASS |
| Explorer move | `tests/explorer_move_spec.lua` | temp-fixture move behavior and cleanup | PASS |
| Explorer search | `tests/explorer_search_spec.lua` | search calculations/state | PASS |
| Explorer UI | `tests/explorer_ui_spec.lua` | UI behavior | PASS |
| Folding | `tests/folding_spec.lua` | ranges, fallback, foldtext, status column, preview | PASS |
| Angular LSP | `tests/angular_lsp_spec.lua` | Angular edit handling/setup | PASS |
| Lightbulb | `tests/lightbulb_spec.lua` | request and indicator lifecycle | PASS |
| Autoclose | `tests/autoclose_quote_check.lua` | quote mappings | PASS |

The injected loader errors printed during the audit test are expected assertions of containment, not failed tests. All suites were run from fresh Neovim processes twice.

## D. Custom tool execution matrix

| Tool/subsystem | Normal | Failure | Repeat | Edge cases | Cleanup | Result |
|---|---:|---:|---:|---:|---:|---|
| Loader | yes | yes | yes | nil/false/missing/cycle/malformed | state isolated per process | PASS |
| Explorer move/search/UI | yes | yes | yes | temp paths, empty/filter states | temp fixture cleanup | PASS |
| Folding | yes | partial | yes | nested/indent/preview | buffer/window cleanup | PASS |
| Angular LSP helpers | yes | partial | yes | edit interception | handlers restored | PASS |
| Lightbulb | yes | yes | yes | absent actions/deleted state | extmark cleanup | PASS |
| Autoclose | yes | partial | yes | quote cases | mappings process-local | PASS |
| Pack manager / vim.pack | query only | timeout before VimEnter; falsified after VimEnter | yes | active/inactive count | N/A | PASS with warning |
| LSP registry | yes | missing-project/no-client | yes | pre/post-VimEnter timing | shutdown via qa | PASS registration; handshake BLOCKED |
| Terminal, LazyGit, Glow, TV, DAP, task runner | presence/config/API inspected | dependency detection inspected | not launched interactively | headless-inapplicable | static lifecycle review | BLOCKED/NA |
| Statusline/tabline/cmdline/shared UI | startup and module tests | partial | yes | headless UI limited | timer/window paths reviewed | WARNING |

Interactive tools were not launched because doing so could create terminals, detached processes, browser windows, sessions, or user-state writes; their safe detection and construction paths were inspected.

## E. LSP report

Configurations: gopls, html, jsonls, sqls, lua_ls, codebook, typos_lsp, just_lsp, vtsls, yamlls, biome, angularls, tailwindcss, docker_language_server. All 14 enable after `VimEnter`. Root detection is per server module/native configuration. `vim.lsp.enable` supplies automatic buffer matching and client reuse. Blink capabilities, folding range, and color provider are merged globally. Attach behavior is guarded by method support and buffer scope. Diagnostics use signs, underline, severity sorting, and jump floats. Formatting is delegated to Conform/LSP paths. Semantic tokens, inlay hints, codelens, linked editing, and document colors are conditional. Mason binaries for most configured servers exist. Shutdown/restart command shims use native `:lsp`; no real server lifecycle was started in an external project fixture.

## F. Plugin / loader report

The lockfile is valid JSON and runtime-readable. `vim.pack` knows all 43 entries; only 19 were active in the measured session. Trigger loading and deferred dependencies work after `VimEnter`. `vim.loader` is explicitly enabled and cache invalidation calls `vim.loader.find/reset`; it remains experimental, but no duplicate execution was reproduced. Loader tests proved one execution/config callback under repeated load and clean cycle/error handling. The `vim.pack.get()` probe that appeared to hang before the event loop entered completed after scheduling post-`VimEnter`; this was falsified as a plugin-manager deadlock.

## G. Performance

Startup wall time (nine headless processes): minimum 270.88 ms; median 290.34 ms; maximum 352.95 ms. Values: 352.95, 305.33, 270.88, 289.48, 283.07, 307.38, 292.85, 284.09, 290.34 ms. This includes process creation and is not interchangeable with `--startuptime`. Fresh temporary `--startuptime` files were empty in this Windows/headless environment, so the existing profile was retained only as supporting evidence. Existing loader hotspots: Treesitter 187.80 ms, autoclose 111.18 ms, lazydev 79.03 ms, colorscheme 44.04 ms. No runtime hot callback was confirmed by controlled timing.

## H/I. Findings and dead code

### NVIM-001

ID: NVIM-001  
Severity: Medium  
Confidence: Confirmed  
Sector: plugin management / reproducibility  
File: `nvim-pack-lock.json` entries for `apidocs.nvim`, `dev-server`, `mini.sessions`, `nvim-lspconfig`  
Issue: four lock entries have no production `vim.pack.add()` declaration. `nvim-lspconfig` appears only as a lazydev library hint while `plugins/lsp.lua` explicitly says it is not declared or used.  
Observed behavior/evidence: 43 lock entries and 43 runtime pack entries, while repository search found no declaration for these four. Official `vim.pack` documentation says the first pack call installs all lockfile entries.  
Why it matters: unused revisions remain managed/downloadable, inflate state, and obscure actual dependencies.  
Reproduction: compare lock properties with all plugin source declarations; run scheduled `vim.pack.get()`.  
Test: recommended lock/declaration consistency test.  
Version: Neovim 0.12.3.  
Correction: delete genuinely unused entries through the supported pack workflow, or explicitly declare/document why they are retained.  
Risk: removing `nvim-lspconfig` may reduce lazydev type metadata; validate Lua completion first.

### NVIM-002

ID: NVIM-002  
Severity: Low; Confidence: Confirmed; Sector: documentation  
File/lines: `README.md:61,83,90` and repository-layout section.  
Issue/evidence: README mentions a ToggleTerm/scooter integration not present in source, gives two inconsistent clone repository names (`nvijm`, `nvijkim`), and lists files/modules absent from the tree.  
Impact: installation and maintenance confusion.  
Test: static repository/documentation comparison.  
Correction: regenerate layout and use the canonical repository URL. Risk: none.

### NVIM-003

ID: NVIM-003  
Severity: Low; Confidence: Confirmed; Sector: test isolation/logging  
File: existing tests invoking LSP-adjacent modules.  
Issue/evidence: otherwise passing `-u NONE` suites emit permission errors for `nvim-data/lsp.log`, `nvim.log`, and LuaSnip logs in a restricted environment.  
Impact: noisy CI and potential masking of real stderr errors; production startup completed normally.  
Correction: runner should set writable temporary state/log locations and assert stderr allowlists. Risk: low.

### NVIM-004

ID: NVIM-004  
Severity: Low; Confidence: Potential; Sector: timers/resource cleanup  
Files: `lua/config/ui.lua`, `lua/plugins/linting.lua`, explorer debounce paths.  
Issue: several lifetime timers are stopped/reused but not explicitly closed until process teardown; `vim.defer_fn` handles are stopped and references discarded in some explorer paths. No growth or shutdown hang was reproduced.  
Impact: potential long-session handle retention, not a confirmed leak.  
Correction: add handle-count repeat/cancel tests before changing implementation. Risk: timer races if changed casually.

### NVIM-005

Informational, Confirmed: `vim.loader` is experimental but intentionally enabled once; cache reset integration exists and duplicate module execution was not reproduced.

### NVIM-006

Informational, Confirmed: inspecting LSP configs before deferred `VimEnter` completion yields zero; after an 800 ms scheduled probe, all 14 are enabled. This is expected architecture, not a defect.

### NVIM-007

Informational, Confirmed: Neovim and Treesitter health checks pass. LSP health is healthy with no client for the empty buffer. Treesitter reports valid ABI 13–15 parsers; duplicate built-in parser candidates are marked not loaded and are not failures.

Dead-code candidates (conservative): the four lock entries in NVIM-001 are unused production plugin declarations (high confidence for apidocs/dev-server/mini.sessions; medium for nvim-lspconfig due lazydev metadata). README-only references are stale documentation, not executable dead code. No Lua module was labeled unreachable solely from static absence because loader triggers and runtime directories load dynamically.

## J. Research ledger

| Topic | Question | Primary source | Conclusion | Findings |
|---|---|---|---|---|
| vim.pack | Does add load plugin files during init; what happens to lock entries? | Neovim `:help vim.pack` / online pack docs, 0.12 current | default `load=false` during init; first call aligns all lock entries | NVIM-001 |
| Native LSP | Are config/enable/get_configs/is_enabled current 0.12 APIs? | Neovim LSP docs and news-0.12 | yes; enable auto-activates and reuses by config/root | architecture, NVIM-006 |
| LSP config priority | Are explicit overrides supported? | official nvim-lspconfig README/source docs | runtime lsp → after/lsp → explicit config | LSP report |
| Treesitter main | Is the pinned main branch appropriate for 0.12? | official nvim-treesitter README | main is rewritten for Neovim 0.12+ | health/performance |
| Deprecations | Are used LSP APIs currently deprecated? | Neovim deprecated-0.12 docs | no confirmed use of listed semantic-token/log deprecated APIs | compatibility |

Sources: [Neovim pack documentation](https://neovim.io/doc/user/pack/), [Neovim LSP documentation](https://neovim.io/doc/user/lsp), [Neovim 0.12 news](https://neovim.io/doc/user/news-0.12/), [Neovim deprecations](https://neovim.io/doc/user/deprecated.html), [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig), [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter).

## K. Important commands executed

`git status --short`, branch/log/revision; `rg --files -uu`; full-file reads; `nvim --version`; runtime `vim.version/stdpath/runtimepath/packpath`; three startup smoke processes; nine-suite test loop twice; `:checkhealth vim.lsp`; `:checkhealth vim.treesitter`; scheduled loader/LSP state probe; scheduled `vim.pack.get()`; nine `Measure-Command` startup samples; executable/version inventories; source/API searches. Failed/limited commands: first PowerShell-profile read timed out (124); initial audit expectation failed (1) then corrected; pre-event-loop loader state probe timed out (124); temporary `--startuptime` files contained no samples.

## L. Files changed

Test infrastructure: `tests/audit_architecture_spec.lua` (created).  
Audit artifacts: `AUDIT_REPORT.md` (created).  
Production configuration: none.  
Existing untracked files preserved: `profile_dump.txt`, `startup.log`.

## M. Unverified / blocked

Real LSP handshakes, reuse, formatting, semantic-token exchange, and shutdown against representative Lua/Go/TS/Angular projects: blocked because no safe external project fixtures/server sessions were placed in scope; registration, binaries, and attach code were verified. Interactive DAP, Overseer, Television, LazyGit, Glow, terminal profiles, browser launches, and user-facing picker interaction: blocked/headless-inapplicable to avoid detached processes and persistent user state. Plugin API review was focused on APIs materially used or uncertain; every one of 43 upstream repositories was not network-cloned because exact pinned sources were already installed/locked and the audit avoided modifying plugin data. Full generic `:checkhealth` plugin fan-out was not captured; focused LSP and Treesitter checks were run.

## O. Systemic architectural findings

The custom loader and `vim.pack` have distinct but overlapping lifecycle ownership: `vim.pack` owns acquisition/runtime paths while the loader owns module setup and triggers. This works, but increases diagnostic complexity—state inspected before `VimEnter` can look empty, and the lockfile can retain dependencies no longer declared. Add machine-checked invariants rather than replacing the loader. The custom UI modules generally share useful primitives, but timer/window lifecycle testing is uneven. LSP correctly uses native 0.12 APIs and does not duplicate legacy lspconfig setup; keep this boundary. Documentation has drifted faster than the code and should be generated/validated where possible.

## Coverage matrix

| Sector | Representative files | Static | Runtime | Automated | Research | Status |
|---|---|---:|---:|---:|---:|---|
| Startup/options/keymaps/autocmds | init, config/* | ✓ | ✓ | ✓ | ✓ | PASS |
| Loader/cache/deps/scheduler | custom/loader/* | ✓ | ✓ | ✓ | ✓ | PASS |
| vim.pack/lock/plugins | plugins/*, lock | ✓ | ✓ | partial | ✓ | WARNING |
| LSP/diagnostics/completion | config/lsp*, plugins/lsp/completion | ✓ | partial | ✓ | ✓ | WARNING |
| Treesitter/queries/ftplugins | plugins/treesitter, after/* | ✓ | ✓ | ✓ | ✓ | PASS |
| Explorer/projects/git | custom/explorer/* | ✓ | ✓ | ✓ | partial | PASS |
| Terminal/process/external tools | terminal_manager, float_term, tv | ✓ | partial | partial | partial | BLOCKED |
| UI/cmdline/windows/extmarks | custom/ui, cmdline, code_action | ✓ | partial | partial | ✓ | WARNING |
| Statusline/tabline | custom/statusline, tabline | ✓ | ✓ | syntax/startup | N/A | PASS |
| Folding | custom/folding/* | ✓ | ✓ | ✓ | ✓ | PASS |
| Autoclose/snippets | custom/autoclose, snippets | ✓ | ✓ | ✓ | partial | PASS |
| Go/Angular helpers | custom/golang, utils/angular, dap/* | ✓ | partial | ✓ | partial | WARNING |
| Formatting/linting | plugins/formatting/linting | ✓ | setup only | syntax | upstream source | WARNING |
| DAP/tasks | plugins/dap/overseer, templates | ✓ | not launched | syntax | upstream source | BLOCKED |
| Sessions/pack manager/right menu | relevant custom/plugins | ✓ | startup/query | syntax | partial | WARNING |
| Filesystem/paths/platform | explorer, utils, terminal | ✓ | Windows ✓ | fixture ✓ | N/A | PASS |
| Async/timers/cleanup | UI/explorer/LSP timers | ✓ | partial | partial | core docs | WARNING |
| Security/error handling | process and loader paths | ✓ | failure injection | ✓ | core docs | PASS |
| Performance/resources | loader profile/startup | ✓ | ✓ | repeat ✓ | N/A | WARNING |
| Documentation/dead code | README, lock, all modules | ✓ | N/A | static | ✓ | WARNING |
| Health | core LSP/Treesitter | N/A | ✓ | N/A | ✓ | PASS |

## P. Completion checklist

- [x] Complete repository inspected
- [x] init/startup path traced
- [x] Every Lua module inspected/compiled
- [x] Every runtime directory inspected
- [x] Custom loader, vim.pack, lockfile, and plugin configurations inspected
- [x] Every custom tool inventoried; safely executable tools executed
- [x] Automated tests created and run twice
- [x] Failure paths and repeated initialization tested
- [x] Keymaps, autocmds, commands, options, and global state audited
- [x] LSP architecture, diagnostics, Treesitter, completion, UI/extmarks audited
- [x] Filesystem, paths, async/processes, timers, security, platform, and dependencies audited
- [x] Focused health checks run; startup profiled; dead code inspected
- [x] Current Neovim/plugin primary documentation checked
- [x] Candidate high/critical findings falsified or reproduced (none remained)
- [x] Every discovered sector included in coverage matrix
- [x] Blocked items and files changed documented
- [ ] Every interactive custom tool executed end-to-end — blocked by headless/non-destructive scope
- [ ] Real language-server clients tested against representative projects — blocked by absent scoped fixtures
- [ ] Full generic/plugin-specific health fan-out captured — focused core checks only

The unchecked items are explicitly covered in section M and do not conceal a confirmed production failure.
