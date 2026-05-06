-- debugger_hover.lua — floating eval window on K
local M = {}

local S = {
  win = nil,
  buf = nil,
}

local function setup_hl()
  local function def(name, opts)
    opts.default = true
    vim.api.nvim_set_hl(0, name, opts)
  end
  def("GoDbgHoverTitle", { link = "Title", bold = true })
  def("GoDbgHoverLabel", { link = "Comment", italic = true })
  def("GoDbgHoverVal", { link = "String" })
  def("GoDbgHoverType", { link = "Keyword", italic = true })
end

local function close()
  if S.win and vim.api.nvim_win_is_valid(S.win) then
    vim.api.nvim_win_close(S.win, true)
  end
  S.win = nil
  S.buf = nil
end

function M.eval(session, frame_id, expr)
  close()
  if not session or session.closed then
    return
  end
  expr = vim.trim(expr or vim.fn.expand("<cword>"))
  if expr == "" then
    return
  end

  session:request("evaluate", {
    expression = expr,
    context = "hover",
    frameId = frame_id,
  }, function(resp)
    if not resp.success or not resp.body then
      return
    end

    setup_hl()
    local result = tostring(resp.body.result or "")
    local typ = tostring(resp.body.type or "")

    -- build lines
    local lines = {
      " 󱄑 Name  " .. expr,
      " 󰅨 Type  " .. (typ ~= "" and typ or "unknown"),
      " 󰇘 Value " .. result,
    }

    local width = 0
    for _, l in ipairs(lines) do
      width = math.max(width, vim.fn.strdisplaywidth(l) + 4)
    end
    width = math.min(width, 80)

    local b = require("custom.ui.buffer").create_raw(false, true)
    vim.bo[b].bufhidden = "wipe"
    vim.api.nvim_buf_set_lines(b, 0, -1, false, lines)
    vim.bo[b].modifiable = false
    S.buf = b

    -- highlights
    local ns = vim.api.nvim_create_namespace("go_dbg_hover")
    for i = 0, #lines - 1 do
      require("custom.ui.render").set_extmark(b, ns, i, 0, { end_col = 8, hl_group = "GoDbgHoverLabel" })
    end
    -- specific field highlights
    require("custom.ui.render").set_extmark(b, ns, 0, 8, { hl_group = "GoDbgHoverTitle" })
    require("custom.ui.render").set_extmark(b, ns, 1, 8, { hl_group = "GoDbgHoverType" })
    require("custom.ui.render").set_extmark(b, ns, 2, 8, { hl_group = "GoDbgHoverVal" })

    S.win = require("custom.ui.window").open_raw(b, false, {
      relative = "cursor",
      row = 1,
      col = 0,
      width = width,
      height = #lines,
      style = "minimal",
      border = "rounded",
      title = " Inspect ",
      title_pos = "center",
      focusable = false,
      zindex = 50,
    })

    vim.wo[S.win].winhl = "Normal:NormalFloat,FloatBorder:DiagnosticInfo"

    vim.api.nvim_create_autocmd(
      { "CursorMoved", "CursorMovedI", "InsertEnter", "BufLeave" },
      { once = true, callback = close }
    )
  end)
end

function M.close()
  close()
end

return M
