return {
  cmd = { "sqls" },
  filetypes = { "sql", "mysql" },
  root_markers = { "config.yml", ".git" },
  settings = {
    sqls = {
      lowercaseKeywords = false,
      connections = {
        {
          driver = "postgresql",
          dataSourceName = "host=127.0.0.1 port=5432 user=postgres password=pascal321 dbname=auth sslmode=disable",
        },
      },
      telemetry = {
        enable = false,
      },
    },
  },
}
