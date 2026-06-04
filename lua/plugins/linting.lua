-- =============================================================================
--  plugins/linting.lua  ·  nvim-lint
-- =============================================================================

vim.pack.add({ { src = "https://github.com/mfussenegger/nvim-lint" } })

local ok, lint = pcall(require, "lint")
if not ok then
  return
end

local function normalize_range(diagnostic, line_count)
  diagnostic.lnum = math.max(0, tonumber(diagnostic.lnum) or 0)
  diagnostic.col = math.max(0, tonumber(diagnostic.col) or 0)

  if line_count and line_count > 0 then
    diagnostic.lnum = math.min(diagnostic.lnum, line_count - 1)
  end

  diagnostic.end_lnum = tonumber(diagnostic.end_lnum)
  diagnostic.end_col = tonumber(diagnostic.end_col)

  if not diagnostic.end_lnum or diagnostic.end_lnum < 0 then
    diagnostic.end_lnum = diagnostic.lnum
  end

  if not diagnostic.end_col or diagnostic.end_col < 0 then
    diagnostic.end_col = diagnostic.col
  end

  if line_count and line_count > 0 then
    diagnostic.end_lnum = math.min(diagnostic.end_lnum, line_count - 1)
  end

  if diagnostic.end_lnum < diagnostic.lnum then
    diagnostic.end_lnum = diagnostic.lnum
    diagnostic.end_col = diagnostic.col
  elseif diagnostic.end_lnum == diagnostic.lnum and diagnostic.end_col < diagnostic.col then
    diagnostic.end_col = diagnostic.col
  end

  return diagnostic
end

local function sanitize_diagnostics(diagnostics, bufnr)
  if type(diagnostics) ~= "table" then
    return {}
  end

  local line_count = vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_line_count(bufnr) or nil
  local sanitized = {}

  for _, diagnostic in ipairs(diagnostics) do
    if type(diagnostic) == "table" then
      sanitized[#sanitized + 1] = normalize_range(diagnostic, line_count)
    end
  end

  return sanitized
end

local function wrap_linter_parser(name)
  local linter = lint.linters[name]
  if not linter or linter._range_sanitized then
    return
  end

  local parser = linter.parser
  if type(parser) ~= "function" then
    return
  end

  linter.parser = function(output, bufnr, linter_cwd)
    return sanitize_diagnostics(parser(output, bufnr, linter_cwd), bufnr)
  end
  linter._range_sanitized = true
end

-- ── Linters by filetype ───────────────────────────────────────────────────────
lint.linters_by_ft = {
  sql = { "sqruff" },
  html = { "htmlhint" },
  typescript = { "biomejs" },
  javascript = { "biomejs" },
  python = { "ruff" },
  go = { "staticcheck" },
}

-- ── Custom linter args ────────────────────────────────────────────────────────
if lint.linters.sqruff then
  lint.linters.sqruff.args = {
    "--format",
    "json",
    "--config",
    vim.fs.joinpath(vim.fn.stdpath("config"), ".sqruff.toml"),
    "--stdin",
    "--stdin-filename",
    vim.fn.expand("%:p"),
  }
end

for _, linter_names in pairs(lint.linters_by_ft) do
  for _, name in ipairs(linter_names) do
    wrap_linter_parser(name)
  end
end

-- ── Debounce helper ───────────────────────────────────────────────────────────
local function debounce(ms, fn)
  local timer = vim.uv.new_timer()
  if not timer then
    return function(...)
      fn(...)
    end
  end
  return function(...)
    local args = { ... }
    timer:stop()
    timer:start(
      ms,
      0,
      vim.schedule_wrap(function()
        fn(unpack(args))
      end)
    )
  end
end

-- ── Lint runner ───────────────────────────────────────────────────────────────
local function run_lint()
  if not vim.bo.modifiable or vim.bo.buftype ~= "" then
    return
  end

  local ok2, err = pcall(lint.try_lint)
  if not ok2 then
    vim.notify("nvim-lint: " .. err, vim.log.levels.ERROR)
  end
end

-- ── Autocommands ─────────────────────────────────────────────────────────────
local augroup = vim.api.nvim_create_augroup("NvimLint", { clear = true })
vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
  group = augroup,
  callback = debounce(200, run_lint),
})
