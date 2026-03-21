local M = {
  _state = {
    last_floating_window = nil,
  },
  _config = {
    notes_dir = "~/Notes",
    filename = "todo.md",
    commit_message = "Some notes..",
    float = {
      percent_width = 0.8,
      percent_height = 0.8,
      border = { "┏", "━", "┓", "┃", "┛", "━", "┗", "┃" },
    },
  },
}

-- Merge user config with defaults
function M.setup(opts)
  M._config = vim.tbl_deep_extend("force", M._config, opts or {})
  vim.api.nvim_create_user_command("ScratchOpenSplit", M.open_scratch_file, {})
  vim.api.nvim_create_user_command("ScratchOpenFloat", M.open_scratch_file_floating, {})
end

function M.get_scratch_filename()
  return M._config.notes_dir .. "/" .. M._config.filename
end

local function ensure_notes_dir()
  vim.fn.mkdir(vim.fn.expand(M._config.notes_dir), "p")
end

function M.open_scratch_file()
  ensure_notes_dir()
  vim.api.nvim_command("vsplit " .. M.get_scratch_filename())
end

function M.open_scratch_file_floating(opts)
  -- Toggle: close if already open
  if M._state.last_floating_window ~= nil then
    if vim.api.nvim_win_is_valid(M._state.last_floating_window) then
      vim.api.nvim_win_close(M._state.last_floating_window, false)
    end
    M._state.last_floating_window = nil
    return
  end

  opts = vim.tbl_deep_extend("force", M._config.float, opts or {})

  local ui = vim.api.nvim_list_uis()[1]
  local width = math.floor(ui.width * opts.percent_width)
  local height = math.floor(ui.height * opts.percent_height)

  local win_opts = {
    relative = "editor",
    width = width,
    height = height,
    col = math.floor((ui.width - width) / 2),
    row = math.floor((ui.height - height) / 2),
    anchor = "NW",
    style = "minimal",
    border = opts.border,
  }

  local winnr = vim.api.nvim_open_win(0, true, win_opts)
  M._state.last_floating_window = winnr

  ensure_notes_dir()
  vim.api.nvim_command("edit " .. M.get_scratch_filename())

  local bufnr = vim.api.nvim_get_current_buf()

  local function close_window()
    ensure_notes_dir()
    vim.api.nvim_command("silent w")
    local wins = vim.api.nvim_list_wins()
    if #wins > 1 and vim.api.nvim_win_is_valid(winnr) then
      vim.api.nvim_win_close(winnr, true)
    end
    M._state.last_floating_window = nil
  end

  -- q / <ESC>: save and close
  for _, key in ipairs({ "q", "<ESC>" }) do
    vim.keymap.set("n", key, close_window, { buffer = bufnr, silent = true })
  end

  -- nc: notes commit (pull → save → stage → commit → push → close)
  vim.keymap.set("n", "nc", function()
    vim.api.nvim_command("Git pull")
    vim.api.nvim_command("silent w")
    vim.api.nvim_command("Gwrite")
    vim.api.nvim_command("Git commit -m '" .. M._config.commit_message .. "'")
    vim.api.nvim_command("Git push")
    close_window()
  end, { buffer = bufnr, silent = true })

  -- np: notes pull
  vim.keymap.set("n", "np", function()
    vim.api.nvim_command("Git pull")
  end, { buffer = bufnr, silent = true })
end

-- Register commands immediately for backwards compatibility,
-- but setup() allows overriding config before they're used.
vim.api.nvim_create_user_command("ScratchOpenSplit", M.open_scratch_file, {})
vim.api.nvim_create_user_command("ScratchOpenFloat", M.open_scratch_file_floating, {})

return M
