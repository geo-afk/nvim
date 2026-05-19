-- lua/dap/vscode.lua
-- Load and merge .vscode/launch.json configurations into nvim-dap.
-- Supports variable substitution for common VSCode variables.
-- Called automatically by plugins/dap.lua on startup.

local M = {}

-- ── Variable substitution ─────────────────────────────────────────────────
-- Replaces ${variable} tokens in strings and tables, mirroring VS Code
-- debugger variable resolution.

local function resolve_var(value, ctx)
  if type(value) ~= "string" then return value end
  return (value:gsub("%${(.-)}", function(var)
    local replacements = {
      workspaceFolder        = ctx.workspace,
      workspaceFolderBasename= vim.fn.fnamemodify(ctx.workspace, ":t"),
      file                   = vim.fn.expand("%:p"),
      fileBasename           = vim.fn.expand("%:t"),
      fileBasenameNoExtension= vim.fn.expand("%:t:r"),
      fileDirname            = vim.fn.expand("%:p:h"),
      fileExtname            = vim.fn.expand("%:e"),
      relativeFile           = vim.fn.expand("%"),
      relativeFileDirname    = vim.fn.expand("%:h"),
      cwd                    = vim.fn.getcwd(),
      lineNumber             = tostring(vim.fn.line(".")),
      selectedText           = "",
      pathSeparator          = package.config:sub(1, 1),
      userHome               = vim.fn.expand("~"),
      env                    = "",   -- ${env:VAR} handled separately below
    }

    -- ${env:VAR_NAME}
    local env_var = var:match("^env:(.+)$")
    if env_var then return os.getenv(env_var) or "" end

    -- ${config:key} – skip silently
    if var:match("^config:") then return "${" .. var .. "}" end

    return replacements[var] or ("${" .. var .. "}")
  end))
end

local function resolve_table(tbl, ctx)
  if type(tbl) ~= "table" then return resolve_var(tbl, ctx) end
  local result = {}
  for k, v in pairs(tbl) do
    if type(v) == "table" then
      result[k] = resolve_table(v, ctx)
    elseif type(v) == "string" then
      result[k] = resolve_var(v, ctx)
    else
      result[k] = v
    end
  end
  return result
end

-- ── Adapter-type normalisation ────────────────────────────────────────────
-- VSCode launch.json uses type names that may differ from the adapter names
-- registered in nvim-dap.  Map known VSCode types → nvim-dap adapter names.
local type_map = {
  ["go"]              = "go",
  ["node"]            = "pwa-node",
  ["node2"]           = "pwa-node",
  ["pwa-node"]        = "pwa-node",
  ["pwa-chrome"]      = "pwa-chrome",
  ["pwa-msedge"]      = "pwa-msedge",
  ["chrome"]          = "pwa-chrome",
  ["msedge"]          = "pwa-msedge",
  ["node-terminal"]   = "node-terminal",
  ["coreclr"]         = "coreclr",
}

-- ── Load launch.json ──────────────────────────────────────────────────────

---@param workspace string  path to .vscode/ parent directory
---@return table[]          list of dap configuration tables
local function load_launch_json(workspace)
  local launch_file = workspace .. "/.vscode/launch.json"
  if vim.fn.filereadable(launch_file) == 0 then return {} end

  local raw = table.concat(vim.fn.readfile(launch_file), "\n")

  -- Strip JSON comments (// and /* */ ) – launch.json is JSON-with-comments
  raw = raw:gsub("/%*.-%*/", "")           -- block comments
  raw = raw:gsub("//[^\n]*", "")           -- line comments
  raw = raw:gsub(",(%s*[%]|}])", "%1")     -- trailing commas

  local ok, parsed = pcall(vim.fn.json_decode, raw)
  if not ok or type(parsed) ~= "table" then
    vim.notify("[dap/vscode] Failed to parse .vscode/launch.json", vim.log.levels.WARN)
    return {}
  end

  local configs = {}
  local ctx = { workspace = workspace }

  for _, entry in ipairs(parsed.configurations or {}) do
    if entry.type and entry.request and entry.name then
      local mapped_type = type_map[entry.type] or entry.type
      local resolved    = resolve_table(entry, ctx)
      resolved.type     = mapped_type
      table.insert(configs, resolved)
    end
  end

  return configs
end

-- ── Merge into dap.configurations ────────────────────────────────────────

---@param workspace string
function M.load(workspace)
  local dap_ok, dap = pcall(require, "dap")
  if not dap_ok then return end

  local configs = load_launch_json(workspace)
  if #configs == 0 then return end

  -- Group by type, then merge without duplicating names
  local by_type = {}
  for _, cfg in ipairs(configs) do
    by_type[cfg.type] = by_type[cfg.type] or {}
    table.insert(by_type[cfg.type], cfg)
  end

  for adapter_type, cfgs in pairs(by_type) do
    dap.configurations[adapter_type] = dap.configurations[adapter_type] or {}
    local existing_names = {}
    for _, c in ipairs(dap.configurations[adapter_type]) do
      existing_names[c.name] = true
    end
    for _, c in ipairs(cfgs) do
      if not existing_names[c.name] then
        table.insert(dap.configurations[adapter_type], 1, c) -- prepend so VSCode configs appear first
      end
    end

    -- Also register for common filetypes associated with this adapter
    local ft_map = {
      ["go"]          = { "go" },
      ["pwa-node"]    = { "javascript", "typescript", "javascriptreact", "typescriptreact" },
      ["pwa-chrome"]  = { "html", "typescript", "typescriptreact", "javascript" },
      ["pwa-msedge"]  = { "html", "typescript", "typescriptreact", "javascript" },
    }
    local fts = ft_map[adapter_type] or {}
    for _, ft in ipairs(fts) do
      if ft ~= adapter_type then
        dap.configurations[ft] = dap.configurations[ft] or {}
        for _, c in ipairs(cfgs) do
          local found = false
          for _, ec in ipairs(dap.configurations[ft]) do
            if ec.name == c.name then found = true; break end
          end
          if not found then
            table.insert(dap.configurations[ft], 1, c)
          end
        end
      end
    end
  end

  vim.notify(
    ("[dap/vscode] Loaded %d config(s) from .vscode/launch.json"):format(#configs),
    vim.log.levels.INFO
  )
end

-- ── Auto-load on BufEnter (detect workspace change) ──────────────────────
function M.setup()
  local loaded_roots = {}

  vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
    group    = vim.api.nvim_create_augroup("DapVSCode", { clear = true }),
    callback = function()
      local root = vim.fs.root(vim.fn.expand("%:p:h"), { ".vscode" })
      if root and not loaded_roots[root] then
        loaded_roots[root] = true
        M.load(root)
      end
    end,
    desc = "Auto-load .vscode/launch.json into nvim-dap",
  })
end

return M
