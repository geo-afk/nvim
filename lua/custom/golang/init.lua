-- lua/custom/golang/init.lua
-- Entry point for Go-specific UI extensions.
-- Must be invoked via M.setup() from the loader config callback.

local M = {}

function M.setup()
  require("custom.golang.swag").setup()
  require("custom.golang.swag_hover").setup()
end

return M
