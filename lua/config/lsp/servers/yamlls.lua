---@module "lspconfig"
---@type vim.lsp.Config
return {
  cmd = { "yaml-language-server", "--stdio" },
  filetypes = { "yaml", "yaml.docker-compose", "yaml.gitlab" },
  root_markers = { ".git" },
  ---@type lspconfig.settings.yamlls
  settings = {
    yaml = {
      yamlVersion = "1.2",
      validate = true,
      hover = true,
      completion = true,
      format = {
        enable = true,
        singleQuote = false,
        bracketSpacing = true,
        proseWrap = "preserve",
        printWidth = 80,
      },
      schemaStore = {
        enable = true,
        url = "https://www.schemastore.org/api/json/catalog.json",
      },
      kubernetesCRDStore = {
        enable = false,
      },
      schemas = {
        ["https://json.schemastore.org/github-workflow.json"] = "/.github/workflows/*.{yml,yaml}",
        ["https://json.schemastore.org/github-action.json"] = "/action.{yml,yaml}",
        ["https://json.schemastore.org/docker-compose.json"] = "docker-compose*.{yml,yaml}",
        ["https://raw.githubusercontent.com/compose-spec/compose-spec/master/schema/compose-spec.json"] = "compose*.{yml,yaml}",
      },
      disableSchemaDetection = false,
      maxItemsComputed = 5000,
      suggest = {
        parentSkeletonSelectedFirst = false,
      },
      style = {
        flowMapping = "allow",
        flowSequence = "allow",
      },
      keyOrdering = false,
      hoverSchemaSource = true,
    },
  },
}
