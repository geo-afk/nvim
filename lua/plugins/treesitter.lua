-- =============================================================================
-- plugins/treesitter.lua · nvim-treesitter
-- =============================================================================

local parsers = {
  "lua",
  "typescript",
  "tsx",
  "javascript",
  "go",
  "gomod",
  "gowork",
  "gotmpl",
  "json",
  -- "jsonc",
  "html",
  "css",
  "scss",
  "markdown",
  "markdown_inline",
  "regex",
  "vim",
  "vimdoc",
  "query",
  "toml",
  "sql",
  "bash",
  "dotenv",
  "angular",
}

local ft_to_lang = {
  javascriptreact = "tsx",
  typescriptreact = "tsx",
  dotenv = "bash",
}

local handled_filetypes = {
  angular = true,
  bash = true,
  css = true,
  dotenv = true,
  go = true,
  gomod = true,
  gowork = true,
  gotmpl = true,
  html = true,
  javascript = true,
  javascriptreact = true,
  json = true,
  -- jsonc = true,
  lua = true,
  markdown = true,
  query = true,
  regex = true,
  scss = true,
  sh = true,
  sql = true,
  toml = true,
  typescript = true,
  typescriptreact = true,
  vim = true,
}

local ok_utils, utils = pcall(require, "utils")
utils = ok_utils and utils or {}

local function get_buf_path(bufnr)
  return vim.api.nvim_buf_get_name(bufnr)
end

local function should_use_angular(bufnr)
  local path = get_buf_path(bufnr)
  if path == "" then
    return false
  end

  if type(utils.should_use_angular_parser) ~= "function" then
    return false
  end

  local ok, result = pcall(utils.should_use_angular_parser, path)
  return ok and result or false
end

local function resolve_lang(bufnr, ft)
  if ft == "html" and should_use_angular(bufnr) then
    return "angular"
  end

  return ft_to_lang[ft] or ft
end

local function has_query(lang, query_name)
  local ok, query = pcall(vim.treesitter.query.get, lang, query_name)
  return ok and query ~= nil
end

local function start_treesitter(bufnr, lang)
  if not lang or lang == "" then
    return
  end

  local ok_parser = pcall(vim.treesitter.get_parser, bufnr, lang)
  if not ok_parser then
    return
  end

  pcall(vim.treesitter.start, bufnr, lang)

  if has_query(lang, "highlights") then
    vim.bo[bufnr].syntax = "off"
  end

  if has_query(lang, "indents") then
    vim.bo[bufnr].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
  end
end

vim.pack.add({
  {
    src = "https://github.com/nvim-treesitter/nvim-treesitter",
    version = "main",
  },
})

local ok_ts, ts = pcall(require, "nvim-treesitter")
if not ok_ts then
  return
end

ts.setup({
  install_dir = vim.fs.joinpath(vim.fn.stdpath("data"), "site"),
})

local group = vim.api.nvim_create_augroup("nvim_treesitter_setup", { clear = true })

local function handle_buffer(bufnr)
  local ft = vim.bo[bufnr].filetype
  if not handled_filetypes[ft] then
    return
  end

  local lang = resolve_lang(bufnr, ft)
  start_treesitter(bufnr, lang)
end

vim.api.nvim_create_autocmd("FileType", {
  group = group,
  pattern = {
    "angular",
    "bash",
    "css",
    "dotenv",
    "go",
    "gomod",
    "gowork",
    "gotmpl",
    "html",
    "javascript",
    "javascriptreact",
    "json",
    "jsonc",
    "lua",
    "markdown",
    "query",
    "regex",
    "scss",
    "sh",
    "sql",
    "toml",
    "typescript",
    "typescriptreact",
    "vim",
  },
  callback = function(ev)
    handle_buffer(ev.buf)
  end,
})

vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
  group = group,
  pattern = { "*.component.html", "*.html" },
  callback = function(ev)
    handle_buffer(ev.buf)
  end,
  desc = "Apply Angular Treesitter parser or fallback",
})

-- If this module was loaded by the loader's FileType trigger, the current
-- buffer's FileType event has already fired before the autocmd above exists.
-- Apply once immediately so the first buffer opened from the explorer is not
-- missed.
if vim.api.nvim_get_current_buf() ~= 0 then
  handle_buffer(vim.api.nvim_get_current_buf())
end
