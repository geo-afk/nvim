-- =============================================================================
-- lua/custom/autoclose/ts.lua
-- Treesitter integration for smart editing
-- =============================================================================

local M = {}

---Safe retrieval of Treesitter node at cursor
---@param bufnr? number
---@return TSNode|nil
function M.get_node(bufnr)
  bufnr = bufnr or 0
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
  if not ok or not parser then
    return nil
  end

  local ok_node, node = pcall(vim.treesitter.get_node, { bufnr = bufnr })
  if ok_node and node then
    return node
  end
  return nil
end

---Check if a node type or any of its ancestors are in the check list
---@param node TSNode|nil
---@param types string[]
---@return boolean
function M.has_ancestor_type(node, types)
  if not node then
    return false
  end

  local current = node
  while current do
    local ntype = current:type()
    for _, t in ipairs(types) do
      if ntype == t or ntype:find(t) then
        return true
      end
    end
    current = current:parent()
  end

  return false
end

---Verify if the cursor resides inside a comment node
---@param ignored_nodes string[]
---@param node? TSNode
---@return boolean
function M.in_comment(ignored_nodes, node)
  node = node or M.get_node()
  return M.has_ancestor_type(node, ignored_nodes)
end

---Verify if the cursor resides inside a string/literal node
---@param ignored_quote_nodes string[]
---@param node? TSNode
---@return boolean
function M.in_string(ignored_quote_nodes, node)
  node = node or M.get_node()
  return M.has_ancestor_type(node, ignored_quote_nodes)
end

---Find the nearest ancestor node that represents a delimited structure
---@param node? TSNode
---@return TSNode|nil
function M.get_pair_node(node)
  node = node or M.get_node()
  if not node then
    return nil
  end

  local current = node
  while current do
    local ntype = current:type()

    -- Refinement: If we are on a "content" or "fragment" node, we definitely want the parent.
    -- These nodes are usually inside the delimiters we want to target.
    if ntype:find("content") or ntype:find("fragment") or ntype:find("body") then
      local parent = current:parent()
      if parent then
        current = parent
        ntype = current:type()
      end
    end

    -- Common pair-like node types in various grammars
    if
      ntype:find("bracket")
      or ntype:find("brace")
      or ntype:find("paren")
      or ntype:find("string")
      or ntype:find("quote")
      or ntype:find("element") -- HTML/XML
      or ntype:find("template")
    then
      return current
    end
    current = current:parent()
  end
  return nil
end

---Get language parser active under the cursor for mixed language support
---@return string
function M.get_lang()
  local node = M.get_node()
  if not node then
    return vim.bo.filetype
  end

  local tree = node:tree()
  if tree then
    local lang = tree:lang()
    if lang and lang ~= "" then
      return lang
    end
  end

  return vim.bo.filetype
end

return M
