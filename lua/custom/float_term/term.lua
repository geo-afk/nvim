-- =============================================================================
--  custom/float_term/term.lua  ·  Floating terminal helper  (Neovim 0.12+)
--
--  Public API: M.setup(opts)  and  M.create_terminal(cmd, opts)
--  Window management is delegated to custom.float_term.floating.
-- =============================================================================

local ok, floating = pcall(require, "custom.float_term.floating")
if not ok then
  error("[float_term] Could not load custom.float_term.floating: " .. tostring(floating))
end

-- 0.12: detect version once
local nvim_012 = vim.fn.has("nvim-0.12") == 1

local M = {}

-- ─── Default configuration ────────────────────────────────────────────────────

local config = {
  width_ratio = 0.7,
  height_ratio = 0.9,
  -- border = nil  →  inherits vim.o.winborder (0.12 global default)
  -- set to e.g. "rounded" to override per-window
  border = nil,
  title = "Terminal",
  title_pos = "center",
  zindex = 50,
  transparent = false,
  winblend = 0,
}

-- ─── Highlight groups ────────────────────────────────────────────────────────

local function apply_highlights()
  vim.api.nvim_set_hl(0, "FloatTermTitle", {
    bg = "#7aa2f7",
    fg = "#1a1b26",
    bold = true,
  })
  vim.api.nvim_set_hl(0, "FloatTermBorder", { fg = "#7aa2f7" })
  vim.api.nvim_set_hl(0, "FloatTermNormal", {
    bg = config.transparent and "NONE" or "#16161e",
  })
end

apply_highlights()

-- ─── Shell helpers ───────────────────────────────────────────────────────────

local function get_shell_cmd(cmd)
  if type(cmd) == "table" then
    return cmd
  end
  local is_windows = vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1
  if is_windows then
    if vim.fn.executable("pwsh") == 1 then
      return { "pwsh", "-NoLogo", "-NoProfile", "-Command", cmd }
    elseif vim.fn.executable("powershell") == 1 then
      return { "powershell", "-NoLogo", "-NoProfile", "-Command", cmd }
    else
      return { "cmd", "/c", cmd }
    end
  end
  local shell = vim.o.shell
  return { (shell ~= "" and shell or "sh"), "-c", cmd }
end

-- ─── Public: create_terminal ─────────────────────────────────────────────────

--- Open a floating terminal that runs `cmd`.
--- @param cmd  string|string[]  command to execute
--- @param opts table?           optional { title = string }
--- @return integer job_id, integer buf, integer win
function M.create_terminal(cmd, opts)
  opts = opts or {}
  local title = opts.title or (type(cmd) == "string" and cmd) or config.title

  local cols = vim.o.columns
  local rows = vim.o.lines - vim.o.cmdheight - 1

  -- 0.12: pass border = nil to inherit vim.o.winborder unless overridden
  local float_id, buf, win = floating.open({
    title = title,
    title_pos = config.title_pos,
    width = math.floor(cols * config.width_ratio),
    height = math.floor(rows * config.height_ratio),
    border = config.border, -- nil = global winborder (0.12)
    zindex = config.zindex,
    position = "center",
    modifiable = true,
    enter = true,
    style = "minimal",
    focusable = true,
  })

  -- Transparency
  if config.winblend > 0 then
    vim.wo[win].winblend = config.winblend
  end

  -- Custom highlight groups
  vim.wo[win].winhighlight = table.concat({
    "Normal:FloatTermNormal",
    "FloatBorder:FloatTermBorder",
    "FloatTitle:FloatTermTitle",
  }, ",")

  vim.wo[win].wrap = false
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].cursorline = false
  vim.wo[win].signcolumn = "no"

  local shell_cmd = get_shell_cmd(cmd)

  local job_id = vim.api.nvim_buf_call(buf, function()
    return vim.fn.jobstart(shell_cmd, {
      term = true,
      on_exit = function(_, exit_code)
        -- 0.12: busy is a number (0 = idle)
        if vim.api.nvim_buf_is_valid(buf) then
          pcall(function()
            vim.bo[buf].busy = 0
          end)
        end

        if not vim.api.nvim_buf_is_valid(buf) then
          return
        end
        vim.bo[buf].modifiable = true
        local msg = exit_code == 0 and "✓ Process completed successfully. Press q or <Esc> to close"
          or string.format("✗ Process exited with code %d. Press q or <Esc> to close", exit_code)
        vim.api.nvim_buf_set_lines(buf, -1, -1, false, {
          "",
          string.rep("─", 80),
          msg,
        })
        vim.bo[buf].modifiable = false
      end,
    })
  end)

  -- 0.12: busy = 1 (number) lights up the statusline ◐ indicator
  -- wrapped in pcall so older Neovim versions don't crash
  pcall(function()
    vim.bo[buf].busy = nvim_012 and 1 or true
  end)

  vim.cmd("startinsert")

  -- Key-maps (override floating.lua's generic q/<Esc> for terminal behaviour)
  vim.keymap.set("n", "q", function()
    floating.close(float_id)
  end, { buffer = buf, nowait = true, silent = true, desc = "Close floating terminal" })

  vim.keymap.set({ "t", "n" }, "<Esc>", function()
    if vim.api.nvim_get_mode().mode == "n" then
      floating.close(float_id)
    else
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, true, true), "n", true)
    end
  end, { buffer = buf, nowait = true, silent = true, desc = "Exit terminal insert / close window" })

  vim.keymap.set("t", "q", "q", { buffer = buf, noremap = true })

  return job_id, buf, win
end

-- ─── Public: setup ───────────────────────────────────────────────────────────

--- Configure the floating terminal.  Call once from your plugin/init file.
---
--- 0.12 note: leave `border` unset (or nil) to inherit `vim.o.winborder`.
--- @param user_config table?
function M.setup(user_config)
  config = vim.tbl_deep_extend("force", config, user_config or {})
  apply_highlights()

  if user_config and user_config.colors then
    local c = user_config.colors
    if c.title_bg then
      vim.api.nvim_set_hl(0, "FloatTermTitle", {
        bg = c.title_bg,
        fg = c.title_fg or "#1a1b26",
        bold = true,
      })
    end
    if c.border then
      vim.api.nvim_set_hl(0, "FloatTermBorder", { fg = c.border })
    end
    if c.background and not config.transparent then
      vim.api.nvim_set_hl(0, "FloatTermNormal", { bg = c.background })
    end
  end
end

return M
