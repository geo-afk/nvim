local function fail(message)
  error(message, 2)
end

local config_root = vim.fn.stdpath("config")
local lock_path = vim.fs.joinpath(config_root, "nvim-pack-lock.json")
local lock = vim.json.decode(table.concat(vim.fn.readfile(lock_path), "\n"))

local declared = {}
for _, path in ipairs(vim.fn.globpath(vim.fs.joinpath(config_root, "lua", "plugins"), "**/*.lua", false, true)) do
  local source = table.concat(vim.fn.readfile(path), "\n")
  source = source:gsub("%-%-[^\r\n]*", "")
  for url in source:gmatch('src%s*=%s*["\'](https://github%.com/[^"\']+)["\']') do
    declared[url:gsub("%.git$", "")] = path
  end
end

local locked = {}
local transitive_dependencies = {
  ["https://github.com/nvim-neotest/nvim-nio"] = "https://github.com/rcarriga/nvim-dap-ui",
}
for name, spec in pairs(lock.plugins or {}) do
  local url = spec.src:gsub("%.git$", "")
  locked[url] = name
  local parent = transitive_dependencies[url]
  if not declared[url] and not (parent and declared[parent]) then
    fail(("lock entry %q (%s) has no plugin declaration"):format(name, spec.src))
  end
end

for url, path in pairs(declared) do
  if not locked[url] then
    fail(("plugin declared in %s is missing from the lockfile: %s"):format(path, url))
  end
end

print(("Pack lock consistency passed (%d plugins)"):format(vim.tbl_count(locked)))
