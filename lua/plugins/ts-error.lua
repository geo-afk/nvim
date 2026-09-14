vim.pack.add({ { src = "https://github.com/dmmulroy/ts-error-translator.nvim" } })

vim.pack.add({ { src = "https://github.com/windwp/nvim-ts-autotag" } })

local ok, ts_error = pcall(require, "ts-error-translator")
if not ok then
  return
end

ts_error().setup({
  auto_attach = true,

  servers = {
    "typescript-tools",
    "vtsls",
  },
})
