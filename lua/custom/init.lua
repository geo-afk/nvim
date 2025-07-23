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
  auto_install = true,
  open_browser = false,
  file_patterns = { "**/*.html", "**/*.css", "**/*.js", "**/*.json" },
}

-- State management
local state = {
  config = {},
  job_id = nil,
  popup = nil,
  server_port = nil,
  server_url = nil,
  browser_sync_available = nil, -- nil = unchecked, true/false = checked
  notify_win = nil,
  notify_buf = nil,
  project_root = nil,
}

-- Utility functions
local function log_error(msg)
  vim.schedule(function()
    vim.notify("Live Server: " .. msg, vim.log.levels.ERROR)
  end)
end

local function log_info(msg)
  vim.schedule(function()
    vim.notify(msg, vim.log.levels.INFO)
  end)
end

local function log_warn(msg)
  vim.schedule(function()
    vim.notify(msg, vim.log.levels.WARN)
  end)
end

-- Get project root with better error handling and caching
local function get_project_root()
  if state.project_root then
    return state.project_root
  end

  -- Try current file directory first
  local current_file = vim.fn.expand("%:p")
  if current_file and current_file ~= "" and vim.fn.filereadable(current_file) == 1 then
    local dir = vim.fn.fnamemodify(current_file, ":h")
    if vim.fn.isdirectory(dir) == 1 then
      state.project_root = dir
      return dir
    end
  end

  -- Try git root
  local git_cmd = vim.fn.systemlist("git rev-parse --show-toplevel 2>/dev/null")
  if vim.v.shell_error == 0 and git_cmd[1] and vim.fn.isdirectory(git_cmd[1]) == 1 then
    state.project_root = git_cmd[1]
    return git_cmd[1]
  end

  -- Fall back to current working directory
  local cwd = vim.fn.getcwd()
  state.project_root = cwd
  return cwd
end

-- Enhanced browser-sync check with better error handling
local function check_browser_sync(callback)
  if state.browser_sync_available ~= nil then
    callback(state.browser_sync_available)
    return
  end

  -- Check if browser-sync is available
  local check_job = vim.fn.jobstart({ "which", "browser-sync" }, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_exit = function(_, code)
      if code == 0 then
        state.browser_sync_available = true
        callback(true)
        return
      end

      -- Try npm list check as fallback
      local npm_check = vim.fn.jobstart({ "npm", "list", "-g", "browser-sync" }, {
        stdout_buffered = true,
        stderr_buffered = true,
        on_exit = function(_, npm_code)
          if npm_code == 0 then
            state.browser_sync_available = true
            callback(true)
            return
          end

          if not state.config.auto_install then
            state.browser_sync_available = false
            log_error("browser-sync not found. Install with: npm install -g browser-sync")
            callback(false)
            return
          end

          log_info("⚠️ Installing browser-sync globally...")
          local install_job = vim.fn.jobstart({ "npm", "install", "-g", "browser-sync" }, {
            stdout_buffered = true,
            stderr_buffered = true,
            on_exit = function(_, install_code)
              if install_code == 0 then
                state.browser_sync_available = true
                log_info("✅ browser-sync installed successfully!")
                callback(true)
              else
                state.browser_sync_available = false
                log_error("Failed to install browser-sync. Please install manually.")
                callback(false)
              end
            end,
          })

          if install_job <= 0 then
            state.browser_sync_available = false
            log_error("Failed to start browser-sync installation")
            callback(false)
          end
        end,
      })

      if npm_check <= 0 then
        state.browser_sync_available = false
        log_error("Failed to check for browser-sync")
        callback(false)
      end
    end,
  })

  if check_job <= 0 then
    state.browser_sync_available = false
    log_error("Failed to check for browser-sync")
    callback(false)
  end
end

-- Improved popup creation with better error handling
local function create_popup(content_lines)
  if not content_lines or #content_lines == 0 then
    return
  end

  -- Clean up existing popup
  if state.popup then
    pcall(function()
      state.popup:unmount()
    end)
    state.popup = nil
  end

  local success, popup = pcall(function()
    return Popup({
      enter = false,
      focusable = false,
      zindex = 50,
      border = {
        style = state.config.popup.border_style,
        text = {
          top = " Live Server ",
          top_align = "center",
        },
      },
      position = state.config.popup.position,
      size = {
        width = state.config.popup.width,
        height = math.max(#content_lines + 2, 5),
      },
      win_options = {
        winhighlight = "Normal:Normal,FloatBorder:Normal",
      },
    })
  end)

  if not success then
    log_error("Failed to create popup")
    return
  end

  state.popup = popup

  local mount_success = pcall(function()
    popup:mount()
  end)

  if not mount_success then
    log_error("Failed to mount popup")
    state.popup = nil
    return
  end

  -- Set up event handlers
  popup:on(event.BufLeave, function() end, { once = false })
  popup:map("n", "q", function()
    pcall(function()
      popup:unmount()
    end)
    state.popup = nil
  end, { noremap = true, silent = true })

  -- Set buffer content safely
  pcall(function()
    vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, content_lines)
    vim.bo[popup.bufnr].buftype = "nofile"
    vim.bo[popup.bufnr].modifiable = false
    vim.bo[popup.bufnr].swapfile = false
  end)
end

local function update_popup(path, url)
  local lines = {
    "🚀 Live Server Running",
    "",
    "📂 " .. (path or "Unknown path"),
    "🌐 " .. (url or "Unknown URL"),
    "",
    "🛑 Run :LiveServerStop to close server",
    "🔒 Press 'q' to close this window",
  }
  create_popup(lines)
end

-- Improved notification system
local function show_persistent_notify(rel_path, port)
  -- Clean up existing notification
  if state.notify_win and vim.api.nvim_win_is_valid(state.notify_win) then
    pcall(function()
      vim.api.nvim_win_close(state.notify_win, true)
    end)
  end
  state.notify_win = nil
  state.notify_buf = nil

  local success, buf = pcall(vim.api.nvim_create_buf, false, true)
  if not success then
    return
  end

  state.notify_buf = buf
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].swapfile = false

  local lines = {
    "🚀 Live Server starting...",
    "📂 " .. (rel_path or "Unknown path"),
    "🌐 Port: " .. tostring(port),
  }

  pcall(function()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
  end)

  local width = 0
  for _, line in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(line))
  end

  local win_success, win = pcall(vim.api.nvim_open_win, buf, false, {
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

  if win_success then
    state.notify_win = win
    pcall(function()
      vim.wo[win].winblend = 0
      vim.wo[win].winhighlight = "Normal:Normal,FloatBorder:Normal"
    end)
  end
end

local function close_persistent_notify()
  if state.notify_win and vim.api.nvim_win_is_valid(state.notify_win) then
    pcall(function()
      vim.api.nvim_win_close(state.notify_win, true)
    end)
  end
  state.notify_win = nil
  state.notify_buf = nil
end

-- Enhanced statusline function
function M.statusline()
  if state.job_id and state.server_port then
    return string.format("%%#StatusLineLiveServer# Live:%d%%*", state.server_port)
  end
  return ""
end

-- Find available port
local function find_available_port(start_port)
  for port = start_port, start_port + 100 do
    local handle = io.popen("netstat -an 2>/dev/null | grep :" .. port .. " || ss -ln 2>/dev/null | grep :" .. port)
    if handle then
      local result = handle:read("*a")
      handle:close()
      if result == "" then
        return port
      end
    end
  end
  return start_port -- fallback
end

-- Enhanced server start function
local function start_server(port)
  if state.job_id then
    log_warn("Live Server is already running on port " .. tostring(state.server_port))
    return
  end

  local cwd = get_project_root()
  if not cwd or vim.fn.isdirectory(cwd) ~= 1 then
    log_error("Invalid project directory: " .. tostring(cwd))
    return
  end

  -- Find available port
  local available_port = find_available_port(port)
  if available_port ~= port then
    log_info("Port " .. port .. " is busy, using port " .. available_port)
  end

  local rel_path = vim.fn.fnamemodify(cwd, ":~:.")
  show_persistent_notify(rel_path, available_port)

  check_browser_sync(function(success)
    if not success then
      close_persistent_notify()
      return
    end

    state.server_port = available_port

    -- Build file patterns
    local file_patterns = table.concat(state.config.file_patterns, ",")

    local cmd = {
      "browser-sync",
      "start",
      "--server",
      cwd,
      "--port",
      tostring(available_port),
      "--files",
      file_patterns,
      "--no-open",
      "--no-notify",
      "--no-ghost-mode",
    }

    if state.config.open_browser then
      table.remove(cmd, #cmd) -- remove --no-open
    end

    state.job_id = vim.fn.jobstart(cmd, {
      cwd = cwd,
      stdout_buffered = false,
      stderr_buffered = false,
      on_stdout = function(_, data)
        if not data then
          return
        end
        for _, line in ipairs(data) do
          if line and line:match("Local:") then
            local url = line:match("Local:%s+(http://[%w%p:]+)")
            if url then
              state.server_url = url
              vim.schedule(function()
                close_persistent_notify()
                update_popup(rel_path, url)
                log_info("🚀 Live Server started at " .. url)
              end)
            end
          end
        end
      end,
      on_stderr = function(_, data)
        if not data then
          return
        end
        for _, line in ipairs(data) do
          if line and line ~= "" and not line:match("Browsersync") then
            vim.schedule(function()
              vim.notify("Live Server: " .. line, vim.log.levels.WARN)
            end)
          end
        end
      end,
      on_exit = function(_, exit_code)
        vim.schedule(function()
          if exit_code == 0 then
            log_info("🛑 Live Server stopped")
          else
            log_error("Live Server exited with code " .. tostring(exit_code))
          end
          close_persistent_notify()
          if state.popup then
            pcall(function()
              state.popup:unmount()
            end)
            state.popup = nil
          end
          state.job_id = nil
          state.server_port = nil
          state.server_url = nil
          state.project_root = nil -- Reset cache
        end)
      end,
    })

    if not state.job_id or state.job_id <= 0 then
      log_error("Failed to start Live Server")
      close_persistent_notify()
      state.job_id = nil
      state.server_port = nil
      return
    end
  end)
end

-- Enhanced stop function
local function stop_server()
  if not state.job_id then
    log_warn("No Live Server is currently running")
    return
  end

  local success = pcall(vim.fn.jobstop, state.job_id)
  if not success then
    log_error("Failed to stop Live Server")
    return
  end

  close_persistent_notify()
  if state.popup then
    pcall(function()
      state.popup:unmount()
    end)
    state.popup = nil
  end

  -- Reset state
  state.job_id = nil
  state.server_port = nil
  state.server_url = nil
  state.project_root = nil
end

-- Setup function with better validation
function M.setup(user_config)
  state.config = vim.tbl_deep_extend("force", defaults, user_config or {})

  -- Validate config
  if
    type(state.config.default_port) ~= "number"
    or state.config.default_port < 1
    or state.config.default_port > 65535
  then
    state.config.default_port = defaults.default_port
    log_warn("Invalid default_port, using " .. defaults.default_port)
  end

  -- Create user commands
  vim.api.nvim_create_user_command("LiveServerStart", function(opts)
    local port = tonumber(opts.args) or state.config.default_port
    if port < 1 or port > 65535 then
      log_error("Invalid port number: " .. tostring(port))
      return
    end
    start_server(port)
  end, {
    nargs = "?",
    desc = "Start the live server on specified port (default: " .. state.config.default_port .. ")",
  })

  vim.api.nvim_create_user_command("LiveServerStop", function()
    stop_server()
  end, { desc = "Stop the live server" })

  vim.api.nvim_create_user_command("LiveServerRestart", function(opts)
    local port = tonumber(opts.args) or (state.server_port or state.config.default_port)
    if port < 1 or port > 65535 then
      log_error("Invalid port number: " .. tostring(port))
      return
    end

    if state.job_id then
      log_info("♻️ Restarting Live Server...")
      stop_server()
      -- Small delay to ensure cleanup
      vim.defer_fn(function()
        start_server(port)
      end, 100)
    else
      start_server(port)
    end
  end, {
    nargs = "?",
    desc = "Restart the live server on specified port",
  })

  -- Auto-cleanup on Vim exit
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = vim.api.nvim_create_augroup("LiveServerCleanup", { clear = true }),
    callback = function()
      if state.job_id then
        pcall(vim.fn.jobstop, state.job_id)
      end
      close_persistent_notify()
      if state.popup then
        pcall(function()
          state.popup:unmount()
        end)
      end
    end,
  })

  -- Set up highlighting
  vim.api.nvim_set_hl(0, "StatusLineLiveServer", {
    fg = "#50fa7b",
    bg = vim.o.background == "dark" and "#282828" or "#f8fbf8",
    bold = true,
  })
end

-- Public API
function M.is_running()
  return state.job_id ~= nil
end

function M.get_server_url()
  return state.server_url
end

function M.get_server_port()
  return state.server_port
end

return M
