-- =============================================================================
-- lua/overseer/template/cpp/make.lua
-- MinGW: mingw32-make / make for projects with a Makefile
-- =============================================================================

local function get_make_bin()
  if vim.fn.executable("mingw32-make") == 1 then
    return "mingw32-make"
  end
  if vim.fn.executable("make") == 1 then
    return "make"
  end
  return "mingw32-make"
end

return {
  {
    name = "mingw: make",
    builder = function(params)
      local cwd = vim.fs.root(vim.fn.expand("%:p:h"), { "Makefile", "makefile", "GNUmakefile" })
        or vim.fn.getcwd()
      local make_bin = get_make_bin()
      local target = params.target or ""
      local cmd = { make_bin }

      if target ~= "" then
        table.insert(cmd, target)
      end
      if params.args and params.args ~= "" then
        vim.list_extend(cmd, vim.split(params.args, " ", { plain = true, trimempty = true }))
      end

      return {
        name = make_bin .. (target ~= "" and (" " .. target) or ""),
        cmd = cmd,
        cwd = cwd,
        components = {
          "on_exit_set_status",
          { "on_complete_notify", system = "unfocused" },
          { "on_output_parse", problem_matcher = "$gcc" },
          { "on_output_quickfix", open_on_exit = "failure", set_diagnostics = true },
          "on_complete_dispose",
        },
        metadata = {
          tags = { "cpp", "c", "make", "mingw" },
        },
      }
    end,
    params = {
      target = {
        type = "string",
        name = "Target",
        description = "Makefile target (e.g. all, clean, build, test)",
        optional = true,
        default = "",
      },
      args = {
        type = "string",
        name = "Arguments",
        description = "Additional make flags (e.g. -j4)",
        optional = true,
      },
    },
    priority = 15,
    tags = { "cpp", "c", "make", "mingw" },
    condition = {
      callback = function(_)
        local has_make = vim.fn.executable("mingw32-make") == 1 or vim.fn.executable("make") == 1
        local has_makefile = vim.fs.root(vim.fn.expand("%:p:h"), { "Makefile", "makefile", "GNUmakefile" }) ~= nil
        return has_make and has_makefile
      end,
    },
  },
}
