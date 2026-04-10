-- =============================================================================
--  custom/image_view.lua  ·  Chafa-backed image preview for Neovim
--
--  Windows-friendly approach:
--    - uses Chafa in symbols mode instead of terminal-specific graphics
--    - renders inside a floating terminal so ANSI colors display correctly
--    - accepts an explicit path, current buffer path, or image path under cursor
-- =============================================================================

local M = {}

M.config = {
  width_ratio = 0.85,
  height_ratio = 0.85,
  border = "rounded",
  title = " Chafa Preview ",
  title_pos = "center",
  keymaps = {
    preview_current = "<leader>vi",
    preview_path = "<leader>vI",
  },
  chafa = {
    format = "symbols",
    colors = "full",
    color_space = "din99d",
    symbols = "block+border+space",
    work = "9",
    optimize = "9",
    animate = "off",
    probe = "off",
    margin_bottom = "0",
    margin_right = "0",
  },
}

local state = {
  win = nil,
  buf = nil,
}

local image_extensions = {
  png = true,
  jpg = true,
  jpeg = true,
  gif = true,
  bmp = true,
  webp = true,
  avif = true,
  tif = true,
  tiff = true,
  ico = true,
}

local function is_image(path)
  if type(path) ~= "string" or path == "" then
    return false
  end

  local ext = path:match("%.([^.]+)$")
  if not ext then
    return false
  end

  return image_extensions[ext:lower()] == true
end

local function close_float()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
  end
  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    vim.api.nvim_buf_delete(state.buf, { force = true })
  end

  state.win = nil
  state.buf = nil
end

local function chafa_path()
  local path = vim.fn.exepath("chafa")
  if path ~= nil and path ~= "" then
    return path
  end

  path = vim.fn.exepath("Chafa")
  if path ~= nil and path ~= "" then
    return path
  end

  return nil
end

local function notify_missing()
  vim.notify(table.concat({
    "Chafa is not installed or not on PATH.",
    "",
    "Install it on Windows with:",
    "  winget install hpjansson.chafa",
  }, "\n"), vim.log.levels.WARN, { title = "custom.image_view" })
end

local function file_exists(path)
  return vim.uv.fs_stat(path) ~= nil
end

local function normalize(path)
  return vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
end

local function path_under_cursor()
  local candidates = {
    vim.fn.expand("<cfile>"),
    vim.fn.expand("<cWORD>"),
  }

  for _, candidate in ipairs(candidates) do
    if candidate ~= nil and candidate ~= "" then
      local cleaned = candidate:gsub('^["' .. "'" .. "]", ""):gsub('["' .. "'" .. "]$", "")
      if cleaned ~= "" then
        local absolute = normalize(cleaned)
        if is_image(absolute) and file_exists(absolute) then
          return absolute
        end
      end
    end
  end

  return nil
end

local function resolve_target(path)
  if path and path ~= "" then
    local absolute = normalize(path)
    if file_exists(absolute) then
      return absolute
    end
    return nil, "File not found: " .. absolute
  end

  local current = vim.api.nvim_buf_get_name(0)
  if is_image(current) and file_exists(current) then
    return normalize(current)
  end

  local cursor_path = path_under_cursor()
  if cursor_path then
    return cursor_path
  end

  return nil, "No image file found. Pass a path or open an image file first."
end

local function create_window(title)
  close_float()

  local ui_w = vim.o.columns
  local ui_h = vim.o.lines - vim.o.cmdheight - 1

  local width = math.max(40, math.floor(ui_w * M.config.width_ratio))
  local height = math.max(12, math.floor(ui_h * M.config.height_ratio))
  local row = math.max(0, math.floor((ui_h - height) / 2))
  local col = math.max(0, math.floor((ui_w - width) / 2))

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    border = M.config.border,
    title = " " .. (title or M.config.title) .. " ",
    title_pos = M.config.title_pos,
    style = "minimal",
  })

  vim.wo[win].wrap = false
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"

  state.buf = buf
  state.win = win

  return buf, win
end

local function build_args(path, width, height)
  local cfg = M.config.chafa

  return {
    "--format=" .. cfg.format,
    "--colors=" .. cfg.colors,
    "--color-space=" .. cfg.color_space,
    "--symbols=" .. cfg.symbols,
    "--work=" .. cfg.work,
    "--optimize=" .. cfg.optimize,
    "--animate=" .. cfg.animate,
    "--probe=" .. cfg.probe,
    "--margin-bottom=" .. cfg.margin_bottom,
    "--margin-right=" .. cfg.margin_right,
    "--size=" .. width .. "x" .. height,
    path,
  }
end

function M.preview(path)
  local exe = chafa_path()
  if not exe then
    notify_missing()
    return
  end

  local target, err = resolve_target(path)
  if not target then
    vim.notify(err, vim.log.levels.WARN, { title = "custom.image_view" })
    return
  end

  local title = (" Chafa %s "):format(vim.fn.fnamemodify(target, ":t"))
  local buf, win = create_window(title)
  local width = math.max(20, vim.api.nvim_win_get_width(win) - 2)
  local height = math.max(8, vim.api.nvim_win_get_height(win) - 2)
  local cmd = vim.list_extend({ exe }, build_args(target, width, height))

  vim.fn.termopen(cmd, {
    on_exit = function()
      vim.schedule(function()
        if vim.api.nvim_buf_is_valid(buf) then
          vim.keymap.set("n", "q", close_float, {
            buffer = buf,
            silent = true,
            desc = "Close image preview",
          })
        end
      end)
    end,
  })

  vim.cmd("startinsert")

  local opts = { buffer = buf, silent = true }
  vim.keymap.set("n", "q", close_float, opts)
  vim.keymap.set("n", "<Esc>", close_float, opts)
  vim.keymap.set("t", "<Esc>", function()
    local keys = vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, true, true)
    vim.api.nvim_feedkeys(keys, "n", false)
  end, opts)
  vim.keymap.set("t", "q", "q", { buffer = buf, noremap = true })
end

function M.prompt_path()
  vim.ui.input({
    prompt = "Image path: ",
    default = vim.api.nvim_buf_get_name(0),
    completion = "file",
  }, function(input)
    if not input or input == "" then
      return
    end
    M.preview(input)
  end)
end

function M.setup(user_config)
  if user_config then
    M.config = vim.tbl_deep_extend("force", M.config, user_config)
  end

  vim.api.nvim_create_user_command("ChafaImage", function(opts)
    M.preview(opts.args ~= "" and opts.args or nil)
  end, {
    nargs = "?",
    complete = "file",
    desc = "Preview an image with Chafa in a floating terminal",
  })

  vim.api.nvim_create_user_command("ChafaImagePrompt", M.prompt_path, {
    desc = "Prompt for an image path and preview it with Chafa",
  })

  local km = M.config.keymaps
  if km.preview_current then
    vim.keymap.set("n", km.preview_current, function()
      M.preview()
    end, { silent = true, desc = "Preview image with Chafa" })
  end

  if km.preview_path then
    vim.keymap.set("n", km.preview_path, M.prompt_path, {
      silent = true,
      desc = "Preview image from path with Chafa",
    })
  end
end

return M
