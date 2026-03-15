-- Safely attempt to load the angular path helper
local ok, angular_paths = pcall(require, "utils.angular_location")

-- fallback if module is missing
if not ok then
  vim.notify(
    "[angularls] utils.angular_location not found. Falling back to default command.",
    vim.log.levels.WARN
  )

  angular_paths = {
    cmd = { "ngserver", "--stdio" }, -- fallback Angular language server command
  }
end

return {
  settings = {
    angularls = {
      experimental = {
        templateDiagnostics = true,
        templateCodeLens = true,
      },
      provideFormatter = true,
      strictTemplates = true,
      trace = {
        server = "messages",
      },
    },
  },

  cmd = angular_paths.cmd,

  root_markers = { "angular.json", "nx.json" },

  filetypes = { "html", "htmlangular", "typescript" },
}
