-- debugger_hover.lua — floating eval window on K
local M = {}

local hover_win = nil

local function close()
  if hover_win and vim.api.nvim_win_is_valid(hover_win) then
    vim.api.nvim_win_close(hover_win, true)
  end
  hover_win = nil
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
    local result = tostring(resp.body.result or "")
    local typ = tostring(resp.body.type or "")

    -- build lines
    local lines = {}
    local header = " " .. expr .. " "
    table.insert(lines, header)
    local val_line = "  = " .. result
    if #val_line > 58 then
      val_line = val_line:sub(1, 56) .. "…"
    end
    table.insert(lines, val_line)
    if typ ~= "" then
      table.insert(lines, "  : " .. typ)
    end

    local width = 0
    for _, l in ipairs(lines) do
      width = math.max(width, #l + 2)
    end
    width = math.min(width, 60)

    local b = vim.api.nvim_create_buf(false, true)
    vim.bo[b].bufhidden = "wipe"
    vim.bo[b].modifiable = true
    vim.api.nvim_buf_set_lines(b, 0, -1, false, lines)
    vim.bo[b].modifiable = false
    hover_buf = b

    -- highlights
    local ns = vim.api.nvim_create_namespace("go_dbg_hover")
    vim.api.nvim_buf_set_extmark(b, ns, 0, 0, {
      end_col = #header,
      hl_group = "Title",
    })
    if #lines >= 2 then
      vim.api.nvim_buf_set_extmark(b, ns, 1, 0, {
        end_col = #lines[2],
        hl_group = "Number",
      })
    end
    if #lines >= 3 then
      vim.api.nvim_buf_set_extmark(b, ns, 2, 0, {
        end_col = #lines[3],
        hl_group = "Comment",
      })
    end

    hover_win = vim.api.nvim_open_win(b, false, {
      relative = "cursor",
      row = 1,
      col = 0,
      width = width,
      height = #lines,
      style = "minimal",
      border = "rounded",
      focusable = false,
      zindex = 50,
    })
    vim.wo[hover_win].winhl = "Normal:NormalFloat,FloatBorder:FloatBorder"

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
