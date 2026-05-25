local ok, angular_location = pcall(require, "utils.angular_location")
local ok_utils, utils = pcall(require, "utils")

if not ok then
  vim.notify("[angularls] utils.angular_location not found; using default cmd.", vim.log.levels.WARN)
end

return {
  cmd = function(dispatchers)
    local cmd = { "ngserver", "--stdio" }
    if ok and type(angular_location.build_cmd) == "function" then
      local bufname = vim.api.nvim_buf_get_name(0)
      local root = ok_utils and utils.find_angular_root(bufname) or vim.fn.getcwd()
      cmd = angular_location.build_cmd(root)
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

  settings = {
    angular = {
      experimental = {
        templateDiagnostics = true,
        templateCodeLens = true,
      },
      provideFormatter = true,
      strictTemplates = true,
    },
  },
}
