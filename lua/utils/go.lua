local M = {}
local ns = vim.api.nvim_create_namespace("go_import_highlight")

function M.highlight_imports(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if vim.bo[bufnr].filetype ~= "go" then
    return
  end

  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, "go")
  if not ok or not parser then
    return
  end

  local tree = parser:parse()[1]
  local root = tree:root()

  local query = vim.treesitter.query.parse(
    "go",
    [[
    (import_spec
      path: (interpreted_string_literal
        (interpreted_string_literal_content) @path))
  ]]
  )

  for id, node in query:iter_captures(root, bufnr, 0, -1) do
    if query.captures[id] == "path" then
      local text = vim.treesitter.get_node_text(node, bufnr)
      local start_row, start_col, end_row, end_col = node:range()

      -- Find the position of the last slash
      local last_slash = text:find("/[^/]*$")
      local offset = last_slash or 0

      -- Highlight from the slash (or start) to the end of the string
      vim.api.nvim_buf_set_extmark(bufnr, ns, start_row, start_col + offset, {
        end_col = end_col,
        hl_group = "Type", -- You can change this to any group like @module or Keyword
        priority = 200, -- High priority to win over standard string colors
      })
    end
  end
end

function M.setup()
  local group = vim.api.nvim_create_augroup("GoImportHighlighter", { clear = true })

  vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "TextChanged", "InsertLeave" }, {
    group = group,
    pattern = "*.go",
    callback = function(ev)
      M.highlight_imports(ev.buf)
    end,
  })
end

return M
