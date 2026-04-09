-- =============================================================================
--  plugins/linting.lua  ·  nvim-lint
-- =============================================================================

vim.pack.add({ { src = "https://github.com/mfussenegger/nvim-lint" } })

local ok, lint = pcall(require, "lint")
if not ok then
  return
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
