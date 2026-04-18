-- =============================================================================
--  lua/plugins/init.lua  ·  Plugin loader
--
--  Each file in this directory is self-contained:
--    1. Declares its plugin(s) via vim.pack.add()
--    2. Runs its own setup() with pcall guards
--
--  Order matters: icons → colorscheme → which-key → treesitter
--              → mason → lsp → completion → snippets → …
-- =============================================================================

local function load(mod)
  local ok, err = pcall(require, mod)
  if not ok then
    vim.notify("plugins: failed to load " .. mod .. "\n" .. err, vim.log.levels.ERROR)
  end
end

-- Build hooks (must be registered before vim.pack.add)
vim.api.nvim_create_autocmd("PackChanged", {
  group = vim.api.nvim_create_augroup("pack_changed", { clear = true }),
  callback = function(ev)
    if ev.data.kind == "delete" then
      return
    end
    local name = ev.data.spec.name
    if name == "nvim-treesitter" then
      pcall(function()
        vim.cmd("TSUpdate")
      end)
    elseif name == "mason.nvim" then
      pcall(function()
        vim.cmd("MasonUpdate")
      end)
    end
  end,
})

-- ── Core / UI foundation ─────────────────────────────────────────────────────
-- These must load immediately for visual consistency.
load("plugins.icons") -- nvim-web-devicons
load("plugins.colorscheme") -- tokyonight

-- ── Deferred Loading ─────────────────────────────────────────────────────────
-- Everything else is scheduled to load after the initial UI loop to speed up
-- the first frame and reduce startup blocking.
vim.schedule(function()
  -- Keybinding helper
  load("plugins.which-key")

  -- Syntax / parsing
  load("plugins.treesitter")
  load("plugins.rainbow")
  load("plugins.ts-autotag")

  -- LSP toolchain
  load("plugins.mason")
  load("plugins.lsp")
  load("plugins.lazydev")
  load("plugins.completion")
  load("plugins.snippets")

  -- Formatting / linting
  load("plugins.formatting")
  load("plugins.linting")

  -- Diagnostics / navigation
  load("plugins.trouble")
  load("plugins.telescope")
  load("plugins.flash")

  -- Git
  load("plugins.gitsigns")

  -- Eye candy
  load("plugins.smear")
  load("plugins.color-highlight")

  -- Dev tools
  load("plugins.dev-server")

  -- Activate built-in 0.12 optional plugins
  for _, pkg in ipairs({ "nvim.undotree", "nvim.difftool", "nvim.tohtml" }) do
    ---@diagnostic disable-next-line: param-type-mismatch
    pcall(vim.cmd, "packadd " .. pkg)
  end
end)
