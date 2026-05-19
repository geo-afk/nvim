-- lua/dap/signs.lua
-- Breakpoint signs, highlight groups, and statusline helper.

local M = {}

function M.setup()
  -- ── Signs ──────────────────────────────────────────────────────────────
  local signs = {
    DapBreakpoint          = { text = "●", hl = "DapBreakpoint" },
    DapBreakpointCondition = { text = "◆", hl = "DapBreakpointCondition" },
    DapBreakpointRejected  = { text = "○", hl = "DapBreakpointRejected" },
    DapLogPoint            = { text = "◎", hl = "DapLogPoint" },
    DapStopped             = { text = "→", hl = "DapStopped", linehl = "DapStoppedLine" },
  }

  for name, s in pairs(signs) do
    vim.fn.sign_define(name, {
      text    = s.text,
      texthl  = s.hl,
      linehl  = s.linehl or "",
      numhl   = "",
    })
  end

  -- ── Highlight groups (override per colourscheme in after/plugin/) ──────
  local hls = {
    DapBreakpoint          = { fg = "#e06c75" },
    DapBreakpointCondition = { fg = "#e5c07b" },
    DapBreakpointRejected  = { fg = "#5c6370", italic = true },
    DapLogPoint            = { fg = "#61afef" },
    DapStopped             = { fg = "#98c379", bold = true },
    DapStoppedLine         = { bg = "#2c3043" },
    -- nvim-dap-virtual-text
    NvimDapVirtualText        = { fg = "#7e8a9a", italic = true },
    NvimDapVirtualTextChanged = { fg = "#e5c07b", italic = true },
    NvimDapVirtualTextError   = { fg = "#e06c75", italic = true },
    NvimDapVirtualTextInfo    = { fg = "#61afef", italic = true },
  }

  for name, hl in pairs(hls) do
    -- Don't overwrite if the colourscheme already defines it
    local existing = vim.api.nvim_get_hl(0, { name = name })
    if vim.tbl_isempty(existing) then
      vim.api.nvim_set_hl(0, name, hl)
    end
  end
end

-- ── Statusline / winbar component ────────────────────────────────────────
-- Returns a short string showing the active DAP session name, or "".
-- Use in lualine:  { require("dap.signs").status }
function M.status()
  local ok, dap = pcall(require, "dap")
  if not ok then return "" end
  local session = dap.session()
  if not session then return "" end
  return "  " .. (session.config.name or "debugging")
end

return M
