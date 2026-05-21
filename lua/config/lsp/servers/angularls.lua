local ok, angular_location = pcall(require, "utils.angular_location")
local ok_utils, utils = pcall(require, "utils")

if not ok then
  vim.notify("[angularls] utils.angular_location not found; using default cmd.", vim.log.levels.WARN)
end

-- Store resolved cmd; updated per-connection in before_init
local _base_cmd = { "ngserver", "--stdio" }

return {
  before_init = function(_, config)
    -- FIX #2: resolve cmd with root_dir here, not in cmd function
    if ok and type(angular_location.build_cmd) == "function" then
      local built = angular_location.build_cmd(config.root_dir)
      if type(built) == "table" and #built > 0 then
        _base_cmd = built
      end
    end
  end,

  cmd = function(dispatchers)
    return vim.lsp.rpc.start(_base_cmd, dispatchers)
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
    angular = { -- FIX #21: namespace should be 'angular'
      experimental = {
        templateDiagnostics = true,
        templateCodeLens = true,
      },
      provideFormatter = true,
      strictTemplates = true,
    },
  },
}
