-- =============================================================================
--  go.lua — Neovim Go development utilities (updated)
--  Tools: gotests · gomodifytags · iferr · gotestsum · fillstruct · fillswitch
--         dlv (Delve debugger) · govulncheck · go doc
--  NEW: go mod tidy, go generate, test/impl alternate, godoc browser, auto-organizeImports
--
--  Requires Neovim 0.9+ (uses vim.system for async shell calls)
-- =============================================================================

local file_picker = require("utils.file_selector")

-- to get coverage in golang html format:
-- go test -coverageprofile c.out ./...; go tool cover -html=c.out

vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.softtabstop = 0
vim.opt.expandtab = false
vim.opt.textwidth = 120

-- =============================================================================
--  Augroup (all autocmds belong here — prevents duplicates on re-source)
-- =============================================================================
local aug = vim.api.nvim_create_augroup("GoLua", { clear = true })

-- =============================================================================
--  Tool Registry
--  required = true  → ERROR on startup if missing
--  required = false → grouped WARN on startup if missing
-- =============================================================================
local TOOLS = {
  { cmd = "gotests", required = true, install = "go install github.com/cweill/gotests/gotests@latest" },
  { cmd = "gomodifytags", required = true, install = "go install github.com/fatih/gomodifytags@latest" },
  { cmd = "iferr", required = true, install = "go install github.com/koron/iferr@latest" },
  { cmd = "gotestsum", required = true, install = "go install gotest.tools/gotestsum@latest" },
  -- NOTE: fillstruct/fillswitch are broken on Go ≥1.25 (tokeninternal issue).
  --       The gopls LSP code-action fallback is used automatically when the CLI
  --       tool is absent or returns an error.
  {
    cmd = "fillstruct",
    required = false,
    install = "go install github.com/davidrjenni/reftools/cmd/fillstruct@latest",
  },
  {
    cmd = "fillswitch",
    required = false,
    install = "go install github.com/davidrjenni/reftools/cmd/fillswitch@latest",
  },
  { cmd = "dlv", required = false, install = "go install github.com/go-delve/delve/cmd/dlv@latest" },
  { cmd = "govulncheck", required = false, install = "go install golang.org/x/vuln/cmd/govulncheck@latest" },
}

-- =============================================================================
--  Startup Tool Check  (fires once per session, deferred 500 ms)
-- =============================================================================
local _tools_checked = false

local function check_tools()
  if _tools_checked then
    return
  end
  _tools_checked = true

  local missing_required = {}
  local missing_optional = {}

  for _, tool in ipairs(TOOLS) do
    if vim.fn.executable(tool.cmd) == 0 then
      if tool.required then
        table.insert(missing_required, tool)
      else
        table.insert(missing_optional, tool)
      end
    end
  end

  -- Wrap in vim.schedule so notifications happen on the main loop
  vim.schedule(function()
    for _, tool in ipairs(missing_required) do
      vim.notify(
        string.format("[go.lua] ✗ Required tool missing: %s\n  Install: %s", tool.cmd, tool.install),
        vim.log.levels.ERROR
      )
    end

    if #missing_optional > 0 then
      local lines = { "[go.lua] Optional tools not installed:" }
      for _, tool in ipairs(missing_optional) do
        table.insert(lines, string.format("  • %s  →  %s", tool.cmd, tool.install))
      end
      vim.notify(table.concat(lines, "\n"), vim.log.levels.WARN)
    end
  end)
end

-- 'once = true' ensures this fires exactly once even if 'go' filetypes are
-- opened multiple times; combined with the augroup it will not accumulate.
vim.api.nvim_create_autocmd("FileType", {
  group = aug,
  pattern = "go",
  once = true,
  callback = function()
    vim.defer_fn(check_tools, 500)
  end,
})

-- =============================================================================
--  Floating Terminal (lazy-loaded, configured only once per session)
-- =============================================================================
local float_term_mod = nil
local _float_term_setup = false

local function get_float_term()
  if float_term_mod then
    return float_term_mod
  end
  local ok, mod = pcall(require, "custom.float_term.term")
  if not ok then
    vim.notify("[go.lua] Failed to load float_term module: " .. tostring(mod), vim.log.levels.ERROR)
    return nil
  end
  float_term_mod = mod
  return mod
end

-- Shared Go terminal styling
local go_term_config = {
  width_ratio = 0.8,
  height_ratio = 0.7,
  transparent = true,
  winblend = 15,
  colors = {
    title_bg = "#00ADD8", -- Go cyan
    title_fg = "#000000",
    border = "#00ADD8",
  },
}

--- Create a floating terminal (fallback → bottom split).
---@param cmd   string  Shell command to run
---@param title string  Window title
---@param cwd?  string  Optional working directory
local function create_go_terminal(cmd, title, cwd)
  local ft = get_float_term()

  if not ft then
    -- Fallback: simple bottom split terminal
    local run_cmd = cmd
    if cwd then
      run_cmd = string.format("cd %s && %s", vim.fn.shellescape(cwd), run_cmd)
    end
    vim.cmd("botright 15split")
    vim.cmd("terminal " .. run_cmd)
    vim.cmd("startinsert")
    return
  end

  -- Configure the module only once per session to avoid repeated side-effects
  if not _float_term_setup then
    ft.setup(go_term_config)
    _float_term_setup = true
  end

  if cwd then
    local is_win = vim.uv.os_uname().sysname:match("Windows") ~= nil
    if is_win then
      cmd = string.format('Push-Location -LiteralPath "%s"; %s; Pop-Location', cwd, cmd)
    else
      cmd = string.format("cd %s && %s", vim.fn.shellescape(cwd), cmd)
    end
  end

  ft.create_terminal(cmd, { title = title })
end

-- =============================================================================
--  Generic Helpers
-- =============================================================================

--- Write the buffer if modified, then run a shell command asynchronously.
--- Reloads the buffer on success (Neovim 0.9+ vim.system API).
---@param cmd string Full shell command string
local function save_run_reload(cmd)
  -- Ensure the tool operates on up-to-date file content
  if vim.bo.modified then
    vim.cmd("silent! write")
  end

  -- Split into argv table so vim.system doesn't go through a shell
  -- (avoids quoting issues; each token is one argument)
  vim.system(vim.split(cmd, "%s+", { trimempty = true }), { text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        local stderr = vim.trim(result.stderr or "")
        local stdout = vim.trim(result.stdout or "")
        local msg = stderr ~= "" and stderr or stdout
        vim.notify("[go.lua] Command failed:\n" .. msg, vim.log.levels.ERROR)
        return
      end
      local bufnr = vim.api.nvim_get_current_buf()
      if vim.api.nvim_buf_is_valid(bufnr) then
        vim.cmd("edit!")
      end
    end)
  end)
end

--- Return the main/test file pair for any given Go file path.
---@param filepath string Absolute path to a .go file
---@return string|nil main_file
---@return string|nil test_file
local function get_test_file_pair(filepath)
  if filepath:match("_test%.go$") then
    local main_file = filepath:gsub("_test%.go$", ".go")
    return (vim.fn.filereadable(main_file) == 1) and main_file or nil, filepath
  else
    local test_file = filepath:gsub("%.go$", "_test.go")
    return filepath, (vim.fn.filereadable(test_file) == 1) and test_file or nil
  end
end

--- Shell-escape a file path for use as a standalone CLI argument.
---@param filepath string
---@return string
local function escape_filepath(filepath)
  if vim.uv.os_uname().sysname:match("Windows") ~= nil then
    return '"' .. filepath:gsub("\\", "/") .. '"'
  end
  return vim.fn.shellescape(filepath)
end

--- Return filepath relative to cwd.  Returns "." when they are equal.
---@param filepath string Absolute path
---@return string
local function get_relative_path(filepath)
  local cwd = vim.fn.getcwd():gsub("[/\\]$", "")
  filepath = filepath:gsub("[/\\]$", "")

  if filepath == cwd then
    return "."
  end

  local sep = vim.uv.os_uname().sysname:match("Windows") ~= nil and "\\" or "/"
  local prefix = cwd .. sep
  if filepath:sub(1, #prefix) == prefix then
    return filepath:sub(#prefix + 1)
  end
  return filepath
end

--- Find the directory that contains the project's main.go.
---@return string|nil
local function find_main_go()
  local cwd = vim.fn.getcwd()
  local candidates = {
    cwd .. "/main.go",
    cwd .. "/cmd/main.go",
    cwd .. "/cmd/*/main.go",
  }
  for _, pattern in ipairs(candidates) do
    if pattern:match("%*") then
      local matches = vim.fn.glob(pattern, false, true)
      if #matches > 0 then
        return vim.fn.fnamemodify(matches[1], ":h")
      end
    elseif vim.fn.filereadable(pattern) == 1 then
      return vim.fn.fnamemodify(pattern, ":h")
    end
  end
  return nil
end

--- Guard: notify and return false if the current buffer is not a Go file.
---@return boolean
local function assert_go_file()
  if not vim.fn.expand("%:p"):match("%.go$") then
    vim.notify("[go.lua] Not a Go file", vim.log.levels.WARN)
    return false
  end
  return true
end

--- Compute the byte offset of the cursor position for use as -offset=<N>.
--- Returns nil if the file has not been written (line2byte returns -1).
---@return integer|nil
local function cursor_byte_offset()
  local line, col = unpack(vim.api.nvim_win_get_cursor(0))
  local line_start = vim.fn.line2byte(line) -- 1-based byte of line start; -1 if not indexed
  if line_start < 0 then
    return nil
  end
  return line_start + col -- col is 0-based, so final offset is 1-based — correct for reftools
end

-- =============================================================================
--  Floating Read-only Output Window  (goDoc, etc.)
-- =============================================================================

---@param lines   string[]
---@param title   string
---@param ft_name? string Filetype for syntax (default: 'text')
---@return integer|nil buf
---@return integer|nil win
local function open_output_window(lines, title, ft_name)
  if not lines or #lines == 0 then
    vim.notify("[go.lua] " .. title .. ": no output to display", vim.log.levels.WARN)
    return nil, nil
  end

  ft_name = ft_name or "text"

  local ui = vim.api.nvim_list_uis()[1]
  local width = math.floor(ui.width * 0.75)
  local height = math.floor(ui.height * 0.70)
  local row = math.floor((ui.height - height) / 2)
  local col = math.floor((ui.width - width) / 2)

  local buf = vim.api.nvim_create_buf(false, true)
  -- Set buf options using the modern vim.bo accessor (nvim_buf_set_option deprecated)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = ft_name

  -- Populate then lock
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].readonly = true

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " " .. title .. " ",
    title_pos = "center",
  })

  -- Use modern vim.wo accessor (nvim_win_set_option deprecated)
  vim.wo[win].wrap = true
  vim.wo[win].number = false
  vim.wo[win].winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder,FloatTitle:FloatTitle"

  local function close()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  for _, key in ipairs({ "q", "<Esc>", "<CR>" }) do
    vim.keymap.set("n", key, close, { buffer = buf, nowait = true, silent = true })
  end

  return buf, win
end

-- =============================================================================
--  fillstruct — fill a struct literal with zero-value fields
--
--  CLI: fillstruct -file=<f> -offset=<bytes>|-line=<n>
--  Output: JSON [{ "start": N, "end": N, "code": "..." }]
--          Elements are in REVERSE order so iterating forward is safe.
--
--  Compatibility: fillstruct CLI is broken on Go ≥1.25.  When it fails we
--  automatically fall back to the gopls "Fill <struct>" code action.
-- =============================================================================

local function fillstruct_via_lsp()
  if #vim.lsp.get_clients({ bufnr = 0, name = "gopls" }) == 0 then
    vim.notify("[go.lua] fillstruct: gopls not attached — cannot use LSP fallback", vim.log.levels.ERROR)
    return
  end
  vim.lsp.buf.code_action({
    context = { only = { "source.fillStruct" } },
    apply = false,
  })
end

--- Parse and apply the JSON edit list produced by fillstruct or fillswitch.
---@param output    string  Raw stdout from the CLI tool
---@param tool_name string  Used in error messages
---@return boolean          true if edits were applied
local function apply_reftools_edits(output, tool_name)
  output = vim.trim(output)
  if output == "" or output == "[]" or output == "null" then
    return false
  end

  local ok, edits = pcall(vim.fn.json_decode, output)
  if not ok or type(edits) ~= "table" or #edits == 0 then
    vim.notify(string.format("[go.lua] %s: unexpected output:\n%s", tool_name, output), vim.log.levels.ERROR)
    return false
  end

  local bufnr = vim.api.nvim_get_current_buf()

  -- Edits arrive in reverse occurrence order, so applying them sequentially
  -- keeps earlier line numbers stable throughout the loop.
  for _, edit in ipairs(edits) do
    local start_0 = edit.start - 1 -- convert 1-based → 0-based inclusive start
    local end_excl = edit["end"] -- already 0-based exclusive end for nvim API
    local code_lines = vim.split(edit.code, "\n", { plain = true })
    vim.api.nvim_buf_set_lines(bufnr, start_0, end_excl, false, code_lines)
  end

  vim.notify(string.format("[go.lua] %s: applied %d replacement(s)", tool_name, #edits), vim.log.levels.INFO)
  return true
end

local function run_fillstruct()
  if not assert_go_file() then
    return
  end
  if vim.bo.modified then
    vim.cmd("silent! write")
  end

  local file = vim.fn.expand("%:p")
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local offset = cursor_byte_offset()

  -- -offset is more precise than -line; use it when available
  local pos_flag = offset and string.format("-offset=%d", offset) or string.format("-line=%d", line)

  local cmd = string.format("fillstruct -file=%s %s", escape_filepath(file), pos_flag)
  local output = vim.fn.system(cmd)
  local exit = vim.v.shell_error

  -- CLI failure most likely means Go ≥1.25 breakage → try gopls
  if exit ~= 0 then
    vim.notify(
      "[go.lua] fillstruct CLI failed (may be Go ≥1.25 incompatibility) — trying gopls…",
      vim.log.levels.WARN
    )
    fillstruct_via_lsp()
    return
  end

  -- Empty output means cursor wasn't on a struct literal → try gopls
  if not apply_reftools_edits(output, "fillstruct") then
    vim.notify("[go.lua] fillstruct: no struct literal found — trying gopls code action", vim.log.levels.INFO)
    fillstruct_via_lsp()
  end
end

-- =============================================================================
--  fillswitch — fill a (type) switch with case statements
--  Same JSON contract and fallback strategy as fillstruct.
-- =============================================================================

local function fillswitch_via_lsp()
  if #vim.lsp.get_clients({ bufnr = 0, name = "gopls" }) == 0 then
    vim.notify("[go.lua] fillswitch: gopls not attached — cannot use LSP fallback", vim.log.levels.ERROR)
    return
  end
  vim.lsp.buf.code_action({
    context = { only = { "source.fixAll" } },
    apply = false,
  })
end

local function run_fillswitch()
  if not assert_go_file() then
    return
  end
  if vim.bo.modified then
    vim.cmd("silent! write")
  end

  local file = vim.fn.expand("%:p")
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local offset = cursor_byte_offset()

  local pos_flag = offset and string.format("-offset=%d", offset) or string.format("-line=%d", line)

  local cmd = string.format("fillswitch -file=%s %s", escape_filepath(file), pos_flag)
  local output = vim.fn.system(cmd)
  local exit = vim.v.shell_error

  if exit ~= 0 then
    vim.notify("[go.lua] fillswitch CLI failed — trying gopls…", vim.log.levels.WARN)
    fillswitch_via_lsp()
    return
  end

  if not apply_reftools_edits(output, "fillswitch") then
    vim.notify("[go.lua] fillswitch: no (type) switch found — trying gopls code action", vim.log.levels.INFO)
    fillswitch_via_lsp()
  end
end

-- =============================================================================
--  goDoc — floating `go doc` window
--  Accepts full symbol paths: fmt.Println, encoding/json.Marshal, etc.
-- =============================================================================

---@param symbol? string Package/symbol; defaults to word under cursor
local function run_godoc(symbol)
  symbol = vim.trim(symbol or "")
  if symbol == "" then
    symbol = vim.fn.expand("<cword>")
  end
  if symbol == "" then
    vim.notify("[go.lua] goDoc: place cursor on a symbol or supply one as argument", vim.log.levels.WARN)
    return
  end

  -- -all shows full exported documentation; fall back to basic form
  local output = vim.fn.system("go doc -all " .. vim.fn.shellescape(symbol) .. " 2>&1")
  if vim.v.shell_error ~= 0 then
    output = vim.fn.system("go doc " .. vim.fn.shellescape(symbol) .. " 2>&1")
    if vim.v.shell_error ~= 0 then
      vim.notify("[go.lua] goDoc: " .. vim.trim(output), vim.log.levels.WARN)
      return
    end
  end

  local lines = vim.split(output, "\n", { plain = true })
  while #lines > 0 and vim.trim(lines[#lines]) == "" do
    table.remove(lines)
  end

  open_output_window(lines, "󰋖 Go Doc: " .. symbol, "go")
end

-- =============================================================================
--  govulncheck — security vulnerability scan
-- =============================================================================

---@param args? string Extra arguments (default: './...')
local function run_govulncheck(args)
  if vim.fn.executable("govulncheck") == 0 then
    vim.notify(
      "[go.lua] govulncheck not found.\n  Install: go install golang.org/x/vuln/cmd/govulncheck@latest",
      vim.log.levels.ERROR
    )
    return
  end
  args = (args and vim.trim(args) ~= "") and args or "./..."
  create_go_terminal(string.format("govulncheck %s", args), " 󰒃 govulncheck ")
end

-- =============================================================================
--  NEW: Build / Module helpers (revamped with floating terminal + cross-platform)
-- =============================================================================

local function run_mod_tidy()
  create_go_terminal("go mod tidy", " 󰏖 Go Mod Tidy ")
end

local function run_go_generate()
  create_go_terminal("go generate ./...", " 󰠱 Go Generate ")
end

local function go_alternate()
  if not assert_go_file() then
    return
  end
  local filepath = vim.fn.expand("%:p")
  if filepath:match("_test%.go$") then
    -- in test → go to implementation
    local main_file = filepath:gsub("_test%.go$", ".go")
    if vim.fn.filereadable(main_file) == 1 then
      vim.cmd("edit " .. escape_filepath(main_file))
    else
      vim.notify("[go.lua] No implementation file found", vim.log.levels.WARN)
    end
  else
    -- in implementation → go to (or create) test file
    local test_file = filepath:gsub("%.go$", "_test.go")
    vim.cmd("edit " .. escape_filepath(test_file))
  end
end

local function go_doc_browser()
  local word = vim.trim(vim.fn.expand("<cword>"))
  if word == "" then
    vim.notify("[go.lua] Place cursor on a symbol", vim.log.levels.WARN)
    return
  end

  local url = "https://pkg.go.dev/search?q=" .. word

  local cmd_str
  if vim.fn.has("mac") == 1 then
    cmd_str = "open " .. vim.fn.shellescape(url)
  elseif vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1 then
    cmd_str = 'start "" ' .. vim.fn.shellescape(url)
  else
    cmd_str = "xdg-open " .. vim.fn.shellescape(url)
  end

  vim.fn.system(cmd_str)
  if vim.v.shell_error == 0 then
    vim.notify('[go.lua] Opened pkg.go.dev for "' .. word .. '"', vim.log.levels.INFO)
  else
    vim.notify("[go.lua] Failed to open browser", vim.log.levels.ERROR)
  end
end

local function organize_go_imports()
  if #vim.lsp.get_clients({ bufnr = 0, name = "gopls" }) == 0 then
    vim.notify("[go.lua] gopls not attached — cannot organize imports", vim.log.levels.WARN)
    return
  end
  vim.lsp.buf.code_action({
    context = { only = { "source.organizeImports" } },
    apply = true,
  })
end

-- =============================================================================
--  dlv (Delve debugger)
--  Strategy:
--    1. nvim-dap present  → configure adapter once, expose full DAP workflow
--    2. nvim-dap absent   → dlv CLI in a floating terminal (limited but usable)
-- =============================================================================
local _dap_configured = false

--- Configure the Delve DAP adapter and default launch configs.  Idempotent.
---@return boolean success
local function setup_dap()
  if _dap_configured then
    return true
  end

  if vim.fn.executable("dlv") == 0 then
    vim.notify(
      "[go.lua] dlv not found.\n  Install: go install github.com/go-delve/delve/cmd/dlv@latest",
      vim.log.levels.ERROR
    )
    return false
  end

  local ok, dap = pcall(require, "dap")
  if not ok then
    return false
  end -- nvim-dap not installed; terminal fallback used

  -- ── Adapter ──────────────────────────────────────────────────────────────
  dap.adapters.delve = function(callback, config)
    if config.mode == "remote" and config.request == "attach" then
      callback({
        type = "server",
        host = config.host or "127.0.0.1",
        port = config.port or "38697",
      })
    else
      callback({
        type = "server",
        port = "${port}",
        executable = {
          command = "dlv",
          args = { "dap", "-l", "127.0.0.1:${port}", "--log", "--log-output=dap" },
          detached = vim.fn.has("win32") == 0,
        },
      })
    end
  end
  dap.adapters.go = dap.adapters.delve -- legacy alias

  -- ── Launch configurations (add only when none exist yet) ─────────────────
  if not dap.configurations.go or #dap.configurations.go == 0 then
    dap.configurations.go = {
      {
        type = "delve",
        name = "Debug (current file)",
        request = "launch",
        program = "${file}",
      },
      {
        type = "delve",
        name = "Debug package (dir)",
        request = "launch",
        program = "${fileDirname}",
      },
      {
        type = "delve",
        name = "Debug test (current file)",
        request = "launch",
        mode = "test",
        program = "${file}",
      },
      {
        type = "delve",
        name = "Debug test (package)",
        request = "launch",
        mode = "test",
        program = "./${relativeFileDirname}",
      },
      {
        type = "delve",
        name = "Attach to running process",
        request = "attach",
        mode = "local",
        -- Evaluated lazily at debug time so dap.utils is not required at setup
        processId = function()
          local ok_u, utils = pcall(require, "dap.utils")
          return ok_u and utils.pick_process() or tonumber(vim.fn.input("PID: "))
        end,
      },
      {
        type = "delve",
        name = "Remote attach",
        request = "attach",
        mode = "remote",
        host = "127.0.0.1",
        port = "38697",
      },
    }
  end

  -- ── Auto open/close nvim-dap-ui ───────────────────────────────────────────
  local has_ui, dapui = pcall(require, "dapui")
  if has_ui then
    dap.listeners.after.event_initialized["go_lua_dapui"] = function()
      dapui.open()
    end
    dap.listeners.before.event_terminated["go_lua_dapui"] = function()
      dapui.close()
    end
    dap.listeners.before.event_exited["go_lua_dapui"] = function()
      dapui.close()
    end
  end

  _dap_configured = true
  return true
end

--- Run a function with the dap module.  Emits a warning if nvim-dap is absent.
---@param fn fun(dap: table)
local function with_dap(fn)
  if not setup_dap() then
    return
  end
  local ok, dap = pcall(require, "dap")
  if ok then
    fn(dap)
  end
end

-- ── Terminal fallback ─────────────────────────────────────────────────────────

---@param subcmd  string  e.g. 'debug', 'test', 'connect'
---@param extra?  string  Additional CLI arguments
---@param cwd?    string  Working directory
local function dlv_terminal(subcmd, extra, cwd)
  if vim.fn.executable("dlv") == 0 then
    vim.notify(
      "[go.lua] dlv not found.\n  Install: go install github.com/go-delve/delve/cmd/dlv@latest",
      vim.log.levels.ERROR
    )
    return
  end
  local cmd = string.format("dlv %s %s", subcmd, extra or "")
  create_go_terminal(cmd, string.format(" 󰃤 dlv %s ", subcmd), cwd)
end

-- ── Debug entry points ────────────────────────────────────────────────────────

local function dlv_debug()
  if setup_dap() then
    with_dap(function(dap)
      dap.continue()
    end)
  else
    -- Resolve the project root so `dlv debug .` finds main.go
    local cwd = find_main_go() or vim.fn.expand("%:p:h")
    dlv_terminal("debug", ".", cwd)
  end
end

local function dlv_debug_test()
  -- nvim-dap-go gives the best nearest-test detection
  local ok_go, dap_go = pcall(require, "dap-go")
  if ok_go then
    dap_go.debug_test()
    return
  end

  if setup_dap() then
    with_dap(function(dap)
      dap.run({
        type = "delve",
        name = "Debug test (nearest)",
        request = "launch",
        mode = "test",
        program = vim.fn.expand("%:p:h"),
      })
    end)
    return
  end

  dlv_terminal("test", ".", vim.fn.expand("%:p:h"))
end

local function dlv_toggle_breakpoint()
  with_dap(function(dap)
    dap.toggle_breakpoint()
  end)
end

local function dlv_conditional_breakpoint()
  with_dap(function(dap)
    dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
  end)
end

local function dlv_clear_breakpoints()
  with_dap(function(dap)
    dap.clear_breakpoints()
    vim.notify("[go.lua] All breakpoints cleared", vim.log.levels.INFO)
  end)
end

local function dlv_attach_remote()
  local host = vim.fn.input("Remote host [127.0.0.1]: ")
  local port = vim.fn.input("Remote port [38697]: ")
  host = (host == "") and "127.0.0.1" or host
  port = (port == "") and "38697" or port

  if setup_dap() then
    with_dap(function(dap)
      dap.run({
        type = "delve",
        name = "Remote attach",
        request = "attach",
        mode = "remote",
        host = host,
        port = port,
      })
    end)
    return
  end
  dlv_terminal("connect", string.format("%s:%s", host, port))
end

local function dlv_repl()
  with_dap(function(dap)
    dap.repl.open()
  end)
end

local function dlv_hover()
  local ok, widgets = pcall(require, "dap.ui.widgets")
  if ok then
    widgets.hover()
  else
    vim.notify("[go.lua] nvim-dap not available", vim.log.levels.WARN)
  end
end

local function dlv_toggle_ui()
  local ok, dapui = pcall(require, "dapui")
  if ok then
    dapui.toggle()
  else
    vim.notify("[go.lua] nvim-dap-ui not installed", vim.log.levels.WARN)
  end
end

-- =============================================================================
--  Shared test runner  (single source of truth — no duplication)
-- =============================================================================

---@param filepath string Absolute path to any .go file
local function run_tests_for_file(filepath)
  if not filepath:match("%.go$") then
    vim.notify("[go.lua] Not a Go file", vim.log.levels.WARN)
    return
  end

  local main_file, test_file = get_test_file_pair(filepath)
  local files_to_test = {}

  if main_file then
    table.insert(files_to_test, get_relative_path(main_file))
  end
  if test_file then
    table.insert(files_to_test, get_relative_path(test_file))
  end

  if #files_to_test == 0 then
    vim.notify("[go.lua] No valid Go files found", vim.log.levels.ERROR)
    return
  end

  local files_str = table.concat(files_to_test, " ")
  local cmd = string.format("gotestsum --format pkgname --hide-summary=skipped %s", files_str)

  if main_file and test_file then
    vim.notify(
      string.format(
        "[go.lua] Running tests: %s + %s",
        vim.fn.fnamemodify(main_file, ":t"),
        vim.fn.fnamemodify(test_file, ":t")
      ),
      vim.log.levels.INFO
    )
  elseif test_file then
    vim.notify(
      string.format("[go.lua] Running test file: %s (no main file found)", vim.fn.fnamemodify(test_file, ":t")),
      vim.log.levels.WARN
    )
  else
    vim.notify(
      string.format("[go.lua] Running file: %s (no test file found)", vim.fn.fnamemodify(main_file, ":t")),
      vim.log.levels.WARN
    )
  end

  create_go_terminal(cmd, " 󰤑 Go Tests ")
end

-- =============================================================================
--  Auto-organize imports on save (sync so edits are applied BEFORE write)
-- =============================================================================
vim.api.nvim_create_autocmd("BufWritePre", {
  group = aug,
  pattern = "*.go",
  desc = "Organize imports on save (gopls)",
  callback = function()
    local clients = vim.lsp.get_clients({ bufnr = 0, name = "gopls" })
    if #clients == 0 then
      return
    end
    local client = clients[1]
    local params = vim.lsp.util.make_range_params(0, client.offset_encoding or "utf-16")
    params.context = { only = { "source.organizeImports" } }
    local result = vim.lsp.buf_request_sync(0, "textDocument/codeAction", params, 300)
    for _, response in pairs(result or {}) do
      if response.result then
        for _, action in ipairs(response.result) do
          if action.edit then
            vim.lsp.util.apply_workspace_edit(action.edit, client.offset_encoding or "utf-16")
            return
          end
        end
      end
    end
  end,
})

-- =============================================================================
--  User Commands
-- =============================================================================

-- ── Code generation ──────────────────────────────────────────────────────────

vim.api.nvim_create_user_command("GoTests", function(opts)
  if not assert_go_file() then
    return
  end
  local file = vim.fn.expand("%:p")
  local args = opts.args ~= "" and opts.args or "-all"
  save_run_reload(string.format("gotests -w %s %s", args, escape_filepath(file)))
end, { nargs = "?", desc = "Generate tests with gotests" })

vim.api.nvim_create_user_command("GoModifyTags", function(opts)
  if not assert_go_file() then
    return
  end
  local file = vim.fn.expand("%:p")
  local args = opts.args ~= "" and opts.args or ""
  if
    not args:match("%-all")
    and not args:match("%-line")
    and not args:match("%-offset")
    and not args:match("%-struct")
  then
    args = "-all " .. args
  end
  save_run_reload(string.format("gomodifytags -file %s -w %s", escape_filepath(file), args))
end, { nargs = "?", desc = "Modify struct tags with gomodifytags" })

vim.api.nvim_create_user_command("GoIfErr", function()
  if not assert_go_file() then
    return
  end
  if vim.bo.modified then
    vim.cmd("silent! write")
  end
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local file = vim.fn.expand("%:p")
  save_run_reload(string.format("iferr -pos %d %s", line, escape_filepath(file)))
end, { desc = "Generate error handling with iferr" })

-- NEW: Organize imports (manual trigger)
vim.api.nvim_create_user_command("GoOrganizeImports", function()
  organize_go_imports()
end, { desc = "Organize imports with gopls" })

-- ── Run / Test ───────────────────────────────────────────────────────────────

vim.api.nvim_create_user_command("GoRun", function()
  local main_dir = find_main_go()
  if main_dir then
    local rel = get_relative_path(main_dir)
    if rel == "." then
      create_go_terminal("go run .", " 󰐊 Go Run ")
    else
      vim.notify("[go.lua] Running from: " .. vim.fn.fnamemodify(main_dir, ":~:."), vim.log.levels.INFO)
      create_go_terminal("go run .", " 󰐊 Go Run ", main_dir)
    end
    return
  end

  vim.notify("[go.lua] main.go not found — please select it", vim.log.levels.INFO)
  file_picker.select_file({ prompt_title = "Select main.go to run", cwd = vim.fn.getcwd() }, function(selected_file)
    if not selected_file then
      vim.notify("[go.lua] Go run cancelled", vim.log.levels.INFO)
      return
    end
    if not selected_file:match("%.go$") then
      vim.notify("[go.lua] Please select a .go file", vim.log.levels.WARN)
      return
    end
    create_go_terminal("go run .", " 󰐊 Go Run ", vim.fn.fnamemodify(selected_file, ":h"))
  end)
end, { desc = "Run the current Go project" })

vim.api.nvim_create_user_command("GoTestRun", function()
  file_picker.select_file({ prompt_title = "Select Go file to test", cwd = vim.fn.getcwd() }, function(selected_file)
    if not selected_file then
      vim.notify("[go.lua] Test run cancelled", vim.log.levels.INFO)
      return
    end
    run_tests_for_file(selected_file)
  end)
end, { nargs = "*", desc = "Run Go tests with gotestsum (pick file)" })

vim.api.nvim_create_user_command("GoTestRunCurrent", function()
  run_tests_for_file(vim.fn.expand("%:p"))
end, { desc = "Run tests for current Go file" })

-- NEW: Alternate (test ↔ impl)
vim.api.nvim_create_user_command("GoAlternate", function()
  go_alternate()
end, { desc = "Toggle between .go and _test.go" })

-- NEW: Module / Build
vim.api.nvim_create_user_command("GoModTidy", function()
  run_mod_tidy()
end, { desc = "Run go mod tidy" })

vim.api.nvim_create_user_command("GoGenerate", function()
  run_go_generate()
end, { desc = "Run go generate ./..." })

-- ── Refactoring ──────────────────────────────────────────────────────────────

vim.api.nvim_create_user_command("GoFillStruct", function()
  run_fillstruct()
end, { desc = "Fill struct with zero-value fields (fillstruct / gopls fallback)" })

vim.api.nvim_create_user_command("GoFillSwitch", function()
  run_fillswitch()
end, { desc = "Fill (type) switch with cases (fillswitch / gopls fallback)" })

-- ── Documentation ────────────────────────────────────────────────────────────

-- nargs='*' allows multi-token symbol paths: GoDoc encoding/json Marshal
vim.api.nvim_create_user_command("GoDoc", function(opts)
  run_godoc(opts.args)
end, { nargs = "*", desc = "Show go doc for symbol (cursor word or argument)" })

-- NEW: Godoc in browser
vim.api.nvim_create_user_command("GoDocBrowser", function()
  go_doc_browser()
end, { desc = "Open godoc search in browser" })

-- ── Security ─────────────────────────────────────────────────────────────────

vim.api.nvim_create_user_command("GoVulnCheck", function(opts)
  run_govulncheck(opts.args)
end, { nargs = "?", desc = "Run govulncheck on the project" })

-- ── Debugger ─────────────────────────────────────────────────────────────────

vim.api.nvim_create_user_command("GoDlvDebug", function()
  dlv_debug()
end, { desc = "Start / continue debug session" })
vim.api.nvim_create_user_command("GoDlvTest", function()
  dlv_debug_test()
end, { desc = "Debug nearest test" })
vim.api.nvim_create_user_command("GoDlvBreakpoint", function()
  dlv_toggle_breakpoint()
end, { desc = "Toggle breakpoint at current line" })
vim.api.nvim_create_user_command("GoDlvCondBreakpoint", function()
  dlv_conditional_breakpoint()
end, { desc = "Set conditional breakpoint" })
vim.api.nvim_create_user_command("GoDlvClearBreakpoints", function()
  dlv_clear_breakpoints()
end, { desc = "Clear all breakpoints" })
vim.api.nvim_create_user_command("GoDlvAttach", function()
  setup_dap()
  dlv_attach_remote()
end, { desc = "Attach dlv to a remote process" })
vim.api.nvim_create_user_command("GoDlvRepl", function()
  dlv_repl()
end, { desc = "Open nvim-dap REPL" })
vim.api.nvim_create_user_command("GoDlvStepOver", function()
  with_dap(function(d)
    d.step_over()
  end)
end, { desc = "Step over" })
vim.api.nvim_create_user_command("GoDlvStepInto", function()
  with_dap(function(d)
    d.step_into()
  end)
end, { desc = "Step into" })
vim.api.nvim_create_user_command("GoDlvStepOut", function()
  with_dap(function(d)
    d.step_out()
  end)
end, { desc = "Step out" })
vim.api.nvim_create_user_command("GoDlvTerminate", function()
  with_dap(function(d)
    d.terminate()
  end)
end, { desc = "Terminate debug session" })
vim.api.nvim_create_user_command("GoDlvUI", function()
  dlv_toggle_ui()
end, { desc = "Toggle nvim-dap-ui" })

-- =============================================================================
--  which-key Mappings (updated with new features)
-- =============================================================================
local ok_wk, wk = pcall(require, "which-key")
if not ok_wk then
  vim.notify("[go.lua] which-key not found — keymaps not registered", vim.log.levels.WARN)
  return
end

wk.add({
  -- ── Parent groups ────────────────────────────────────────────────────────
  { "<leader>g", group = "Go", icon = "󰟓" },
  { "<leader>gd", group = "Go Debugger", icon = "󰃤" },

  -- ── Code generation ──────────────────────────────────────────────────────
  { "<leader>gt", ":GoTests -all<CR>", desc = "Generate tests (all)", icon = "󰙨" },
  { "<leader>gm", ":GoModifyTags -add-tags json<CR>", desc = "Add JSON struct tags", icon = "󰓹" },
  { "<leader>gr", ":GoModifyTags -remove-tags json<CR>", desc = "Remove JSON struct tags", icon = "󰓹" },
  { "<leader>ge", ":GoIfErr<CR>", desc = "Insert if-err snippet", icon = "󰈸" },
  { "<leader>gi", organize_go_imports, desc = "Organize imports (gopls)", icon = "󰒓" },

  -- ── Refactoring ──────────────────────────────────────────────────────────
  { "<leader>gf", run_fillstruct, desc = "Fill struct with defaults", icon = "󰉸" },
  { "<leader>gw", run_fillswitch, desc = "Fill switch with cases", icon = "󰘬" },

  -- ── Run / Test ───────────────────────────────────────────────────────────
  { "<leader>go", ":GoRun<CR>", desc = "Run Go project", icon = "󰐊" },
  { "<leader>ga", ":GoTestRun<CR>", desc = "Run tests (pick file)", icon = "󰤑" },
  { "<leader>gc", ":GoTestRunCurrent<CR>", desc = "Run tests (current file)", icon = "󰤑" },
  { "<leader>gA", go_alternate, desc = "Alternate test/impl", icon = "󰅂" },

  -- ── Module / Build ───────────────────────────────────────────────────────
  { "<leader>gT", run_mod_tidy, desc = "go mod tidy", icon = "󰏖" },
  { "<leader>gg", run_go_generate, desc = "go generate ./...", icon = "󰠱" },

  -- ── Documentation ────────────────────────────────────────────────────────
  {
    "<leader>gk",
    function()
      run_godoc()
    end,
    desc = "Go doc (cursor word)",
    icon = "󰋖",
  },
  { "<leader>gD", go_doc_browser, desc = "Godoc (browser)", icon = "󰖟" },

  -- ── Security ─────────────────────────────────────────────────────────────
  { "<leader>gv", ":GoVulnCheck<CR>", desc = "govulncheck ./...", icon = "󰒃" },

  -- ── Debugger ─────────────────────────────────────────────────────────────
  { "<leader>gds", dlv_debug, desc = "Start / continue debug", icon = "󰐊" },
  { "<leader>gdt", dlv_debug_test, desc = "Debug nearest test", icon = "󰙨" },
  { "<leader>gdb", dlv_toggle_breakpoint, desc = "Toggle breakpoint", icon = "󰝥" },
  { "<leader>gdB", dlv_conditional_breakpoint, desc = "Conditional breakpoint", icon = "󰝥" },
  { "<leader>gdx", dlv_clear_breakpoints, desc = "Clear all breakpoints", icon = "󰅙" },
  {
    "<leader>gdn",
    function()
      with_dap(function(d)
        d.step_over()
      end)
    end,
    desc = "Step over",
    icon = "󰆷",
  },
  {
    "<leader>gdi",
    function()
      with_dap(function(d)
        d.step_into()
      end)
    end,
    desc = "Step into",
    icon = "󰆹",
  },
  {
    "<leader>gdo",
    function()
      with_dap(function(d)
        d.step_out()
      end)
    end,
    desc = "Step out",
    icon = "󰆸",
  },
  {
    "<leader>gdq",
    function()
      with_dap(function(d)
        d.terminate()
      end)
    end,
    desc = "Terminate",
    icon = "󰓛",
  },
  { "<leader>gdr", dlv_repl, desc = "Open REPL", icon = "󰞇" },
  {
    "<leader>gda",
    function()
      setup_dap()
      dlv_attach_remote()
    end,
    desc = "Attach to remote",
    icon = "󰌷",
  },
  { "<leader>gdu", dlv_toggle_ui, desc = "Toggle DAP UI", icon = "󰕮" },
  { "<leader>gdh", dlv_hover, desc = "Hover variable value", icon = "󰠿" },
})

-- =============================================================================
--  Buffer-local extras for Go files
-- =============================================================================
vim.api.nvim_create_autocmd("FileType", {
  group = aug,
  pattern = "go",
  callback = function(ev)
    -- <leader>K → go doc in floating window (distinct from LSP hover on K)
    vim.keymap.set("n", "<leader>K", function()
      run_godoc()
    end, {
      buffer = ev.buf,
      silent = true,
      desc = "Go doc (floating window)",
    })
  end,
})
