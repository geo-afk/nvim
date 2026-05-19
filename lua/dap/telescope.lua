-- lua/dap/telescope.lua
-- Telescope pickers for DAP: configurations, breakpoints, frames, variables.
-- Gracefully no-ops when telescope is not installed.

local M = {}

local function has(mod)
  return pcall(require, mod)
end

function M.setup()
  local ok_tel = has("telescope")
  local ok_dap = has("dap")
  if not (ok_tel and ok_dap) then return end

  -- Load the telescope-dap extension if available
  local ok_ext = pcall(require("telescope").load_extension, "dap")

  local map = function(lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, { noremap = true, silent = true, desc = desc })
  end

  if ok_ext then
    -- ── Extension pickers (richer UI) ────────────────────────────────────
    map("<leader>dtc", "<cmd>Telescope dap configurations<CR>",   "DAP: Pick configuration")
    map("<leader>dtb", "<cmd>Telescope dap list_breakpoints<CR>", "DAP: List breakpoints")
    map("<leader>dtf", "<cmd>Telescope dap frames<CR>",           "DAP: Call-stack frames")
    map("<leader>dtv", "<cmd>Telescope dap variables<CR>",        "DAP: Scope variables")
    map("<leader>dtC", "<cmd>Telescope dap commands<CR>",         "DAP: Commands")
  else
    -- ── Fallback: custom pickers using telescope builtins ─────────────────
    local telescope = require("telescope")
    local pickers   = require("telescope.pickers")
    local finders   = require("telescope.finders")
    local conf      = require("telescope.config").values
    local actions   = require("telescope.actions")
    local action_state = require("telescope.actions.state")

    --- Pick a debug configuration for the current filetype and run it.
    local function pick_config()
      local dap      = require("dap")
      local ft       = vim.bo.filetype
      local configs  = dap.configurations[ft] or {}
      if #configs == 0 then
        vim.notify("[dap] No configurations for filetype: " .. ft, vim.log.levels.INFO)
        return
      end

      pickers.new({}, {
        prompt_title = "DAP Configurations (" .. ft .. ")",
        finder = finders.new_table({
          results = configs,
          entry_maker = function(cfg)
            return {
              value   = cfg,
              display = cfg.name,
              ordinal = cfg.name,
            }
          end,
        }),
        sorter = conf.generic_sorter({}),
        attach_mappings = function(buf, _)
          actions.select_default:replace(function()
            actions.close(buf)
            local sel = action_state.get_selected_entry()
            if sel then dap.run(sel.value) end
          end)
          return true
        end,
      }):find()
    end

    map("<leader>dtc", pick_config, "DAP: Pick configuration")

    --- List breakpoints and jump to selection.
    local function list_breakpoints()
      local dap_bps = require("dap.breakpoints")
      local bps     = dap_bps.get()
      local entries = {}
      for bufnr, buf_bps in pairs(bps) do
        local name = vim.api.nvim_buf_get_name(bufnr)
        for _, bp in ipairs(buf_bps) do
          table.insert(entries, {
            bufnr = bufnr,
            lnum  = bp.line,
            col   = 1,
            text  = vim.fn.fnamemodify(name, ":~:.") .. ":" .. bp.line
              .. (bp.condition and (" [cond: " .. bp.condition .. "]") or ""),
          })
        end
      end
      if #entries == 0 then
        vim.notify("[dap] No breakpoints set.", vim.log.levels.INFO)
        return
      end
      vim.fn.setqflist(entries, "r")
      vim.cmd("copen")
    end

    map("<leader>dtb", list_breakpoints, "DAP: List breakpoints (qf)")
  end
end

return M
