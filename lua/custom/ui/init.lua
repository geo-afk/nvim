local M = {}

function M.buffer()
  return require("custom.ui.buffer")
end

function M.window()
  return require("custom.ui.window")
end

function M.render()
  return require("custom.ui.render")
end

function M.state()
  return require("custom.ui.state")
end

function M.input(opts, on_submit)
  return require("custom.ui.components.input").open(opts, on_submit)
end

function M.list(opts)
  return require("custom.ui.components.list").open(opts)
end

function M.picker(opts)
  return require("custom.ui.components.picker").open(opts)
end

function M.preview(opts)
  return require("custom.ui.components.preview").open(opts)
end

return M
