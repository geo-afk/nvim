-- =============================================================================
--  plugins/auto-session.lua  ·  Automated session manager
-- =============================================================================

vim.pack.add({ { src = "https://github.com/rmagatti/auto-session" } })

local ok, auto_session = pcall(require, "auto-session")
if not ok then
  return
end

-- Recommended sessionoptions
vim.opt.sessionoptions:append("winpos")

auto_session.setup({
  enabled = true,
  auto_save = true,
  auto_restore = true,
  auto_create = true,
  suppressed_dirs = { "~/", "~/Projects", "~/Downloads", "/" },

  -- Use telescope/snacks for session picking
  session_lens = {
    load_on_setup = true,
    theme_conf = { border = "rounded" },
    -- previewer = false,
  },
})
