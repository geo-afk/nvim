local M = {}

-- Floating window for ng serve/ng test output
local function create_floating_window()
  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.4)
  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) * 0.5),
    col = math.floor((vim.o.columns - width) * 0.5),
    style = "minimal",
    border = "rounded",
  })
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  return buf, win
end

-- Toggleable preview window
local preview_buf = nil
local preview_win = nil
local job_id = nil

local function toggle_preview(command)
  if preview_win and vim.api.nvim_win_is_valid(preview_win) then
    vim.api.nvim_win_close(preview_win, true)
    preview_buf = nil
    preview_win = nil
    if job_id then
      vim.fn.jobstop(job_id)
      job_id = nil
    end
    return
  end

  preview_buf, preview_win = create_floating_window()
  vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, { "Running " .. command .. "..." })

  local function append_data(_, data)
    if data then
      vim.api.nvim_buf_set_lines(preview_buf, -1, -1, false, data)
      local line_count = vim.api.nvim_buf_line_count(preview_buf)
      vim.api.nvim_win_set_cursor(preview_win, { line_count, 0 })
    end
  end

  job_id = vim.fn.jobstart(command, {
    on_stdout = append_data,
    on_stderr = append_data,
    stdout_buffered = true,
    stderr_buffered = true,
  })

  if job_id <= 0 then
    vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, { "Failed to start " .. command })
    job_id = nil
  end
end

-- Keybindings
table.insert(M, {
  "folke/which-key.nvim",
  opts = {
    spec = {
      { "<leader>a", group = "+Angular" },
    },
  },
})

table.insert(M, {
  "nvim-lua/plenary.nvim",
  config = function()
    vim.keymap.set("n", "<leader>as", function()
      toggle_preview("ng serve")
    end, { desc = "Toggle ng serve preview" })
    vim.keymap.set("n", "<leader>at", function()
      toggle_preview("ng test")
    end, { desc = "Toggle ng test preview" })
  end,
})

return M
