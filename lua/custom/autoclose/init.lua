-- =============================================================================
-- lua/custom/autoclose/init.lua
-- Entry point and bootstrap loader for smart editing
-- =============================================================================

local config = require("custom.autoclose.config")
local rules = require("custom.autoclose.rules")
local handlers = require("custom.autoclose.handlers")
local surround = require("custom.autoclose.surround")

local M = {}
local did_setup = false

---Toggle smart editing globally
function M.toggle()
  config.current.enabled = not config.current.enabled
  local status = config.current.enabled and "enabled" or "disabled"
  vim.notify("[autoclose] smart context editing " .. status, vim.log.levels.INFO)
end

---Initialize smart editing configuration and set up keybindings
---@param opts? table User override options
function M.setup(opts)
  if did_setup then
    return
  end
  did_setup = true

  -- Merge configurations
  config.current = vim.tbl_deep_extend("force", config.defaults, opts or {})

  -- ── 1. Create User Commands ──────────────────────────────────────────────────
  vim.api.nvim_create_user_command("AutoCloseToggle", function()
    M.toggle()
  end, { desc = "Toggle smart editing globally" })

  -- ── 2. Register Autoclose Keymaps ────────────────────────────────────────────
  local pairs_map = config.get("pairs")
  local closers = config.get("closers")

  -- Set up pairing keymaps
  for open, close in pairs(pairs_map) do
    -- Bind opening delimiters
    vim.keymap.set("i", open, function()
      if rules.can_close(open, close) then
        return open .. close .. "<Left>"
      end

      -- Identical quote triggers skip if typed at closing boundary
      if open == close then
        return handlers.handle_close(open)
      end

      return open
    end, { expr = true, desc = "Smart close: " .. open })
  end

  -- Bind closing delimiters for skip-over behavior
  for closer, _ in pairs(closers) do
    if pairs_map[closer] == closer then
      goto continue
    end

    vim.keymap.set("i", closer, function()
      return handlers.handle_close(closer)
    end, { expr = true, desc = "Smart skip: " .. closer })

    ::continue::
  end

  -- Bind tag closing
  vim.keymap.set("i", ">", function()
    return handlers.handle_tag_close()
  end, { expr = true, desc = "Smart tag close" })

  -- ── 3. Register Handler Keymaps ─────────────────────────────────────────────
  -- Bind smart backspace deletion
  vim.keymap.set("i", "<BS>", function()
    return handlers.handle_backspace()
  end, { expr = true, desc = "Smart backspace delete" })

  -- Bind smart brace carriage return expansion
  vim.keymap.set("i", "<CR>", function()
    return handlers.handle_cr()
  end, { expr = true, desc = "Smart CR brace expansion" })

  -- ── 4. Register Surround Keymaps ────────────────────────────────────────────
  local km = config.get("keymaps")

  -- Visual mode surround wrapping
  if km.surround_visual then
    vim.keymap.set("x", km.surround_visual, function()
      surround.visual_surround()
    end, { desc = "Surround visual selection" })
  end

  -- Normal mode surround utilities
  if km.surround_normal then
    vim.keymap.set("n", km.surround_normal, function()
      surround.word_surround()
    end, { desc = "Surround word under cursor" })
  end

  -- Normal mode surround treesitter node
  vim.keymap.set("n", "<leader>an", function()
    surround.node_surround()
  end, { desc = "Surround Treesitter node under cursor" })

  -- Normal mode delete surround
  if km.surround_delete then
    vim.keymap.set("n", km.surround_delete, function()
      surround.delete_surround()
    end, { desc = "Delete surrounding pair" })
  end

  -- Normal mode replace surround
  if km.surround_replace then
    vim.keymap.set("n", km.surround_replace, function()
      surround.replace_surround()
    end, { desc = "Replace surrounding pair" })
  end

  -- Global Toggle Keymap
  if km.toggle then
    vim.keymap.set("n", km.toggle, function()
      M.toggle()
    end, { desc = "Toggle smart editing globally" })
  end
end

return M
