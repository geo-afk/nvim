local M = {}

-- Configuration table for customizable options
local config = {
  width_ratio = 0.7,    -- Percentage of editor width
  height_ratio = 0.7,   -- Percentage of editor height
  border = "rounded",   -- Border style: "single", "double", "rounded", "shadow"
  title = "Terminal",   -- Title for the floating window
  title_pos = "center", -- Title position: "left", "center", "right"
  zindex = 50,          -- Window stacking order
}

-- Create a floating window with enhanced UI
function M.create_window()
  local max_height = vim.api.nvim_win_get_height(0)
  local max_width = vim.api.nvim_win_get_width(0)

  local height = math.floor(max_height * config.height_ratio)
  local width = math.floor(max_width * config.width_ratio)

  -- Calculate centered position
  local row = math.floor((max_height - height) / 2)
  local col = math.floor((max_width - width) / 2)

  -- Create buffer with better settings
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })

  -- Create window with enhanced options
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    height = height,
    width = width,
    row = row,
    col = col,
    border = config.border,
    title = config.title,
    title_pos = config.title_pos,
    zindex = config.zindex,
    style = "minimal",
    focusable = true,
  })

  -- Set window options for better UI
  vim.api.nvim_set_option_value("winhighlight", "Normal:NormalFloat,FloatBorder:FloatBorder", { win = win })
  vim.api.nvim_set_option_value("wrap", false, { win = win })
  vim.api.nvim_set_option_value("number", false, { win = win })
  vim.api.nvim_set_option_value("relativenumber", false, { win = win })
  vim.api.nvim_set_option_value("cursorline", false, { win = win })

  return buf, win
end

-- Create terminal in floating window
function M.create_terminal(cmd)
  local buf, win = M.create_window()

  -- Start terminal
  vim.api.nvim_buf_call(buf, function()
    vim.cmd.term(cmd or "nu")
    vim.cmd("startinsert")
  end)

  -- Set buffer-specific keymaps using modern API
  vim.keymap.set({ "n", "t" }, "<Esc>", "<C-\\><C-n>:q<CR>", { buffer = buf, noremap = true, silent = true })
  vim.keymap.set("n", "q", ":q<CR>", { buffer = buf, noremap = true, silent = true })
end

-- Setup function to allow user configuration
function M.setup(user_config)
  config = vim.tbl_deep_extend("force", config, user_config or {})
end

return M
