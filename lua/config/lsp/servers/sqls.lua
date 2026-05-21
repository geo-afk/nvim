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
          dataSourceName = string.format(
            "host=127.0.0.1 port=5432 user=%s password=%s dbname=%s sslmode=disable",
            os.getenv("SQLS_DB_USER") or "postgres",
            os.getenv("SQLS_DB_PASSWORD") or "",
            os.getenv("SQLS_DB_NAME") or "auth"
          ),
        },
      },
      telemetry = {
        enable = false,
      },
    },
  },
}
