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
vim.opt.sessionoptions:remove("terminal")

local function wipe_session_transient_buffers()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    local name = vim.api.nvim_buf_get_name(bufnr)
    local buftype = vim.api.nvim_get_option_value("buftype", { buf = bufnr })

    if buftype == "terminal" or name:match("^term://") then
      pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
    end
  end
end

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

  pre_save_cmds = {
    wipe_session_transient_buffers,
  },
})
