-- custom/explorer/config.lua

local M = {}

-- ── Tree connector style presets ──────────────────────────────────────────
--
--  'rounded'  (default)     'sharp'              'minimal'
--  ╰─ file.lua              └─ file.lua            file.lua
--  ├─ foo.lua               ├─ foo.lua             foo.lua
--  │  ╰─ bar.lua            │  └─ bar.lua            bar.lua
--
M.TREE_STYLES = {
  rounded = { last = "╰─ ", branch = "├─ ", vert = "│  ", blank = "   " },
  sharp = { last = "└─ ", branch = "├─ ", vert = "│  ", blank = "   " },
  minimal = { last = "  ", branch = "  ", vert = "  ", blank = "   " },
  dots = { last = "  · ", branch = "  · ", vert = "    ", blank = "    " },
}

M.defaults = {
  width = 36,
  expanded_width = 72,
  -- "fixed" keeps `width`; "fit" grows to visible rows and keeps that width.
  width_mode = "fixed",
  min_width = 24,
  max_width = 72,
  side = "left",
  show_hidden = false,
  show_git = true,
  follow_file = true,
  auto_close = false,
  delete_to_trash = true,

  icons = { style = "auto" },

  -- 'rounded' | 'sharp' | 'minimal' | 'dots' | leave nil for custom `tree`
  tree_style = "sharp",

  -- Override individual connector keys (nil = derive from tree_style)
  tree = nil,

  -- ── expand_all depth ─────────────────────────────────────────────────────
  --
  -- Number of directory levels opened by the expand_all keymap (E by default).
  -- 1 = immediate children of root only.
  -- 2 = two levels deep (recommended default — covers most project layouts).
  -- Increase carefully: very deep expansion on large repos will fan out many
  -- async scandir calls.
  expand_all_depth = 2,

  -- ── Git sign column ───────────────────────────────────────────────────
  --
  -- git_icons   — Nerd Font glyphs shown as the status icon (preferred).
  -- git_signs   — Plain-text fallback used when Nerd Fonts are not available.
  -- use_git_icons — true  → use git_icons glyphs (default)
  --                 false → use git_signs text
  --
  use_git_icons = true,

  git_icons = {
    modified = "󰏫", -- nf-md-pencil
    added = "", -- nf-fa-plus
    deleted = "", -- nf-md-delete
    renamed = "", -- nf-fa-arrow_right
    untracked = "", -- nf-fa-question
    conflict = "", -- nf-fa-times_circle
    ignored = "◌", -- nf-md-circle_outline
  },
  -- Plain-text fallbacks (used when use_git_icons = false)
  git_signs = {
    modified = "~",
    added = "+",
    deleted = "x",
    renamed = ">",
    untracked = "?",
    conflict = "!",
    ignored = "-",
  },

  -- Show a match-count badge in the search bar when a filter is active
  search_count = true,
  search_placeholder = "Filter files",
  search_hint = true,
  empty_folder_label = "Empty folder",
  empty_search_label = "No matching files",

  -- ── Project switcher ──────────────────────────────────────────────────
  projects = {
    dirs = {}, -- explicit project paths
    roots = {}, -- parent dirs to scan for projects
    recent_limit = 20,
    store_path = nil, -- defaults to stdpath("data") .. "/explorer/projects.json"
  },

  keymaps = {
    toggle = "<leader>e",

    open = { "<CR>", "l" },
    close_dir = "h",
    go_up = "-",
    vsplit = "v",
    split = "s",
    tab = "t",
    add = "a",
    delete = "d",
    rename = "r",
    copy = "c",
    move = "m",
    toggle_hidden = ".",
    toggle_width = "zw",
    fit_width = "<leader>ef",
    refresh = "R",
    add_project = "P",
    copy_path = "y",
    file_info = "i",
    mark = "M",
    collapse_all = "W",
    expand_all = "E",
    git_stage = "gs",
    git_restore = "gr",
    search = "/",
    quit = "q",
    help = "?",
    projects = "gp",
    -- Previously "P" — conflicts with add_project.
    projects_toggle_pin = "<C-p>",
  },
}

M.current = nil

function M.get()
  local c = M.current or M.defaults
  -- Lazily resolve tree connector table from style preset.
  -- Shallow-copy so the original table is never mutated.
  if not c.tree then
    local style = c.tree_style or "rounded"
    c = vim.tbl_extend("force", {}, c, {
      tree = M.TREE_STYLES[style] or M.TREE_STYLES.rounded,
    })
  end
  return c
end

return M
