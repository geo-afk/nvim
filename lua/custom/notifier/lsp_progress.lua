-- custom/notifier/lsp_progress.lua

local M = {}

local _progress = {}

local function gen_id(prefix)
  return prefix .. '_' .. tostring(vim.loop.hrtime())
end

local function nm()
  return require 'custom.notifier'
end

local function on_progress(err, result, ctx)
  if err then
    return
  end
  local client = vim.lsp.get_client_by_id(ctx.client_id)
  if not client then
    return
  end

  local name = client.name
  local value = result.value or {}
  local kind = value.kind
  local title = value.title or ''
  local msg = value.message or ''
  local pct = value.percentage -- number or nil

  if kind == 'begin' then
    local text = title ~= '' and title or 'Working…'
    if msg ~= '' then
      text = text .. '\n' .. msg
    end
    local id = gen_id('lsp_' .. name)
    _progress[name] = id
    nm().notify(text, vim.log.levels.INFO, {
      id = id,
      title = name,
      timeout = 0,
      progress = pct, -- nil → spinner
    })
  elseif kind == 'report' and _progress[name] then
    local text = title ~= '' and title or 'Working…'
    if msg ~= '' then
      text = text .. '\n' .. msg
    end
    -- Pass progress % to renderer so it can draw the bar
    local ok, r = pcall(require, 'custom.notifier.renderer')
    if ok and r.update then
      r.update(_progress[name], text, vim.log.levels.INFO, pct)
    end
  elseif kind == 'end' then
    local id = _progress[name]
    if id then
      local text = (title ~= '' and (title .. ' ✔') or 'Done')
      if msg ~= '' then
        text = text .. ' — ' .. msg
      end
      local ok, r = pcall(require, 'custom.notifier.renderer')
      if ok and r.update then
        r.update(id, text, vim.log.levels.INFO, false)
      end
      vim.defer_fn(function()
        nm().dismiss(id)
      end, 2000)
      _progress[name] = nil
    end
  end
end

function M.setup()
  local ok = pcall(function()
    local orig = vim.lsp.handlers['$/progress']
    vim.lsp.handlers['$/progress'] = function(err, result, ctx, config)
      on_progress(err, result, ctx)
      if orig then
        orig(err, result, ctx, config)
      end
    end
  end)
  if not ok then
    vim.api.nvim_create_autocmd('LspProgress', {
      callback = function(ev)
        on_progress(nil, ev.data and ev.data.result or {}, {
          client_id = ev.data and ev.data.client_id,
        })
      end,
    })
  end
end

return M
