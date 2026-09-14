local root_markers = { "config.yml", ".git" }
local connection
local resolved = false
local prompting = false
local waiting = {}

local function finish(value)
  connection = value
  resolved = true
  prompting = false

  local callbacks = waiting
  waiting = {}
  for _, item in ipairs(callbacks) do
    item.on_dir(item.root)
  end
end

local function ask_input(opts, callback)
  if opts.secret then
    vim.schedule(function()
      local ok, value = pcall(vim.fn.inputsecret, opts.prompt)
      callback(ok and value or nil)
    end)
    return
  end

  vim.ui.input(opts, callback)
end

local function ask_connection_string()
  ask_input({ prompt = "PostgreSQL connection string: ", secret = true }, function(value)
    value = value and vim.trim(value) or ""
    finish(value ~= "" and value or nil)
  end)
end

local field_prompts = {
  { key = "host", prompt = "PostgreSQL host: ", default = "127.0.0.1" },
  { key = "port", prompt = "PostgreSQL port: ", default = "5432" },
  { key = "user", prompt = "PostgreSQL user: " },
  { key = "password", prompt = "PostgreSQL password: ", secret = true },
  { key = "dbname", prompt = "PostgreSQL database: " },
  { key = "sslmode", prompt = "PostgreSQL SSL mode: ", default = "disable" },
}

local function quote_conninfo(value)
  return "'" .. value:gsub("\\", "\\\\"):gsub("'", "\\'") .. "'"
end

local function ask_fields(index, values)
  local field = field_prompts[index]
  if not field then
    finish(string.format(
      "host=%s port=%s user=%s password=%s dbname=%s sslmode=%s",
      quote_conninfo(values.host),
      quote_conninfo(values.port),
      quote_conninfo(values.user),
      quote_conninfo(values.password),
      quote_conninfo(values.dbname),
      quote_conninfo(values.sslmode)
    ))
    return
  end

  ask_input({
    prompt = field.prompt,
    default = field.default,
    secret = field.secret,
  }, function(value)
    if value == nil then
      finish(nil)
      return
    end

    values[field.key] = value
    ask_fields(index + 1, values)
  end)
end

local function prompt_for_connection()
  vim.ui.select({
    "Enter connection string",
    "Enter connection fields",
    "Use sqls without a connection",
  }, { prompt = "Configure PostgreSQL for sqls:" }, function(_, index)
    if index == 1 then
      ask_connection_string()
    elseif index == 2 then
      ask_fields(1, {})
    else
      finish(nil)
    end
  end)
end

local function root_dir(bufnr, on_dir)
  local root = vim.fs.root(bufnr, root_markers)
  if resolved then
    on_dir(root)
    return
  end

  waiting[#waiting + 1] = { root = root, on_dir = on_dir }
  if prompting then
    return
  end

  prompting = true
  prompt_for_connection()
end

local function before_init(_, config)
  local sqls_settings = config.settings.sqls
  sqls_settings.connections = connection and {
    {
      driver = "postgresql",
      dataSourceName = connection,
    },
  } or nil
end

return {
  cmd = { "sqls" },
  filetypes = { "sql", "mysql" },
  root_dir = root_dir,
  before_init = before_init,
  settings = {
    sqls = {
      lowercaseKeywords = false,
      telemetry = {
        enable = false,
      },
    },
  },
}
