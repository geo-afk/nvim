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
  side = "left",
  show_hidden = false,
  show_git = true,
  follow_file = true,
  auto_close = false,

  icons = { style = "auto" },

  -- 'rounded' | 'sharp' | 'minimal' | 'dots' | leave nil for custom `tree`
  tree_style = "sharp",

  -- Override individual connector keys (nil = derive from tree_style)
  tree = nil,

  -- ── Git sign column ───────────────────────────────────────────────────
  --
  -- git_icons   — Nerd Font glyphs shown as the status icon (preferred).
  --               Each glyph must render as ≤ 2 display columns; git.lua
  --               pads automatically with strdisplaywidth() so the sign
  --               column never shifts regardless of the font in use.
  --
  -- git_signs   — Plain-text fallback used when Nerd Fonts are not
  --               available.  Set use_git_icons = false to force these.
  --
  -- use_git_icons — true  → use git_icons glyphs (default)
  --                 false → use git_signs text
  --
  use_git_icons = true,

  git_icons = {
    modified = " ", -- nf-fa-pencil             (U+F040)
    added = " ", -- nf-fa-plus               (U+F067)
    deleted = " ", -- nf-fa-trash-o            (U+F014)
    renamed = " ", -- nf-fa-arrow-right        (U+F061)
    untracked = " ", -- nf-fa-question-circle    (U+F059)
    conflict = " ", -- nf-fa-exclamation-circle (U+F06A)
    ignored = " ", -- nf-fa-eye-slash          (U+F070)
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
