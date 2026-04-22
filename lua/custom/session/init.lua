local nvim_utils = require("utils.nvim")

local api = vim.api
local fn = vim.fn
local uv = vim.uv

local M = {}

local defaults = {
  enabled = true,
  auto_restore = true,
  auto_save = true,
  notify = false,
  session_dir = vim.fs.joinpath(vim.fn.stdpath("state"), "session"),
  session_file = "last.vim",
  meta_file = "last.json",
  sessionoptions = {
    "blank",
    "buffers",
    "curdir",
    "folds",
    "help",
    "tabpages",
    "winsize",
    "terminal",
    "localoptions",
    "skiprtp",
  },
}

local state = {
  config = nil,
  restoring = false,
  restored = false,
  saved_this_exit = false,
}

local function normalize(path)
  return vim.fs.normalize(path or "")
end

local function paths()
  local dir = normalize(state.config.session_dir)
  return {
    dir = dir,
    session = normalize(vim.fs.joinpath(dir, state.config.session_file)),
    meta = normalize(vim.fs.joinpath(dir, state.config.meta_file)),
  }
end

local function ensure_dir(dir)
  if fn.isdirectory(dir) == 1 then
    return true
  end
  return pcall(fn.mkdir, dir, "p")
end

local function atomic_write(path, content)
  local tmp = path .. ".tmp"
  local fd, open_err = io.open(tmp, "wb")
  if not fd then
    return false, open_err
  end
  local ok, write_err = fd:write(content)
  fd:close()
  if not ok then
    os.remove(tmp)
    return false, write_err
  end
  local renamed, rename_err = os.rename(tmp, path)
  if not renamed then
    os.remove(path)
    renamed, rename_err = os.rename(tmp, path)
  end
  if not renamed then
    os.remove(tmp)
    return false, rename_err
  end
  return true
end

local function read_json(path)
  if fn.filereadable(path) ~= 1 then
    return nil
  end
  local fd = io.open(path, "rb")
  if not fd then
    return nil
  end
  local raw = fd:read("*a")
  fd:close()
  if not raw or raw == "" then
    return nil
  end
  local ok, decoded = pcall(vim.json.decode, raw)
  if not ok or type(decoded) ~= "table" then
    return nil
  end
  return decoded
end

local function write_json(path, value)
  local ok, encoded = pcall(vim.json.encode, value)
  if not ok then
    return false, encoded
  end
  return atomic_write(path, encoded)
end

local function ui_attached()
  return #api.nvim_list_uis() > 0
end

local function is_clean_start_buffer(buf)
  if not (buf and api.nvim_buf_is_valid(buf)) then
    return false
  end
  if vim.bo[buf].modified or vim.bo[buf].buftype ~= "" then
    return false
  end
  return api.nvim_buf_get_name(buf) == ""
end

local function should_auto_restore()
  if not state.config.enabled or not state.config.auto_restore then
    return false
  end
  if state.restored or state.restoring or vim.g.SessionLoad == 1 then
    return false
  end
  if not ui_attached() or fn.argc() > 0 then
    return false
  end
  local session_path = paths().session
  if fn.filereadable(session_path) ~= 1 then
    return false
  end
  local wins = api.nvim_list_wins()
  if #wins ~= 1 then
    return false
  end
  return is_clean_start_buffer(api.nvim_get_current_buf())
end

local function collect_tabline_order()
  local ok, buffers = pcall(require, "custom.tabline.buffers")
  if not ok then
    return {}
  end
  local order = {}
  for _, bufnr in ipairs(buffers.get_buffers()) do
    if api.nvim_buf_is_valid(bufnr) then
      local name = normalize(api.nvim_buf_get_name(bufnr))
      if name ~= "" then
        order[#order + 1] = name
      end
    end
  end
  return order
end

local function collect_known_files()
  local files = {}
  local seen = {}
  for _, bufnr in ipairs(api.nvim_list_bufs()) do
    if api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buftype == "" then
      local name = normalize(api.nvim_buf_get_name(bufnr))
      if name ~= "" and not seen[name] then
        seen[name] = true
        files[#files + 1] = name
      end
    end
  end
  table.sort(files)
  return files
end

local function wipe_buffer(bufnr)
  if api.nvim_buf_is_valid(bufnr) then
    pcall(api.nvim_buf_delete, bufnr, { force = false })
  end
end

local function cleanup_after_restore(meta)
  local current = api.nvim_get_current_buf()
  local known = {}
  if meta and type(meta.files) == "table" then
    for _, path in ipairs(meta.files) do
      if type(path) == "string" and path ~= "" then
        known[normalize(path)] = true
      end
    end
  end

  for _, bufnr in ipairs(api.nvim_list_bufs()) do
    if api.nvim_buf_is_valid(bufnr) and bufnr ~= current then
      local name = normalize(api.nvim_buf_get_name(bufnr))
      if name == "" and vim.bo[bufnr].buftype == "" and not vim.bo[bufnr].modified then
        wipe_buffer(bufnr)
      elseif name ~= "" and known[name] and vim.bo[bufnr].buftype == "" and not vim.bo[bufnr].modified then
        local stat = uv.fs_stat(name)
        if not stat then
          wipe_buffer(bufnr)
        end
      end
    end
  end

  local ok, buffers = pcall(require, "custom.tabline.buffers")
  if ok and meta and type(meta.tabline_order) == "table" and buffers.restore_order then
    pcall(buffers.restore_order, meta.tabline_order)
  end

  if api.nvim_get_current_buf() == 0 or not api.nvim_buf_is_valid(api.nvim_get_current_buf()) then
    vim.cmd("enew")
  end

  vim.schedule(function()
    pcall(vim.cmd, "redrawtabline")
    pcall(vim.cmd, "redraw!")
  end)
end

local function notify(msg, level)
  if state.config.notify then
    vim.notify(msg, level or vim.log.levels.INFO)
  end
end

function M.get_paths()
  return vim.deepcopy(paths())
end

function M.save(opts)
  opts = opts or {}
  if not state.config.enabled or state.restoring or vim.g.SessionLoad == 1 then
    return false
  end

  local p = paths()
  if not ensure_dir(p.dir) then
    notify("[session] failed to create session directory", vim.log.levels.WARN)
    return false
  end

  local ok, err = pcall(vim.cmd, "silent! mksession! " .. fn.fnameescape(p.session))
  if not ok then
    notify("[session] save failed: " .. tostring(err), vim.log.levels.WARN)
    return false
  end

  local meta_ok, meta_err = write_json(p.meta, {
    version = 1,
    cwd = normalize(fn.getcwd()),
    saved_at = os.time(),
    tabline_order = collect_tabline_order(),
    files = collect_known_files(),
  })
  if not meta_ok then
    notify("[session] metadata save failed: " .. tostring(meta_err), vim.log.levels.WARN)
  end

  if not opts.silent then
    notify("[session] saved")
  end
  return true
end

function M.restore(opts)
  opts = opts or {}
  local p = paths()
  if fn.filereadable(p.session) ~= 1 then
    return false
  end

  state.restoring = true
  local meta = read_json(p.meta)
  local ok, err = pcall(vim.cmd, "silent! source " .. fn.fnameescape(p.session))
  cleanup_after_restore(meta)
  state.restoring = false
  state.restored = ok

  if not ok then
    notify("[session] restore failed: " .. tostring(err), vim.log.levels.WARN)
    return false
  end

  if not opts.silent then
    notify("[session] restored")
  end
  return true
end

function M.delete()
  local p = paths()
  local ok = true
  if fn.filereadable(p.session) == 1 then
    ok = (os.remove(p.session) ~= nil) and ok
  end
  if fn.filereadable(p.meta) == 1 then
    ok = (os.remove(p.meta) ~= nil) and ok
  end
  return ok
end

function M.restart()
  if not M.save({ silent = true }) then
    return false
  end
  local session_file = paths().session
  local ok, err = pcall(vim.cmd, "restart source " .. fn.fnameescape(session_file))
  if not ok then
    notify("[session] restart failed: " .. tostring(err), vim.log.levels.ERROR)
    return false
  end
  return true
end

function M.setup(opts)
  state.config = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
  vim.opt.sessionoptions = table.concat(state.config.sessionoptions, ",")

  local group = nvim_utils.augroup("CustomSession")

  nvim_utils.command("SessionSave", function()
    M.save()
  end, { desc = "Save the current Neovim session", force = true })

  nvim_utils.command("SessionRestore", function()
    M.restore()
  end, { desc = "Restore the last saved Neovim session", force = true })

  nvim_utils.command("SessionDelete", function()
    M.delete()
  end, { desc = "Delete the last saved Neovim session", force = true })

  nvim_utils.command("SessionRestart", function()
    M.restart()
  end, { desc = "Restart Neovim and restore the last saved session", force = true })

  nvim_utils.autocmd("SessionLoadPre", {
    group = group,
    callback = function()
      state.restoring = true
    end,
  })

  nvim_utils.autocmd("SessionLoadPost", {
    group = group,
    callback = function()
      state.restoring = false
      state.restored = true
      cleanup_after_restore(read_json(paths().meta))
    end,
  })

  if state.config.auto_save then
    local save_on_exit = function()
      if state.saved_this_exit or not ui_attached() then
        return
      end
      state.saved_this_exit = true
      M.save({ silent = true })
    end

    nvim_utils.autocmd({ "VimLeavePre", "UILeave" }, {
      group = group,
      callback = save_on_exit,
    })
  end

  if state.config.auto_restore then
    nvim_utils.autocmd("VimEnter", {
      group = group,
      once = true,
      nested = true,
      callback = function()
        if should_auto_restore() then
          M.restore({ silent = true })
        end
      end,
    })
  end
end

return M
