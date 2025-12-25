local M = {}
local function join_path(...)
  return table.concat({ ... }, '/')
end

function M.get_pkg_path(pkg_name, rel)
  rel = rel or ''
  -- Try mason-registry first (preferred)
  local ok, registry = pcall(require, 'mason-registry')
  if ok and registry then
    local success, pkg = pcall(registry.get_package, pkg_name)
    if success and pkg and pkg:is_installed() then
      local install_path = vim.fn.stdpath 'data' .. '/mason/packages/' .. pkg_name
      local final = install_path .. rel
      if vim.loop.fs_stat(final) then
        return vim.fs.normalize(final)
      end
      return vim.fs.normalize(install_path)
    end
  end
  -- Fallback to default mason packages location
  local data_dir = vim.fn.stdpath 'data'
  local candidate = join_path(data_dir, 'mason', 'packages', pkg_name) .. rel
  if vim.loop.fs_stat(candidate) then
    return vim.fs.normalize(candidate)
  end
  -- Some mason packages put node modules under the package dir; try that as well
  local alt = join_path(data_dir, 'mason', 'packages', pkg_name, 'node_modules') .. rel
  if vim.loop.fs_stat(alt) then
    return vim.fs.normalize(alt)
  end
  return nil
end
return M
