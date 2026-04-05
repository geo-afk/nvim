-- Safely attempt to load the angular path helper
local ok, angular_paths = pcall(require, "utils.angular_location")
local ok_utils, utils = pcall(require, "utils")

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

  root_dir = function(bufnr, on_dir)
    if not ok_utils or not utils.find_angular_root then
      return
    end

    local bufname = vim.api.nvim_buf_get_name(bufnr)
    local root = utils.find_angular_root(bufname)
    if root then
      on_dir(root)
    end
  end,

  single_file_support = false,

  filetypes = { "html", "htmlangular", "typescript" },
}
