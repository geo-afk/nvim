local uv = vim.loop

local typos_config = vim.fn.stdpath 'config' .. '/typos.toml'

local has_config = uv.fs_stat(typos_config) ~= nil

local init_options = {
  diagnosticSeverity = 'Info',
}

if has_config then
  init_options.config = typos_config
else
  vim.notify('[typos-lsp] typos.toml not found at: ' .. typos_config, vim.log.levels.WARN)
end

return {
  init_options = init_options,
}
