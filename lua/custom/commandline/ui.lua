local UI = {}
local M = {} -- Config reference
local State = require('custom.commandline.state')
local Animation = require('custom.commandline.animation').Animation
local Utils = require('custom.commandline.utils')

local function setup_ui(config)
  M.config = config
end

function UI:setup_highlights()
  local t = M.config.theme
  -- Use set_hl for global highlights (best practice)
  vim.api.nvim_set_hl(0, "CmdlineNormal", { bg = t.bg, fg = t.fg })
  vim.api.nvim_set_hl(0, "CmdlineBorder", { fg = t.border })
  -- Make prompt blend with normal bg for seamless look, like VS Code
  vim.api.nvim_set_hl(0, "CmdlinePrompt", { bg = t.bg, fg = t.prompt_fg, bold = true })
  vim.api.nvim_set_hl(0, "CmdlineCursor", { bg = t.cursor_bg, fg = t.bg })
  vim.api.nvim_set_hl(0, "CmdlineHint", { fg = t.hint_fg, italic = true })
  -- Lighter selection bg for subtle highlight, similar to VS Code's gray bar
  vim.api.nvim_set_hl(0, "CmdlineSelection", { bg = t.bg_alt, fg = t.fg, bold = true })
  vim.api.nvim_set_hl(0, "CmdlineHeader", { bg = t.header_bg, fg = t.header_fg, bold = true })
  vim.api.nvim_set_hl(0, "CmdlineKind", { fg = t.kind_fg })
  -- Fainter desc for subtlety
  vim.api.nvim_set_hl(0, "CmdlineDesc", { fg = t.hint_fg })
  vim.api.nvim_set_hl(0, "CmdlineSeparator", { fg = t.separator_fg })
  vim.api.nvim_set_hl(0, "CmdlineAccent", { fg = t.accent_fg, bold = true })
  vim.api.nvim_set_hl(0, "CmdlineMore", { fg = t.hint_fg, italic = true })
end

function UI:create_window()
  self:setup_highlights()
  local width = math.floor(vim.o.columns * M.config.window.width)
  width = Utils.clamp(width, M.config.window.min_width, M.config.window.max_width)
  local height = 1
  local row, col
  if M.config.window.position == "center" then
    row = math.floor((vim.o.lines - height) / 2)
    col = math.floor((vim.o.columns - width) / 2)
  elseif M.config.window.position == "top" then
    row = 2
    col = math.floor((vim.o.columns - width) / 2)
  else
    row = vim.o.lines - vim.o.cmdheight - 5
    col = math.floor((vim.o.columns - width) / 2)
  end
  -- Create buffer (best practice: nofile, bufhidden=wipe, noswapfile)
  State.buf = vim.api.nvim_create_buf(false, true)
  vim.bo[State.buf].buftype = "nofile"
  vim.bo[State.buf].bufhidden = "wipe"
  vim.bo[State.buf].swapfile = false
  vim.bo[State.buf].modifiable = false -- Start read-only, toggle when updating
  -- Open floating window (modern config with title_pos)
  State.win = vim.api.nvim_open_win(State.buf, true, {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = height,
    style = "minimal",
    border = M.config.window.border,
    zindex = M.config.window.zindex,
    title = " Command Palette ",
    title_pos = "center",
  })
  -- Window options (use nvim_win_set_option for safety)
  vim.api.nvim_win_set_option(State.win, "winblend", 100)
  vim.api.nvim_win_set_option(State.win, "winhighlight", "Normal:CmdlineNormal,FloatBorder:CmdlineBorder")
  vim.api.nvim_win_set_option(State.win, "cursorline", false)
  vim.api.nvim_win_set_option(State.win, "wrap", false)
  vim.api.nvim_win_set_option(State.win, "scrolloff", 0)
  -- Animate in with slide-down then fade, mimicking VS Code entrance
  Animation:slide_in(State.win, "down", function()
    Animation:fade_in(State.win)
  end)
  return true
end

function UI:resize_window(height)
  if not State.win or not vim.api.nvim_win_is_valid(State.win) then
    return
  end
  local config = vim.api.nvim_win_get_config(State.win)
  local new_height = Utils.clamp(height, 1, M.config.window.max_height)
  if M.config.window.position == "center" then
    config.row = math.floor((vim.o.lines - new_height) / 2)
  elseif M.config.window.position == "bottom" then
    config.row = vim.o.lines - vim.o.cmdheight - new_height - 3
  end
  config.height = new_height
  pcall(vim.api.nvim_win_set_config, State.win, config)
end

-- Helper to truncate and pad line to width
local function prepare_line(text, width)
  if #text > width then
    text = text:sub(1, width - 3) .. "..."
  else
    text = text .. string.rep(" ", width - #text)
  end
  return text
end

function UI:update_display()
  if not State.buf or not vim.api.nvim_buf_is_valid(State.buf) then
    return
  end
  local lines = {}
  local highlights = {}
  local win_width = vim.api.nvim_win_get_width(State.win)
  -- Prompt line
  local icon = M.config.icons.cmd
  if State.mode == "/" then
    icon = M.config.icons.search
  elseif State.mode == "=" then
    icon = M.config.icons.lua
  end
  local prompt = " " .. icon .. " "
  local text = State.text
  local hint = ""
  if text == "" and M.config.features.inline_hints then
    hint = "Type a command or press Tab for suggestions..."
  end
  local prompt_content = prompt .. (text ~= "" and text or hint)
  local prompt_line = prepare_line(prompt_content, win_width)
  table.insert(lines, prompt_line)
  -- Full line for prompt with seamless bg
  table.insert(highlights, {
    line = 0,
    col = 0,
    end_col = win_width,
    hl = "CmdlinePrompt",
  })
  -- Hint highlight
  if text == "" and hint ~= "" then
    table.insert(highlights, {
      line = 0,
      col = #prompt,
      end_col = math.min(#prompt + #hint, win_width),
      hl = "CmdlineHint",
    })
  end
  -- NO separator for seamless integration like VS Code
  -- Completions rendering starts immediately
  local item_idx = 0
  for _, item in ipairs(State.grouped_completions) do
    if item.is_header then
      local header = string.format(" %s %s (%d)", M.config.icons.header, item.text, item.count)
      local header_line = prepare_line(header, win_width)
      table.insert(lines, header_line)
      table.insert(highlights, {
        line = #lines - 1,
        col = 0,
        end_col = win_width,
        hl = "CmdlineHeader",
      })
    elseif item.is_more then
      local more = string.format(" %s %d more items...", M.config.icons.more, item.count)
      local more_line = prepare_line(more, win_width)
      table.insert(lines, more_line)
      table.insert(highlights, {
        line = #lines - 1,
        col = 0,
        end_col = math.min(#more_line, win_width),
        hl = "CmdlineMore",
      })
    else
      item_idx = item_idx + 1
      local is_selected = item_idx == State.comp_index
      local icon = is_selected and M.config.icons.selected or M.config.icons.item
      local kind = item.kind and string.format(" %s", item.kind) or "" -- Simplified, no brackets for cleaner look
      local desc = item.desc and string.format(" — %s", item.desc) or ""
      -- More padding for modern spacing, like VS Code list items
      local line_content = string.format(" %s %s%s%s", icon, item.text, kind, desc)
      local line = prepare_line(line_content, win_width)
      table.insert(lines, line)
      if is_selected then
        table.insert(highlights, {
          line = #lines - 1,
          col = 0,
          end_col = win_width,
          hl = "CmdlineSelection",
        })
      end
      -- Adjust hl positions with extra padding
      local icon_len = #icon + 1 -- Space after icon
      local text_end = icon_len + #item.text
      if kind ~= "" then
        local kind_start = text_end + 1 -- Space before kind
        table.insert(highlights, {
          line = #lines - 1,
          col = kind_start,
          end_col = math.min(kind_start + #kind, win_width),
          hl = "CmdlineKind",
        })
      end
      if desc ~= "" then
        local desc_start = text_end + #kind + 2 -- Spaces and em dash
        table.insert(highlights, {
          line = #lines - 1,
          col = desc_start,
          end_col = win_width, -- Extend to end for fade effect
          hl = "CmdlineDesc",
        })
      end
    end
  end
  -- Update buffer (toggle modifiable for safety)
  vim.bo[State.buf].modifiable = true
  vim.api.nvim_buf_set_lines(State.buf, 0, -1, false, lines)
  vim.bo[State.buf].modifiable = false
  -- Clear and set extmarks for highlights (modern API)
  vim.api.nvim_buf_clear_namespace(State.buf, State.ns_id, 0, -1)
  for _, hl in ipairs(highlights) do
    pcall(vim.api.nvim_buf_set_extmark, State.buf, State.ns_id, hl.line, hl.col, {
      end_col = hl.end_col,
      hl_group = hl.hl,
    })
  end
  self:resize_window(#lines)
  self:update_cursor(#prompt)
end

function UI:update_cursor(offset)
  if not State.win or not vim.api.nvim_win_is_valid(State.win) then
    return
  end
  local col = offset + State.cursor_pos - 1
  pcall(vim.api.nvim_win_set_cursor, State.win, { 1, col })
end

function UI:cleanup()
  Utils.safe_win_close(State.win)
  State.win = nil
  Utils.safe_buf_delete(State.buf)
  State.buf = nil
end

return { UI = UI, setup = setup_ui }
