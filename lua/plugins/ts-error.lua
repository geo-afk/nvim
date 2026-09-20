vim.pack.add({ { src = "https://github.com/dmmulroy/ts-error-translator.nvim" } })
local ok, ts_error = pcall(require, "ts-error-translator")
if not ok then
  return
end

ts_error.setup({
  auto_attach = true,

  servers = {
    "typescript-tools",
    "vtsls",
  },
})
