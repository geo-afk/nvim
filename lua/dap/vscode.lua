-- lua/dap/vscode.lua
-- Current nvim-dap reads .vscode/launch.json automatically via config
-- providers. This module only teaches that provider which Neovim filetypes
-- each VS Code adapter type belongs to.

local M = {}

function M.setup()
  local ok, vscode = pcall(require, "dap.ext.vscode")
  if not ok then return end

  vscode.type_to_filetypes = vim.tbl_deep_extend("force", vscode.type_to_filetypes or {}, {
    ["go"] = { "go" },
    ["node"] = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
    ["node2"] = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
    ["pwa-node"] = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
    ["node-terminal"] = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
    ["chrome"] = { "html", "javascript", "javascriptreact", "typescript", "typescriptreact" },
    ["pwa-chrome"] = { "html", "javascript", "javascriptreact", "typescript", "typescriptreact" },
    ["msedge"] = { "html", "javascript", "javascriptreact", "typescript", "typescriptreact" },
    ["pwa-msedge"] = { "html", "javascript", "javascriptreact", "typescript", "typescriptreact" },
  })
end

return M
