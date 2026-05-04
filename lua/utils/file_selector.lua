-- lua/utils/file_selector.lua
-- Async-friendly file picker: prefers Telescope, falls back to a native
-- floating window.  The native fallback uses uv.fs_scandir for non-blocking
-- directory traversal instead of the synchronous vim.fn.globpath.

local M = {}

M.config = {
  width_ratio = 0.35,
  height_ratio = 0.35,
  border = "rounded",
}

-- ─── Highlights ──────────────────────────────────────────────────────────────

local function setup_highlights()
  local highlights = {
    FilePickerBorder = { link = "FloatBorder" },
    FilePickerTitle = { link = "FloatTitle" },
    FilePickerNormal = { link = "NormalFloat" },
    FilePickerSelected = { fg = "#88C0D0", bg = "#3B4252", bold = true },
    FilePickerDirectory = { fg = "#81A1C1" },
    FilePickerFile = { fg = "#D8DEE9" },
    FilePickerPrompt = { fg = "#A3BE8C", bold = true },
    FilePickerLineNr = { fg = "#616E88" },
  }
  for group, opts in pairs(highlights) do
    vim.api.nvim_set_hl(0, group, opts)
  end
end

setup_highlights()

-- ─── Telescope check ─────────────────────────────────────────────────────────

local function telescope_available()
  return pcall(require, "telescope")
end

-- ─── Async file scan (uv) ────────────────────────────────────────────────────

--- Recursively collect all files under `root` without blocking the main loop.
---@param root     string
---@param callback fun(files: string[])
local function scan_files_async(root, callback)
  local files = {}
  local pending = 0

  local function on_done()
    pending = pending - 1
    if pending == 0 then
      table.sort(files)
      vim.schedule(function()
        callback(files)
      end)
    end
  end

  local function scan_dir(dir)
    pending = pending + 1
    vim.uv.fs_scandir(dir, function(err, handle)
      if err or not handle then
        on_done()
        return
      end
      -- Collect all entries first so we can dispatch child scans.
      local entries = {}
      while true do
        local name, ftype = vim.uv.fs_scandir_next(handle)
        if not name then
          break
        end
        table.insert(entries, { name = name, ftype = ftype })
      end

      if #entries == 0 then
        on_done()
        return
      end

      -- We need an extra "ticket" per entry that needs type resolution.
      local child_pending = #entries
      local function child_done()
        child_pending = child_pending - 1
        if child_pending == 0 then
          on_done()
        end
      end

      for _, entry in ipairs(entries) do
        local full = dir .. "/" .. entry.name
        local ftype = entry.ftype

        if ftype == "unknown" then
          -- Resolve symlinks / unknown types via stat
          pending = pending + 1
          vim.uv.fs_stat(full, function(_, stat)
            if stat then
              if stat.type == "directory" then
                scan_dir(full)
              elseif stat.type == "file" then
                table.insert(files, full)
              end
            end
            pending = pending - 1 -- for the stat ticket
            child_done()
          end)
        elseif ftype == "directory" then
          -- Skip hidden directories
          if not entry.name:match("^%.") then
            scan_dir(full)
          end
          child_done()
        elseif ftype == "file" then
          table.insert(files, full)
          child_done()
        else
          child_done()
        end
      end
    end)
  end

  pending = 0
  scan_dir(root)

  -- Guard: if root itself couldn't be opened pending stays 0
  if pending == 0 then
    vim.schedule(function()
      callback({})
    end)
  end
end

-- ─── Native floating window picker ───────────────────────────────────────────

local function create_file_picker(files, opts, callback)
  if #files == 0 then
    vim.notify("No files found", vim.log.levels.WARN)
    callback(nil)
    return
  end

  local ui = vim.api.nvim_list_uis()[1]
  local width = math.floor(ui.width * M.config.width_ratio)
  local height = math.floor(ui.height * M.config.height_ratio)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "filepicker"

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    col = math.floor((ui.width - width) / 2),
    row = math.floor((ui.height - height) / 2),
    style = "minimal",
    border = M.config.border,
    title = " " .. (opts.prompt_title or "Select File") .. " ",
    title_pos = "center",
  })

  vim.wo[win].winhighlight = table.concat({
    "Normal:FilePickerNormal",
    "FloatBorder:FilePickerBorder",
    "FloatTitle:FilePickerTitle",
    "CursorLine:FilePickerSelected",
    "LineNr:FilePickerLineNr",
  }, ",")
  vim.wo[win].cursorline = true
  vim.wo[win].number = true
  vim.wo[win].relativenumber = false

  -- Build display lines (relative paths)
  local display = {}
  for _, file in ipairs(files) do
    display[#display + 1] = vim.fn.fnamemodify(file, ":~:.")
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, display)
  vim.bo[buf].modifiable = false

  -- Syntax highlighting
  local ns = vim.api.nvim_create_namespace("filepicker")
  for i, file in ipairs(files) do
    local hl = vim.fn.isdirectory(file) == 1 and "FilePickerDirectory" or "FilePickerFile"
    vim.api.nvim_buf_add_highlight(buf, ns, hl, i - 1, 0, -1)
  end

  local function close_win()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  local function select_item()
    local line = vim.api.nvim_win_get_cursor(win)[1]
    local selected = files[line]
    close_win()
    if selected then
      callback(vim.fn.fnamemodify(selected, ":p"))
    else
      callback(nil)
    end
  end

  local keymaps = {
    ["<CR>"] = select_item,
    ["<Esc>"] = close_win,
    ["q"] = close_win,
    ["<C-c>"] = close_win,
  }
  for key, fn in pairs(keymaps) do
    vim.keymap.set("n", key, fn, { buffer = buf, nowait = true, noremap = true, silent = true })
  end

  -- Non-focusable style: close on blur
  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = buf,
    once = true,
    callback = close_win,
  })
end

-- ─── Public API ──────────────────────────────────────────────────────────────

---Select a file and return its path via callback.
---@param opts     table|nil  { prompt_title, cwd, width_ratio, height_ratio }
---@param callback fun(path: string|nil)
function M.select_file(opts, callback)
  opts = opts or {}

  local width_ratio = opts.width_ratio or M.config.width_ratio
  local height_ratio = opts.height_ratio or M.config.height_ratio

  -- ── Telescope path ───────────────────────────────────────────────────────
  if telescope_available() then
    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local conf = require("telescope.config").values
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")

    local telescope_opts = vim.tbl_deep_extend("force", opts, {
      layout_strategy = "center",
      layout_config = { width = width_ratio, height = height_ratio },
    })

    pickers
      .new(telescope_opts, {
        prompt_title = opts.prompt_title or "Select File",
        finder = finders.new_oneshot_job({ "fd", "--type", "f" }, { cwd = opts.cwd }),
        sorter = conf.generic_sorter(telescope_opts),
        attach_mappings = function(prompt_bufnr, map)
          local function select()
            local sel = action_state.get_selected_entry()
            actions.close(prompt_bufnr)
            if sel and (sel.path or sel.value or sel[1]) then
              local path = vim.fn.fnamemodify(sel.path or sel.value or sel[1], ":p")
              callback(path)
            else
              callback(nil)
            end
          end
          map("i", "<CR>", select)
          map("n", "<CR>", select)
          return true
        end,
      })
      :find()
    return
  end

  -- ── Native async fallback ────────────────────────────────────────────────
  local cwd = opts.cwd or vim.fn.getcwd()

  -- Stash config overrides for the duration of this call.
  local orig_w, orig_h = M.config.width_ratio, M.config.height_ratio
  M.config.width_ratio = width_ratio
  M.config.height_ratio = height_ratio

  scan_files_async(cwd, function(files)
    M.config.width_ratio = orig_w
    M.config.height_ratio = orig_h

    if #files == 0 then
      vim.notify("No files found in " .. cwd, vim.log.levels.WARN)
      callback(nil)
      return
    end

    create_file_picker(files, opts, callback)
  end)
end

---Configure global defaults.
---@param user_config table?
function M.setup(user_config)
  M.config = vim.tbl_deep_extend("force", M.config, user_config or {})
  setup_highlights()
end

return M
