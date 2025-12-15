local prefix = '<leader>x'

local function toggle(section)
  require('trouble').toggle(section)
end

local function toggle_quickfix()
  toggle 'quickfix'
end
local function toggle_loclist()
  toggle 'loclist'
end
local function toggle_buffer_diagnostics()
  toggle 'diagnostics_buffer'
end
local function toggle_workspace_diagnostics()
  toggle 'diagnostics'
end
local function trouble_cascade()
  toggle 'cascade'
end

--- @type LazyPluginSpec
return {
  'folke/trouble.nvim',
  dependencies = { 'nvim-tree/nvim-web-devicons' },
  cmd = 'Trouble',
  init = function()
    require('snacks').toggle
      .new({
        get = function()
          return require('trouble.api').is_open 'quickfix'
        end,
        set = function()
          toggle_quickfix()
        end,
        name = 'Trouble quickfix',
      })
      :map(prefix .. 'q', { desc = 'Trouble quickfix' })
    require('snacks').toggle
      .new({
        get = function()
          return require('trouble.api').is_open 'loclist'
        end,
        set = function()
          toggle_loclist()
        end,
        name = 'Trouble loclist',
      })
      :map(prefix .. 'l', { desc = 'Trouble loclist' })
    require('snacks').toggle
      .new({
        get = function()
          return require('trouble.api').is_open 'diagnostics_buffer'
        end,
        set = function()
          toggle_buffer_diagnostics()
        end,
        name = 'Trouble document diagnostics',
      })
      :map(prefix .. 'b', { desc = 'Trouble document diagnostics' })
    require('snacks').toggle
      .new({
        get = function()
          return require('trouble.api').is_open 'diagnostics'
        end,
        set = function()
          toggle_workspace_diagnostics()
        end,
        name = 'Trouble workspace diagnostics',
      })
      :map(prefix .. 'w', { desc = 'Trouble workspace diagnostics' })
    require('snacks').toggle
      .new({
        get = function()
          return require('trouble.api').is_open 'cascade'
        end,
        set = function()
          trouble_cascade()
        end,
        name = 'Trouble cascade',
      })
      :map(prefix .. 'd', { desc = 'Trouble cascade' })
  end,
  opts = {
    padding = false,
    use_diagnostic_signs = true,
    modes = {
      diagnostics_buffer = {
        mode = 'diagnostics', -- inherit from diagnostics mode
        filter = { buf = 0 }, -- filter diagnostics to the current buffer
      },
      -- show only most severe available diagnostics
      cascade = {
        mode = 'diagnostics',
        filter = function(items)
          local severity = vim.diagnostic.severity.HINT
          for _, item in ipairs(items) do
            severity = math.min(severity, item.severity)
          end
          return vim.tbl_filter(function(item)
            return item.severity == severity
          end, items)
        end,
      },
    },
  },
}
