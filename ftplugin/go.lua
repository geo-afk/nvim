-- =============================================================================
--  ftplugin/go.lua — Neovim Go development utilities
--  Tools: gotests · gomodifytags · iferr · gotestsum · fillstruct · fillswitch
--         dlv (Delve debugger) · govulncheck · go doc
-- =============================================================================

local file_picker = require("utils.file_selector")

vim.opt_local.tabstop = 4
vim.opt_local.shiftwidth = 4
vim.opt_local.softtabstop = 0
vim.opt_local.expandtab = false
vim.opt_local.textwidth = 120

-- =============================================================================
--  Augroup
-- =============================================================================
local aug = vim.api.nvim_create_augroup("GoLua", { clear = true })

-- =============================================================================
--  Tool Registry
-- =============================================================================
local TOOLS = {
  { cmd = "gotests", required = true, install = "go install github.com/cweill/gotests/gotests@latest" },
  { cmd = "gomodifytags", required = true, install = "go install github.com/fatih/gomodifytags@latest" },
  { cmd = "iferr", required = true, install = "go install github.com/koron/iferr@latest" },
  { cmd = "gotestsum", required = true, install = "go install gotest.tools/gotestsum@latest" },
  -- fillstruct/fillswitch: broken on Go ≥1.25; gopls fallback used automatically.
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

vim.defer_fn(check_tools, 500)

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

local go_term_config = {
  width_ratio = 0.8,
  height_ratio = 0.7,
  transparent = true,
  winblend = 15,
  colors = {
    title_bg = "#00ADD8",
    title_fg = "#000000",
    border = "#00ADD8",
  },
}

---@param cmd   string  Shell command to run
---@param title string  Window title
---@param cwd?  string  Optional working directory
local function create_go_terminal(cmd, title, cwd)
  local ft = get_float_term()

  if not ft then
    -- Fallback: simple bottom split
    local run_cmd = cwd and string.format("cd %s && %s", vim.fn.shellescape(cwd), cmd) or cmd
    vim.cmd("botright 15split")
    vim.cmd("terminal " .. run_cmd)
    vim.cmd("startinsert")
    return
  end

  if not _float_term_setup then
    ft.setup(go_term_config)
    _float_term_setup = true
  end

  if cwd then
    local is_win = vim.uv.os_uname().sysname:match("Windows") ~= nil
    if is_win then
      cmd = string.format('Push-Location -LiteralPath "%s"; %s; Pop-Location', cwd, cmd)
    else
      -- Use subshell so the cd is scoped
      cmd = string.format("(cd %s && %s)", vim.fn.shellescape(cwd), cmd)
    end
  end

  ft.create_terminal(cmd, { title = title })
end

-- =============================================================================
--  Generic Helpers
-- =============================================================================

---@param filepath string Absolute path
---@return string
local function escape_filepath(filepath)
  if vim.uv.os_uname().sysname:match("Windows") ~= nil then
    return '"' .. filepath:gsub("\\", "/") .. '"'
  end
  return vim.fn.shellescape(filepath)
end

---Return filepath relative to cwd, or the original path if outside cwd.
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

---Derive a `./pkg/dir` package pattern from an absolute file path.
---This is what `go test` and `gotestsum` expect — NOT individual file paths.
---@param filepath string Absolute path to any .go file
---@return string  e.g. "./internal/server" or "."
local function file_to_pkg_pattern(filepath)
  local dir = vim.fn.fnamemodify(filepath, ":h")
  local rel_dir = get_relative_path(dir)
  if rel_dir == "." then
    return "."
  end
  -- Normalise separators and ensure leading ./
  rel_dir = rel_dir:gsub("\\", "/")
  if not rel_dir:match("^%.?/") then
    rel_dir = "./" .. rel_dir
  end
  return rel_dir
end

---Return the main/test file pair for a given .go path.
---@param filepath string
---@return string|nil main_file, string|nil test_file
local function get_test_file_pair(filepath)
  if filepath:match("_test%.go$") then
    local main_file = filepath:gsub("_test%.go$", ".go")
    return (vim.fn.filereadable(main_file) == 1) and main_file or nil, filepath
  else
    local test_file = filepath:gsub("%.go$", "_test.go")
    return filepath, (vim.fn.filereadable(test_file) == 1) and test_file or nil
  end
end

---Find the directory that contains the project's main.go.
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

---Guard: notify and return false when current buffer is not a Go file.
---@return boolean
local function assert_go_file()
  if not vim.fn.expand("%:p"):match("%.go$") then
    vim.notify("[go.lua] Not a Go file", vim.log.levels.WARN)
    return false
  end
  return true
end

---Byte offset of the cursor for -offset= flags.
---@return integer|nil
local function cursor_byte_offset()
  local line, col = unpack(vim.api.nvim_win_get_cursor(0))
  local line_start = vim.fn.line2byte(line)
  if line_start < 0 then
    return nil
  end
  return line_start + col
end

---Write buffer if modified, run `argv` async, reload on success.
---@param argv string[]
local function save_run_reload(argv)
  if vim.bo.modified then
    vim.cmd("silent! write")
  end
  vim.system(argv, { text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        local msg = vim.trim(result.stderr ~= "" and result.stderr or result.stdout)
        vim.notify("[go.lua] Command failed:\n" .. msg, vim.log.levels.ERROR)
        return
      end
      if vim.api.nvim_buf_is_valid(vim.api.nvim_get_current_buf()) then
        vim.cmd("edit!")
      end
    end)
  end)
end

---@param kind string
---@param label string
local function apply_gopls_code_action(kind, label)
  if #vim.lsp.get_clients({ bufnr = 0, name = "gopls" }) == 0 then
    vim.notify(string.format("[go.lua] %s: gopls not attached", label), vim.log.levels.ERROR)
    return
  end
  vim.lsp.buf.code_action({
    context = { only = { kind } },
    apply = true,
  })
end

-- =============================================================================
--  Floating Read-only Output Window  (GoDoc, etc.)
-- =============================================================================

---@param lines   string[]
---@param title   string
---@param ft_name? string
---@return integer|nil buf, integer|nil win
local function open_output_window(lines, title, ft_name)
  if not lines or #lines == 0 then
    vim.notify("[go.lua] " .. title .. ": no output", vim.log.levels.WARN)
    return nil, nil
  end

  ft_name = ft_name or "text"
  local ui = vim.api.nvim_list_uis()[1]
  local width = math.floor(ui.width * 0.75)
  local height = math.floor(ui.height * 0.70)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = ft_name
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].readonly = true

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((ui.height - height) / 2),
    col = math.floor((ui.width - width) / 2),
    style = "minimal",
    border = "rounded",
    title = " " .. title .. " ",
    title_pos = "center",
  })

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
--  fillstruct / fillswitch
-- =============================================================================

local function fillstruct_via_lsp()
  apply_gopls_code_action("refactor.rewrite.fillStruct", "fillstruct")
end

local function fillswitch_via_lsp()
  apply_gopls_code_action("refactor.rewrite.fillSwitch", "fillswitch")
end

---Parse and apply JSON edit list from fillstruct/fillswitch.
---@param output    string
---@param tool_name string
---@return boolean
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
  for _, edit in ipairs(edits) do
    vim.api.nvim_buf_set_lines(bufnr, edit.start - 1, edit["end"], false, vim.split(edit.code, "\n", { plain = true }))
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
  local pos = offset and string.format("-offset=%d", offset) or string.format("-line=%d", line)
  local output = vim.fn.system(string.format("fillstruct -file=%s %s", escape_filepath(file), pos))

  if vim.v.shell_error ~= 0 then
    vim.notify("[go.lua] fillstruct CLI failed — trying gopls…", vim.log.levels.WARN)
    fillstruct_via_lsp()
    return
  end
  if not apply_reftools_edits(output, "fillstruct") then
    vim.notify("[go.lua] fillstruct: no struct literal found — trying gopls", vim.log.levels.INFO)
    fillstruct_via_lsp()
  end
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
  local pos = offset and string.format("-offset=%d", offset) or string.format("-line=%d", line)
  local output = vim.fn.system(string.format("fillswitch -file=%s %s", escape_filepath(file), pos))

  if vim.v.shell_error ~= 0 then
    vim.notify("[go.lua] fillswitch CLI failed — trying gopls…", vim.log.levels.WARN)
    fillswitch_via_lsp()
    return
  end
  if not apply_reftools_edits(output, "fillswitch") then
    vim.notify("[go.lua] fillswitch: no (type) switch found — trying gopls", vim.log.levels.INFO)
    fillswitch_via_lsp()
  end
end

-- =============================================================================
--  GoDoc
-- =============================================================================

---@param symbol? string
local function run_godoc(symbol)
  symbol = vim.trim(symbol or "")
  if symbol == "" then
    symbol = vim.fn.expand("<cword>")
  end
  if symbol == "" then
    vim.notify("[go.lua] goDoc: place cursor on a symbol or supply one as argument", vim.log.levels.WARN)
    return
  end

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
--  govulncheck
-- =============================================================================

---@param args? string
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
--  Module / Build helpers
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
    local main_file = filepath:gsub("_test%.go$", ".go")
    if vim.fn.filereadable(main_file) == 1 then
      vim.cmd("edit " .. escape_filepath(main_file))
    else
      vim.notify("[go.lua] No implementation file found", vim.log.levels.WARN)
    end
  else
    vim.cmd("edit " .. escape_filepath(filepath:gsub("%.go$", "_test.go")))
  end
end

local function go_doc_browser()
  local word = vim.trim(vim.fn.expand("<cword>"))
  if word == "" then
    vim.notify("[go.lua] Place cursor on a symbol", vim.log.levels.WARN)
    return
  end

  local url = "https://pkg.go.dev/search?q=" .. word
  local ok, err = pcall(vim.ui.open, url)
  if ok then
    vim.notify('[go.lua] Opened pkg.go.dev for "' .. word .. '"', vim.log.levels.INFO)
  else
    vim.notify("[go.lua] Failed to open browser: " .. tostring(err), vim.log.levels.ERROR)
  end
end

local function organize_go_imports()
  if #vim.lsp.get_clients({ bufnr = 0, name = "gopls" }) == 0 then
    vim.notify("[go.lua] gopls not attached — cannot organize imports", vim.log.levels.WARN)
    return
  end
  vim.lsp.buf.code_action({ context = { only = { "source.organizeImports" } }, apply = true })
end

local go_debugger = nil

local function get_go_debugger()
  if go_debugger then
    return go_debugger
  end
  local ok, mod = pcall(require, "custom.go.debugger")
  if not ok then
    vim.notify("[go.lua] Failed to load Go debugger: " .. tostring(mod), vim.log.levels.ERROR)
    return nil
  end
  mod.setup()
  go_debugger = mod
  return mod
end

local function with_go_debugger(action)
  return function(...)
    local dbg = get_go_debugger()
    if not dbg then
      return
    end
    return dbg[action](...)
  end
end

-- =============================================================================
--  Test runner
--  FIX: go test / gotestsum requires package patterns (./pkg/dir or ./...),
--       NOT individual file paths.  We derive the package directory from the
--       file and pass that as the target.
-- =============================================================================

---@param filepath string  Absolute path to any .go file
local function run_tests_for_file(filepath)
  if not filepath:match("%.go$") then
    vim.notify("[go.lua] Not a Go file", vim.log.levels.WARN)
    return
  end

  local _, test_file = get_test_file_pair(filepath)

  -- Derive the package directory regardless of whether it's a test or impl file.
  -- Both the impl and test file always live in the same directory.
  local pkg_pattern = file_to_pkg_pattern(filepath)
  local cwd = vim.fn.getcwd()

  if not test_file then
    -- No _test.go found for this package — nothing to run.
    vim.notify(
      string.format("[go.lua] No test file found for %s", vim.fn.fnamemodify(filepath, ":t")),
      vim.log.levels.WARN
    )
    return
  end

  -- gotestsum passes remaining arguments after '--' directly to 'go test'.
  -- Using the package directory pattern ensures all imports resolve correctly
  -- because Go builds the full package, not isolated files.
  local cmd = string.format("gotestsum --format pkgname --hide-summary=skipped -- %s", pkg_pattern)

  vim.notify(string.format("[go.lua] Running tests in package: %s", pkg_pattern), vim.log.levels.INFO)

  create_go_terminal(cmd, " 󰤑 Go Tests ", cwd)
end

-- =============================================================================
--  Auto-organize imports on save
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

vim.api.nvim_create_user_command("GoTests", function(opts)
  if not assert_go_file() then
    return
  end
  local args = opts.args ~= "" and opts.args or "-all"
  local argv = { "gotests", "-w" }
  vim.list_extend(argv, vim.split(args, "%s+", { trimempty = true }))
  table.insert(argv, vim.fn.expand("%:p"))
  save_run_reload(argv)
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
  local argv = { "gomodifytags", "-file", file, "-w" }
  vim.list_extend(argv, vim.split(args, "%s+", { trimempty = true }))
  save_run_reload(argv)
end, { nargs = "?", desc = "Modify struct tags with gomodifytags" })

vim.api.nvim_create_user_command("GoIfErr", function()
  if not assert_go_file() then
    return
  end
  if vim.bo.modified then
    vim.cmd("silent! write")
  end
  save_run_reload({ "iferr", "-pos", tostring(vim.api.nvim_win_get_cursor(0)[1]), vim.fn.expand("%:p") })
end, { desc = "Generate error handling with iferr" })

vim.api.nvim_create_user_command("GoOrganizeImports", function()
  organize_go_imports()
end, { desc = "Organize imports with gopls" })

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

vim.api.nvim_create_user_command("GoAlternate", function()
  go_alternate()
end, { desc = "Toggle between .go and _test.go" })

vim.api.nvim_create_user_command("GoModTidy", function()
  run_mod_tidy()
end, { desc = "Run go mod tidy" })

vim.api.nvim_create_user_command("GoGenerate", function()
  run_go_generate()
end, { desc = "Run go generate ./..." })

vim.api.nvim_create_user_command("GoFillStruct", function()
  run_fillstruct()
end, { desc = "Fill struct with zero-value fields (fillstruct / gopls fallback)" })

vim.api.nvim_create_user_command("GoFillSwitch", function()
  run_fillswitch()
end, { desc = "Fill (type) switch with cases (fillswitch / gopls fallback)" })

vim.api.nvim_create_user_command("GoDoc", function(opts)
  run_godoc(opts.args)
end, { nargs = "*", desc = "Show go doc for symbol" })

vim.api.nvim_create_user_command("GoDocBrowser", function()
  go_doc_browser()
end, { desc = "Open godoc search in browser" })

vim.api.nvim_create_user_command("GoVulnCheck", function(opts)
  run_govulncheck(opts.args)
end, { nargs = "?", desc = "Run govulncheck on the project" })

vim.api.nvim_create_user_command("GoDlvDebug", function()
  with_go_debugger("debug")()
end, { desc = "Start Delve debug session" })
vim.api.nvim_create_user_command("GoDlvTest", function()
  with_go_debugger("test")()
end, { desc = "Debug tests in current package" })
vim.api.nvim_create_user_command("GoDlvBreakpoint", function()
  with_go_debugger("toggle_breakpoint")()
end, { desc = "Toggle breakpoint at current line" })
vim.api.nvim_create_user_command("GoDlvSetBreakpoint", function()
  with_go_debugger("set_breakpoint")()
end, { desc = "Set breakpoint at current line" })
vim.api.nvim_create_user_command("GoDlvRemoveBreakpoint", function()
  with_go_debugger("remove_breakpoint")()
end, { desc = "Remove breakpoint at current line" })
vim.api.nvim_create_user_command("GoDlvListBreakpoints", function()
  with_go_debugger("list_breakpoints")()
end, { desc = "List breakpoints" })
vim.api.nvim_create_user_command("GoDlvCondBreakpoint", function()
  with_go_debugger("conditional_breakpoint")()
end, { desc = "Set conditional breakpoint" })
vim.api.nvim_create_user_command("GoDlvClearBreakpoints", function()
  with_go_debugger("clear_breakpoints")()
end, { desc = "Clear all breakpoints" })
vim.api.nvim_create_user_command("GoDlvAttach", function()
  with_go_debugger("attach_spawn")()
end, { desc = "Build, start, and attach to current Go program" })
vim.api.nvim_create_user_command("GoDlvAttachPID", function()
  with_go_debugger("attach")()
end, { desc = "Attach to an existing PID" })
vim.api.nvim_create_user_command("GoDlvAttachSelect", function()
  with_go_debugger("attach_select")()
end, { desc = "Pick a process and attach" })
vim.api.nvim_create_user_command("GoDlvConnect", function(opts)
  with_go_debugger("connect")(opts.args)
end, { nargs = "?", desc = "Connect to headless Delve DAP server" })
vim.api.nvim_create_user_command("GoDlvContinue", function()
  with_go_debugger("continue")()
end, { desc = "Continue debuggee" })
vim.api.nvim_create_user_command("GoDlvStepOver", function()
  with_go_debugger("step_over")()
end, { desc = "Step over" })
vim.api.nvim_create_user_command("GoDlvStepInto", function()
  with_go_debugger("step_into")()
end, { desc = "Step into" })
vim.api.nvim_create_user_command("GoDlvStepOut", function()
  with_go_debugger("step_out")()
end, { desc = "Step out" })
vim.api.nvim_create_user_command("GoDlvStack", function()
  with_go_debugger("stack")()
end, { desc = "Refresh stack frames" })
vim.api.nvim_create_user_command("GoDlvVariables", function()
  with_go_debugger("variables")()
end, { desc = "Refresh variables" })
vim.api.nvim_create_user_command("GoDlvInspect", function(opts)
  with_go_debugger("inspect")(opts.args)
end, { nargs = "*", desc = "Inspect expression" })
vim.api.nvim_create_user_command("GoDlvStop", function()
  with_go_debugger("stop")()
end, { desc = "Stop debug session" })
vim.api.nvim_create_user_command("GoDlvToggleUI", function()
  with_go_debugger("toggle_ui")()
end, { desc = "Toggle debugger UI" })

-- =============================================================================
--  which-key Mappings
-- =============================================================================

local function go_map(lhs, rhs, desc)
  vim.keymap.set("n", lhs, rhs, { buffer = true, silent = true, desc = desc })
end

local ok_wk, wk = pcall(require, "which-key")
if ok_wk then
  wk.add({
    { "<leader>t", group = "Go", icon = "󰟓", buffer = 0 },
    { "<leader>td", group = "Go Debugger", icon = "󰃤", buffer = 0 },
  })
end

go_map("<leader>tt", "<cmd>GoTests -all<CR>", "Generate tests (all)")
go_map("<leader>tm", "<cmd>GoModifyTags -add-tags json<CR>", "Add JSON struct tags")
go_map("<leader>tr", "<cmd>GoModifyTags -remove-tags json<CR>", "Remove JSON struct tags")
go_map("<leader>te", "<cmd>GoIfErr<CR>", "Insert if-err snippet")
go_map("<leader>ti", organize_go_imports, "Organize imports (gopls)")
go_map("<leader>tf", run_fillstruct, "Fill struct with defaults")
go_map("<leader>tw", run_fillswitch, "Fill switch with cases")
go_map("<leader>to", "<cmd>GoRun<CR>", "Run Go project")
go_map("<leader>ta", "<cmd>GoTestRun<CR>", "Run tests (pick file)")
go_map("<leader>tc", "<cmd>GoTestRunCurrent<CR>", "Run tests (current file)")
go_map("<leader>tA", go_alternate, "Alternate test/impl")
go_map("<leader>tT", run_mod_tidy, "go mod tidy")
go_map("<leader>tg", run_go_generate, "go generate ./...")
go_map("<leader>tk", function()
  run_godoc()
end, "Go doc (cursor word)")
go_map("<leader>tD", go_doc_browser, "Godoc (browser)")
go_map("<leader>tv", "<cmd>GoVulnCheck<CR>", "govulncheck ./...")
go_map("<leader>tds", with_go_debugger("debug"), "Start debug session")
go_map("<leader>tdt", with_go_debugger("test"), "Debug tests in current package")
go_map("<leader>tdb", with_go_debugger("toggle_breakpoint"), "Toggle breakpoint")
go_map("<leader>tdB", with_go_debugger("conditional_breakpoint"), "Conditional breakpoint")
go_map("<leader>tdl", with_go_debugger("list_breakpoints"), "List breakpoints")
go_map("<leader>tdx", with_go_debugger("clear_breakpoints"), "Clear all breakpoints")
go_map("<leader>tda", with_go_debugger("attach_spawn"), "Build, start, and attach")
go_map("<leader>tdc", with_go_debugger("continue"), "Continue")
go_map("<leader>tdo", with_go_debugger("step_over"), "Step over")
go_map("<leader>tdi", with_go_debugger("step_into"), "Step into")
go_map("<leader>tdO", with_go_debugger("step_out"), "Step out")
go_map("<leader>tdv", with_go_debugger("variables"), "Variables")
go_map("<leader>tdf", with_go_debugger("stack"), "Stack frames")
go_map("<leader>tdp", with_go_debugger("inspect"), "Inspect expression")
go_map("<leader>tdq", with_go_debugger("stop"), "Stop debugger")
go_map("<leader>tdu", with_go_debugger("toggle_ui"), "Toggle UI")

-- =============================================================================
--  Buffer-local extras
-- =============================================================================

vim.keymap.set("n", "<leader>K", function()
  run_godoc()
end, {
  buffer = true,
  silent = true,
  desc = "Go doc (floating window)",
})
