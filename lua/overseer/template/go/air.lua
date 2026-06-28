-- =============================================================================
-- lua/overseer/template/go/air.lua
-- air – live-reload for Go (https://github.com/cosmtrek/air)
-- Runs persistently; restartable from the task panel.
-- =============================================================================

return {
  name    = "go: air (live reload)",
  builder = function(params)
    local cwd = vim.fs.root(vim.fn.expand("%:p:h"), { "go.mod", "go.work", ".air.toml" })
           or vim.fn.getcwd()

    local cmd = { "air" }
    if params.config and params.config ~= "" then
      vim.list_extend(cmd, { "-c", params.config })
    end

    return {
      name = "air",
      cmd  = cmd,
      cwd  = cwd,
      -- Persistent: keep running, notify only on unexpected exit
      components = {
        "on_exit_set_status",
        { "on_complete_notify", system = "unfocused" },
        -- Auto-restart if air crashes unexpectedly
        { "on_complete_restart", statuses = { "FAILURE" } },
      },
      metadata = {
        tags            = { "go", "air", "live-reload" },
        restart_on_save = false,  -- air handles its own reload
      },
    }
  end,
  params = {
    config = {
      type        = "string",
      name        = "Config file",
      description = "Path to .air.toml (default: auto-detect)",
      optional    = true,
    },
  },
  priority = 40,
  tags     = { "go", "air" },
  condition = {
    filetype = { "go" },
    callback = function(_)
      return vim.fn.executable("air") == 1
    end,
  },
}
