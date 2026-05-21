-- Safely attempt to load the angular path helper
local ok, angular_location = pcall(require, "utils.angular_location")
local ok_utils, utils = pcall(require, "utils")

-- fallback if module is missing
if not ok then
  vim.notify("[angularls] utils.angular_location not found. Falling back to default command.", vim.log.levels.WARN)
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

  cmd = function(dispatchers, config)
    local cmd = { "ngserver", "--stdio" }
    if ok and type(angular_location.build_cmd) == "function" then
      cmd = angular_location.build_cmd(config.root_dir)
    end
    return vim.lsp.rpc.start(cmd, dispatchers)
  end,

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
