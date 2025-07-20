local Popup = require("nui.popup")
local event = require("nui.utils.autocmd").event

local M = {}

local defaults = {
  default_port = 3000,
  popup = {
    border_style = "rounded",
    width = 60,
    position = "50%",
  },
}

local config = {}
local job_id = nil
local popup = nil
local server_port = nil
local server_url = nil
local browser_sync_checked = false
local notify_win = nil
local notify_buf = nil

-- Get directory of the currently open file or fall back to project root
local function get_project_root()
  local current_file = vim.fn.expand("%:p")
  if current_file and current_file ~= "" then
    return vim.fn.fnamemodify(current_file, ":h")
  end
  local git_root = vim.fn.systemlist("git rev-parse --show-toplevel")[1]
  if vim.v.shell_error == 0 and git_root then
    return git_root
  end
  return vim.fn.getcwd()
end

-- Async browser-sync check
local function check_browser_sync(callback)
  if browser_sync_checked then
    callback(true)
    return
  end

  local check_job = vim.fn.jobstart({ "npm", "list", "-g", "browser-sync" }, {
    on_exit = function(_, code)
      if code == 0 then
        browser_sync_checked = true
        callback(true)
      else
        vim.notify("⚠️ Installing browser-sync...", vim.log.levels.INFO)
        local install_job = vim.fn.jobstart({ "npm", "install", "-g", "browser-sync" }, {
          on_exit = function(_, install_code)
            if install_code == 0 then
              browser_sync_checked = true
              vim.notify("✅ browser-sync installed!", vim.log.levels.INFO)
              callback(true)
            else
              vim.notify("❌ Failed to install browser-sync.", vim.log.levels.ERROR)
              callback(false)
            end
          end,
        })
      end
    end,
  })
end

local function create_popup(content_lines)
  if popup then
    popup:unmount()
  end

  popup = Popup({
    enter = false,
    focusable = false,
    zindex = 50,
    border = {
      style = config.popup.border_style,
      text = {
        top = " Live Server ",
        top_align = "center",
      },
    },
    position = config.popup.position,
    size = {
      width = config.popup.width,
      height = #content_lines + 2,
    },
    win_options = {
      winhighlight = "Normal:Normal,FloatBorder:Normal",
    },
  })

  popup:mount()
  popup:on(event.BufLeave, function() end, { once = false })
  popup:map("n", "q", function()
    popup:unmount()
    popup = nil
  end, { noremap = true, silent = true })

  -- Set lines first, then make buffer non-modifiable
  vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, content_lines)
  vim.bo[popup.bufnr].buftype = "nofile"
  vim.bo[popup.bufnr].modifiable = false
end

local function update_popup(path, url)
  local lines = {
    "🚀 Live Server Running",
    "",
    "📂 " .. path,
    "🌐 " .. url,
    "",
    "🛑 Run :LiveServerStop to close server",
    "🔒 Press 'q' to close this window",
  }
  create_popup(lines)
end

local function show_persistent_notify(rel_path, port)
  if notify_win then
    vim.api.nvim_win_close(notify_win, true)
    notify_win = nil
    notify_buf = nil
  end

  notify_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[notify_buf].buftype = "nofile"

  local lines = {
    "🚀 Live Server starting...",
    "📂 " .. rel_path,
    "🌐 Port: " .. port,
  }
  vim.api.nvim_buf_set_lines(notify_buf, 0, -1, false, lines)
  vim.bo[notify_buf].modifiable = false

  local width = 0
  for _, line in ipairs(lines) do
    width = math.max(width, #line)
  end

  notify_win = vim.api.nvim_open_win(notify_buf, false, {
    relative = "editor",
    anchor = "NE",
    row = 1,
    col = vim.o.columns - 1,
    width = width + 2,
    height = #lines,
    style = "minimal",
    border = "single",
    zindex = 50,
  })

  vim.wo[notify_win].winblend = 0
  vim.wo[notify_win].winhighlight = "Normal:Normal,FloatBorder:Normal"
end

local function close_persistent_notify()
  if notify_win then
    vim.api.nvim_win_close(notify_win, true)
    notify_win = nil
    notify_buf = nil
  end
end

function M.statusline()
  if job_id and server_port then
    return string.format("%%#StatusLineLiveServer# Live:%d%%*", server_port)
  end
  return ""
end

local function start_server(port)
  local cwd = get_project_root()
  local rel_path = vim.fn.fnamemodify(cwd, ":~:.")

  show_persistent_notify(rel_path, port)

  check_browser_sync(function(success)
    if not success then
      close_persistent_notify()
      return
    end

    server_port = port

    job_id = vim.fn.jobstart({
      "browser-sync",
      "start",
      "--server",
      cwd,
      "--port",
      tostring(port),
      "--files",
      cwd .. "/**/*",
      "--no-open",
    }, {
      cwd = cwd,
      pty = true,
      on_stdout = function(_, data)
        for _, line in ipairs(data) do
          if line and line:match("Local:") then
            server_url = line:match("Local:%s+(http://[%w%p]+)")
            if server_url then
              vim.schedule(function()
                close_persistent_notify()
                update_popup(rel_path, server_url)
              end)
            end
          end
        end
      end,
      on_stderr = function(_, data)
        for _, line in ipairs(data) do
          if line and line ~= "" then
            vim.schedule(function()
              vim.notify("Live Server Error: " .. line, vim.log.levels.ERROR)
            end)
          end
        end
      end,
      on_exit = function()
        vim.schedule(function()
          vim.notify("🛑 Live Server stopped.", vim.log.levels.INFO)
          close_persistent_notify()
          if popup then
            popup:unmount()
            popup = nil
          end
          job_id = nil
          server_port = nil
          server_url = nil
        end)
      end,
    })

    if job_id <= 0 then
      vim.notify("❌ Failed to start Live Server.", vim.log.levels.ERROR)
      close_persistent_notify()
      return
    end
  end)
end

function M.setup(user_config)
  config = vim.tbl_deep_extend("force", defaults, user_config or {})

  vim.api.nvim_create_user_command("LiveServerStart", function(opts)
    if job_id then
      vim.notify("⚠️ Live Server is already running.", vim.log.levels.WARN)
      return
    end

    local port = tonumber(opts.args) or config.default_port
    start_server(port)
  end, { nargs = "?" })

  vim.api.nvim_create_user_command("LiveServerStop", function()
    if job_id then
      vim.fn.jobstop(job_id)
      close_persistent_notify()
      if popup then
        popup:unmount()
        popup = nil
      end
      vim.notify("🛑 Live Server stopped.", vim.log.levels.INFO)
    else
      vim.notify("⚠️ No Live Server running.", vim.log.levels.WARN)
    end
  end, {})

  vim.api.nvim_create_user_command("LiveServerRestart", function(opts)
    local port = tonumber(opts.args) or (server_port or config.default_port)
    if job_id then
      vim.fn.jobstop(job_id)
      close_persistent_notify()
      if popup then
        popup:unmount()
        popup = nil
      end
      vim.notify("♻️ Restarting Live Server...", vim.log.levels.INFO)
    end
    start_server(port)
  end, { nargs = "?" })

  vim.api.nvim_create_autocmd("VimLeavePre", {
    callback = function()
      if job_id then
        vim.fn.jobstop(job_id)
      end
      close_persistent_notify()
      if popup then
        popup:unmount()
        popup = nil
      end
    end,
  })

  vim.api.nvim_set_hl(0, "StatusLineLiveServer", { fg = "#50fa7b", bg = "#282828" })
  vim.o.statusline = vim.o.statusline .. "%{%v:lua.require('custom.live-server').statusline()%}"
end

return M
