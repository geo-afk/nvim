-- =============================================================================
--  custom/float_term/term.lua  ·  Floating terminal helper  (Neovim 0.10+)
-- =============================================================================

local ok, floating = pcall(require, "custom.float_term.floating")
if not ok then
  error("[float_term] Could not load custom.float_term.floating: " .. tostring(floating))
end

local nvim_012 = vim.fn.has("nvim-0.12") == 1

local M = {}

-- ─── Default configuration ────────────────────────────────────────────────────

local config = {
  width_ratio = 0.7,
  height_ratio = 0.9,
  border = nil, -- nil = inherit vim.o.winborder (Neovim 0.12+)
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
--- The window only closes on explicit user action (q / <Esc> in normal mode).
--- @param cmd   string|string[]
--- @param opts  table?  { title = string, on_exit = function }
--- @return integer job_id, integer buf, integer win
function M.create_terminal(cmd, opts)
  opts = opts or {}
  local title = opts.title or (type(cmd) == "string" and cmd) or config.title

  local cols = vim.o.columns
  local rows = vim.o.lines - vim.o.cmdheight - 1

  local float_id, buf, win = floating.open({
    title = title,
    title_pos = config.title_pos,
    width = math.floor(cols * config.width_ratio),
    height = math.floor(rows * config.height_ratio),
    border = config.border,
    zindex = config.zindex,
    position = "center",
    modifiable = true,
    enter = true,
    style = "minimal",
    focusable = true,
    -- No on_close hook needed; closure is user-driven only.
  })

  if config.winblend > 0 then
    vim.wo[win].winblend = config.winblend
  end

  vim.wo[win].winhighlight = "Normal:FloatTermNormal,FloatBorder:FloatTermBorder,FloatTitle:FloatTermTitle"
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
        -- Terminal buffers cannot accept nvim_buf_set_lines; we feed the
        -- status line through the pty channel instead.
        vim.schedule(function()
          if not vim.api.nvim_buf_is_valid(buf) then
            return
          end

          -- Clear busy indicator
          pcall(function()
            vim.bo[buf].busy = nvim_012 and 0 or false
          end)

          -- Call user on_exit if provided
          if opts.on_exit then
            pcall(opts.on_exit, exit_code)
          end

          -- Only append the status when the window is still open.
          if not vim.api.nvim_win_is_valid(win) then
            return
          end

          local sep = string.rep("─", 60)
          local status = exit_code == 0 and "✓ Process completed successfully.  Press q or <Esc> to close"
            or string.format("✗ Process exited with code %d.  Press q or <Esc> to close", exit_code)

          -- Feed text into the terminal emulator so it renders correctly.
          local chan = vim.bo[buf].channel
          if chan and chan > 0 then
            pcall(vim.fn.chansend, chan, "\r\n" .. sep .. "\r\n" .. status .. "\r\n")
          end
        end)
      end,
    })
  end)

  -- Mark as busy (0.12: integer; earlier: boolean)
  pcall(function()
    vim.bo[buf].busy = nvim_012 and 1 or true
  end)

  -- Override floating.lua's generic close keymaps with terminal-aware ones.
  -- q in normal mode → close
  vim.keymap.set("n", "q", function()
    floating.close(float_id)
  end, { buffer = buf, nowait = true, silent = true, desc = "Close floating terminal" })

  -- <Esc>: normal mode → close; terminal mode → switch to normal mode
  vim.keymap.set({ "t", "n" }, "<Esc>", function()
    if vim.api.nvim_get_mode().mode == "n" then
      floating.close(float_id)
    else
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, true, true), "n", true)
    end
  end, { buffer = buf, nowait = true, silent = true, desc = "Exit terminal insert / close" })

  -- Let literal 'q' keystrokes through in terminal mode (e.g. typing "quit" in dlv)
  vim.keymap.set("t", "q", "q", { buffer = buf, noremap = true })

  -- Defer startinsert so it runs after the current event loop tick.
  -- This prevents mode-change side effects that could trigger spurious BufLeave.
  vim.schedule(function()
    if vim.api.nvim_win_is_valid(win) then
      vim.cmd("startinsert")
    end
  end)

  return job_id, buf, win
end

-- ─── Public: setup ───────────────────────────────────────────────────────────

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
