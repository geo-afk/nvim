-- lua/config/lsp-hover.lua
-- Modern LSP Hover Configuration for LazyVim
local consts = require("constants.noice-constant")

local M = {}

-- Custom hover handler with modern styling
function M.setup()
  -- Override LSP hover handler
  vim.lsp.handlers["textDocument/hover"] = function(_, result, _, config)
    config = config or {}
    config.border = consts.border
    config.max_width = 80
    config.max_height = 20
    config.wrap = true
    config.focusable = true
    config.close_events = { "CursorMoved", "BufHidden", "InsertCharPre" }
    config.blend = 10 -- Modern blend option

    if not result or not result.contents then
      vim.notify("No hover information available", vim.log.levels.INFO)
      return
    end

    local bufnr, win_id = vim.lsp.util.open_floating_preview(
      vim.lsp.util.convert_input_to_markdown_lines(result.contents),
      "markdown",
      config
    )

    -- Auto-close
    vim.api.nvim_create_autocmd({ "CursorMoved", "BufLeave" }, {
      buffer = bufnr,
      once = true,
      callback = function()
        if vim.api.nvim_win_is_valid(win_id) then
          vim.api.nvim_win_close(win_id, true)
        end
      end,
    })
  end

  -- Override LSP signature help handler
  vim.lsp.handlers["textDocument/signatureHelp"] = function(_, result, _, config)
    config = config or {}
    config.border = consts.border
    config.max_width = 80
    config.max_height = 15
    config.wrap = true
    config.focusable = false
    config.blend = 10

    if not result or not result.signatures then
      vim.notify("No signature help available", vim.log.levels.INFO)
      return
    end

    local lines = vim.lsp.util.convert_signature_to_markdown_lines(result)
    local bufnr, win_id = vim.lsp.util.open_floating_preview(lines, "markdown", config)

    -- Auto-close
    vim.api.nvim_create_autocmd({ "CursorMoved", "BufLeave" }, {
      buffer = bufnr,
      once = true,
      callback = function()
        if vim.api.nvim_win_is_valid(win_id) then
          vim.api.nvim_win_close(win_id, true)
        end
      end,
    })
  end

  -- Setup highlight groups
  M.setup_highlights()

  -- Enhanced hover keymap
  vim.keymap.set("n", "K", function()
    if vim.bo.filetype == "help" then
      vim.cmd("normal! K")
      return
    end
    local clients = vim.lsp.get_clients({ bufnr = 0 })
    if #clients > 0 then
      vim.lsp.buf.hover()
    else
      vim.cmd("normal! K")
    end
  end, { desc = "󰋗 Show hover documentation", silent = true })

  -- Signature help keymaps
  vim.keymap.set({ "n", "i" }, "<C-k>", vim.lsp.buf.signature_help, {
    desc = "󰊕 Show signature help",
    silent = true,
  })
end

-- Setup modern highlight groups
function M.setup_highlights()
  local highlights = {
    NormalFloat = { link = "NormalFloat" },
    FloatBorder = { link = "FloatBorder" },
    FloatTitle = { fg = vim.api.nvim_get_hl(0, { name = "Identifier" }).fg, bold = true },
    LspHover = { link = "NormalFloat" },
    LspSignatureActiveParameter = {
      fg = vim.api.nvim_get_hl(0, { name = "Constant" }).fg,
      bold = true,
      underline = true,
    },
  }

  for group, opts in pairs(highlights) do
    vim.api.nvim_set_hl(0, group, opts)
  end
end

-- Enhanced hover with additional info
function M.enhanced_hover()
  local clients = vim.lsp.get_clients({ bufnr = 0 })
  local encoding = clients[1] and clients[1].offset_encoding or "utf-16"
  local params = vim.lsp.util.make_position_params(0, encoding)
  vim.lsp.buf_request(0, "textDocument/hover", params, function(err, result, ctx, _)
    if err or not result or not result.contents then
      vim.notify("No hover information available", vim.log.levels.INFO)
      return
    end

    local contents = {}
    local client = vim.lsp.get_client_by_id(ctx.client_id)
    local client_name = client and client.name or "Unknown"

    local content = result.contents
    if type(content) == "string" then
      table.insert(contents, content)
    elseif content.kind == "markdown" then
      table.insert(contents, content.value)
    elseif type(content) == "table" then
      for _, item in ipairs(content) do
        if type(item) == "string" then
          table.insert(contents, item)
        elseif item.value then
          table.insert(contents, item.value)
        end
      end
    end

    if #contents == 0 then
      vim.notify("No hover information available", vim.log.levels.INFO)
      return
    end

    table.insert(contents, "")
    table.insert(contents, "**LSP Source:** " .. client_name)

    local lines = vim.split(table.concat(contents, "\n"), "\n")
    local bufnr, win_id = vim.lsp.util.open_floating_preview(lines, "markdown", {
      border = consts.border,
      max_width = 80,
      max_height = 20,
      title = " 󰋗 Hover Documentation ",
      title_pos = "center",
      wrap = true,
      blend = 10,
    })

    -- Auto-close
    vim.api.nvim_create_autocmd({ "CursorMoved", "BufLeave" }, {
      buffer = bufnr,
      once = true,
      callback = function()
        if vim.api.nvim_win_is_valid(win_id) then
          vim.api.nvim_win_close(win_id, true)
        end
      end,
    })
  end)
end

-- Setup diagnostics float on cursor hold
function M.setup_auto_hover()
  vim.diagnostic.config({
    float = {
      border = "rounded",
      source = true,
      scope = "cursor",
      focus = false,
    },
  })
  vim.api.nvim_create_autocmd("CursorHold", {
    pattern = "*",
    callback = function()
      if vim.bo.filetype ~= "help" and #vim.lsp.get_clients({ bufnr = 0 }) > 0 then
        vim.diagnostic.open_float(nil, { scope = "cursor" })
      end
    end,
  })
  vim.o.updatetime = 300
end

return M
