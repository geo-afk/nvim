local function gh(repo)
  return "https://github.com/" .. repo
end

local function is_single_spec(spec)
  if type(spec) ~= "table" then
    return false
  end

  if type(spec[1]) == "string" then
    return true
  end

  return spec.src ~= nil or spec.dir ~= nil or spec.name ~= nil or spec.config ~= nil or spec.opts ~= nil
end

local function normalize_specs(spec)
  if not spec then
    return {}
  end

  if is_single_spec(spec) then
    return { spec }
  end

  return spec
end

local function repo_name(spec)
  if spec.name then
    return spec.name
  end

  local src = spec.src or spec[1]
  if type(src) ~= "string" then
    return nil
  end

  local trimmed = src:gsub("\\", "/"):gsub("/+$", "")
  return trimmed:match("([^/]+)%.git$") or trimmed:match("([^/]+)$")
end

local function pack_version(spec)
  if spec.version == "*" then
    return nil
  end

  if type(spec.version) == "string" then
    local major = spec.version:match("^v?(%d+)%.%*$")
    if major then
      return vim.version.range(major)
    end

    return spec.version
  end

  if spec.version ~= nil then
    return spec.version
  end

  return spec.branch or spec.tag or spec.commit
end

local function should_include(spec)
  if spec.enabled == false then
    return false
  end

  if type(spec.cond) == "function" then
    local ok, result = pcall(spec.cond)
    if not ok then
      vim.notify("pack: cond failed for " .. tostring(repo_name(spec)), vim.log.levels.WARN)
      return false
    end
    return result
  end

  if spec.cond == false then
    return false
  end

  return true
end

local top_level_modules = {
  "plugins.ui.colortheme",
  "plugins.treesitter",
  "plugins.lsp.blink",
  "plugins.lsp.conform",
  "plugins.lsp.lazydev",
  "plugins.lsp.lsp",
  "plugins.lsp.luasnip",
  "plugins.lsp.nvim-lint",
  "plugins.tools.dev-server",
  "plugins.tools.flash",
  "plugins.tools.lazygit",
  "plugins.tools.telescope",
  "plugins.tools.toggle-term",
  "plugins.tools.trouble",
  "plugins.tools.ts-auto-close",
  "plugins.tools.whichkey",
  "plugins.ui.color_highlight",
  "plugins.ui.gitsigns",
  "plugins.ui.rainbow",
  "plugins.ui.smear",
}

local loaded_modules = {}
local ordered_specs = {}
local install_specs = {}
local seen_install = {}
local spec_order = 0

local function register_install_spec(spec)
  if spec.dir or not should_include(spec) then
    return
  end

  local src = spec.src or spec[1]
  if type(src) ~= "string" then
    return
  end

  if
    not src:match("^https?://")
    and not src:match("^git@")
    and not src:match("^gh:")
    and src:match("^[^%s]+/[^%s]+$")
  then
    src = gh(src)
  end

  local name = repo_name(spec)
  if not name or seen_install[name] then
    return
  end

  seen_install[name] = true
  table.insert(install_specs, {
    src = src,
    name = name,
    version = pack_version(spec),
  })
end

local function collect_dependency(dep)
  if type(dep) == "string" then
    register_install_spec({ dep })
    return
  end

  if type(dep) ~= "table" then
    return
  end

  for _, spec in ipairs(normalize_specs(dep)) do
    register_install_spec(spec)
    if spec.dependencies then
      for _, child in ipairs(spec.dependencies) do
        collect_dependency(child)
      end
    end
  end
end

local function collect_module(module_name)
  if loaded_modules[module_name] then
    return
  end

  loaded_modules[module_name] = true
  local specs = normalize_specs(require(module_name))

  for _, spec in ipairs(specs) do
    spec_order = spec_order + 1
    spec.__order = spec_order
    table.insert(ordered_specs, spec)
    register_install_spec(spec)

    for _, dep in ipairs(spec.dependencies or {}) do
      collect_dependency(dep)
    end
  end
end

for _, module_name in ipairs(top_level_modules) do
  collect_module(module_name)
end

vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

require("config.options")
require("config.keymaps")
require("config.autocmds")
require("config.neovide")

vim.diagnostic.config({
  severity_sort = true,
  underline = true,
  signs = true,
  virtual_text = {
    source = "if_many",
    spacing = 2,
  },
  virtual_lines = false,
  float = {
    border = "rounded",
    source = "if_many",
  },
})

local pack_hooks = {
  ["LuaSnip"] = function(path)
    if vim.fn.executable("make") == 1 then
      vim.system({ "make", "install_jsregexp" }, { cwd = path }, function(obj)
        if obj.code ~= 0 then
          vim.schedule(function()
            vim.notify("LuaSnip build failed", vim.log.levels.WARN)
          end)
        end
      end)
    end
  end,
}

vim.api.nvim_create_autocmd("PackChanged", {
  callback = function(ev)
    if ev.data.kind ~= "install" and ev.data.kind ~= "update" then
      return
    end

    local hook = pack_hooks[ev.data.spec.name]
    if hook then
      hook(ev.data.path)
    end
  end,
})

if #install_specs > 0 then
  vim.pack.add(install_specs, { confirm = false, load = true })
end

local implicit_setups = {
  ["folke/lazydev.nvim"] = function(opts)
    require("lazydev").setup(opts)
  end,
  ["saghen/blink.cmp"] = function(opts)
    require("blink.cmp").setup(opts)
  end,
  ["stevearc/conform.nvim"] = function(opts)
    require("conform").setup(opts)
  end,
  ["lewis6991/gitsigns.nvim"] = function(opts)
    require("gitsigns").setup(opts)
  end,
  ["folke/trouble.nvim"] = function(opts)
    require("trouble").setup(opts)
  end,
  ["folke/which-key.nvim"] = function(opts)
    require("which-key").setup(opts)
  end,
  ["sphamba/smear-cursor.nvim"] = function(opts)
    require("smear_cursor").setup(opts)
  end,
}

local function setup_keys(spec)
  for _, mapping in ipairs(spec.keys or {}) do
    local lhs = mapping[1]
    local rhs = mapping[2]

    if not lhs or not rhs then
      goto continue
    end

    local opts = {
      desc = mapping.desc,
      expr = mapping.expr,
      silent = mapping.silent,
      noremap = mapping.noremap,
      nowait = mapping.nowait,
      remap = mapping.remap,
      buffer = mapping.buffer,
    }

    local mode = mapping.mode or "n"
    vim.keymap.set(mode, lhs, rhs, opts)

    ::continue::
  end
end

table.sort(ordered_specs, function(a, b)
  local a_priority = a.priority or 0
  local b_priority = b.priority or 0
  if a_priority == b_priority then
    return (a.__order or 0) < (b.__order or 0)
  end
  return a_priority > b_priority
end)

for _, spec in ipairs(ordered_specs) do
  if should_include(spec) then
    setup_keys(spec)

    local opts = spec.opts
    if type(opts) == "function" then
      opts = opts()
    end

    if spec.config then
      spec.config(spec, opts)
    elseif opts ~= nil then
      local setup = implicit_setups[spec[1]]
      if setup then
        setup(opts)
      end
    end
  end
end

require("custom.explorer").setup()
require("custom.statusline").setup()
require("custom.tabline").setup()
require("custom.lsp_keymapper").setup()
require("custom.autoclose").setup()
require("custom.scratch").setup({
  notes_dir = "~/Downloads/Notes",
  filename = "scratch.md",
  commit_message = "chore: update notes",
  float = {
    percent_width = 0.7,
    percent_height = 0.6,
  },
})

require("custom.glow").setup({
  style = "auto",
  width = 100,
})

local codelens = require("custom.codelens")
codelens.setup({})
-- require("custom.code_action_menu").setup()
require("custom.code_action").setup()

require("custom.cmdline").setup()

require("vim._core.ui2").enable({
  msg = { target = "cmd" },
})
