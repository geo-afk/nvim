local State = {
  active = false,
  mode = ":",
  text = "",
  cursor_pos = 1,
  win = nil,
  buf = nil,
  completions = {},
  grouped_completions = {},
  comp_index = 0,
  flat_items = {},
  history_index = 0,
  undo_stack = {},
  redo_stack = {},
  ns_id = vim.api.nvim_create_namespace("custom.commandline"),
  original_win = nil, -- Track the window we came from
}

function State:reset()
  self.text = ""
  self.cursor_pos = 1
  self.history_index = 0
  self.completions = {}
  self.grouped_completions = {}
  self.comp_index = 0
  self.flat_items = {}
  self.undo_stack = {}
  self.redo_stack = {}
end

function State:push_undo()
  table.insert(self.undo_stack, { text = self.text, cursor = self.cursor_pos })
  if #self.undo_stack > 50 then
    table.remove(self.undo_stack, 1)
  end
  self.redo_stack = {}
end

function State:undo()
  if #self.undo_stack > 0 then
    table.insert(self.redo_stack, { text = self.text, cursor = self.cursor_pos })
    local state = table.remove(self.undo_stack)
    self.text = state.text
    self.cursor_pos = state.cursor
    return true
  end
  return false
end

function State:redo()
  if #self.redo_stack > 0 then
    table.insert(self.undo_stack, { text = self.text, cursor = self.cursor_pos })
    local state = table.remove(self.redo_stack)
    self.text = state.text
    self.cursor_pos = state.cursor
    return true
  end
  return false
end

return State
