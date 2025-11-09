-- config.lua
local M = {}

M.config = {
  window = {
    width = 0.47,
    min_width = 64,
    max_width = 90,
    max_height = 20,
    position = "center",
    border = "rounded",
    blend = 0,
    zindex = 250,
  },
  theme = {
    bg = "#282c34",
    bg_alt = "#32363e",
    fg = "#abb2bf",
    border = "#61afef",
    prompt_bg = "#1e2125",
    prompt_fg = "#61afef",
    cursor_bg = "#e06c75",
    selection_bg = "#40486a",
    hint_fg = "#5c6370",
    header_fg = "#c678dd",
    header_bg = "#32363e",
    kind_fg = "#56b6c2",
    desc_fg = "#abb2bf",
    separator_fg = "#5c6370",
    accent_fg = "#d19a66",
    success_fg = "#98c379",
    error_fg = "#e06c75",
  },
  icons = {
    cmd = "󱐌 ", -- Command key, very Mac
    search = "", -- Standard search icon
    lua = "󰢱", -- Specific language icon
    separator = "─", -- Simple horizontal line
    header = "󰉋", -- Clean folder icon
    item = "•", -- Simple bullet point
    selected = "▶", -- Black right-pointing triangle for selection
    more = "▾", -- Black down-pointing small triangle for expand
  },
  animation = {
    enabled = true,
    duration = 180,
    slide_distance = 10,
  },
  completion = {
    enabled = true,
    max_items_per_group = 6,
    auto_trigger = true,
    delay = 50,
    fuzzy = true,
  },
  features = {
    history = true,
    auto_pairs = true,
    undo_redo = true,
    inline_hints = true,
    group_completions = true,
    smart_quit = true, -- Handle quit commands intelligently
  },
}

return M
