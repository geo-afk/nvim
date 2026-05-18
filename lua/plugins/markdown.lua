vim.pack.add({
  {
    src = "https://github.com/OXY2DEV/markview.nvim",
  },
})

local ok, markview = pcall(require, "markview")

if not ok then
  return
end

--------------------------------------------------------------------------------
-- OPTIONS
--------------------------------------------------------------------------------

vim.opt.conceallevel = 2
vim.opt.concealcursor = "nc"

--------------------------------------------------------------------------------
-- SETUP
--------------------------------------------------------------------------------

markview.setup({
  ------------------------------------------------------------------------------
  -- EXPERIMENTAL
  ------------------------------------------------------------------------------
  experimental = {
    check_rtp_message = true,

    file_open_command = nil,

    linewise_ignore_org_indent = false,

    list_empty_line_tolerance = 1,

    max_file_length = 50000,

    read_chunk_size = 10000,

    hybrid_mode = false,

    debounce = 50,

    prefer_nvim = true,

    date_formats = {
      "%Y-%m-%d",
      "%d-%m-%Y",
      "%m/%d/%Y",
    },

    date_time_formats = {
      "%Y-%m-%d %H:%M",
      "%d-%m-%Y %H:%M",
    },
  },

  ------------------------------------------------------------------------------
  -- PREVIEW
  ------------------------------------------------------------------------------
  preview = {
    enable = true,

    icon_provider = "internal",

    filetypes = {
      "markdown",
      "quarto",
      "rmd",
      "typst",
    },

    ignore_buftypes = {
      "nofile",
      "prompt",
      "help",
      "terminal",
    },

    modes = { "n", "no", "c" },

    hybrid_modes = { "n" },

    linewise_hybrid_mode = true,

    max_buf_lines = 50000,

    min_buf_lines = 1,

    debounce = 50,
  },

  ------------------------------------------------------------------------------
  -- MARKDOWN
  ------------------------------------------------------------------------------
  markdown = {
    enable = true,

    ----------------------------------------------------------------------------
    -- HEADINGS
    ----------------------------------------------------------------------------
    headings = {
      enable = true,

      shift_width = 0,

      heading_1 = {
        style = "icon",
        icon = "󰼏 ",
        hl = "MarkviewHeading1",
      },

      heading_2 = {
        style = "icon",
        icon = "󰎨 ",
        hl = "MarkviewHeading2",
      },

      heading_3 = {
        style = "icon",
        icon = "󰼑 ",
        hl = "MarkviewHeading3",
      },

      heading_4 = {
        style = "icon",
        icon = "󰎲 ",
        hl = "MarkviewHeading4",
      },

      heading_5 = {
        style = "icon",
        icon = "󰼓 ",
        hl = "MarkviewHeading5",
      },

      heading_6 = {
        style = "icon",
        icon = "󰎴 ",
        hl = "MarkviewHeading6",
      },
    },

    ----------------------------------------------------------------------------
    -- HORIZONTAL RULES
    ----------------------------------------------------------------------------
    horizontal_rules = {
      enable = true,

      parts = {
        {
          type = "repeating",

          repeat_amount = function()
            return vim.o.columns
          end,

          text = "─",
        },
      },
    },

    ----------------------------------------------------------------------------
    -- CODE BLOCKS
    ----------------------------------------------------------------------------
    code_blocks = {
      enable = true,

      style = "language",

      min_width = 60,

      pad_amount = 2,

      language_direction = "right",

      sign = true,

      icons = true,

      default = "󰆍",

      border_hl = "FloatBorder",

      info_hl = "Title",
    },

    ----------------------------------------------------------------------------
    -- BLOCK QUOTES
    ----------------------------------------------------------------------------
    block_quotes = {
      enable = true,

      default = {
        border = "▋",
        hl = "Comment",
      },

      note = {
        border = "󰋽 ",
        hl = "DiagnosticInfo",
      },

      tip = {
        border = "󰌶 ",
        hl = "DiagnosticHint",
      },

      important = {
        border = "󰅾 ",
        hl = "DiagnosticWarn",
      },

      warning = {
        border = "󰀪 ",
        hl = "DiagnosticWarn",
      },

      caution = {
        border = "󰳦 ",
        hl = "DiagnosticError",
      },
    },

    ----------------------------------------------------------------------------
    -- CHECKBOXES
    ----------------------------------------------------------------------------
    checkboxes = {
      enable = true,

      checked = {
        text = "󰄲",
        hl = "DiagnosticOk",
      },

      unchecked = {
        text = "󰄱",
        hl = "DiagnosticHint",
      },

      custom = {
        todo = {
          raw = "[-]",
          rendered = "󰥔",
          hl = "DiagnosticWarn",
        },

        cancelled = {
          raw = "[/]",
          rendered = "󰜺",
          hl = "DiagnosticError",
        },
      },
    },

    ----------------------------------------------------------------------------
    -- TABLES
    ----------------------------------------------------------------------------
    tables = {
      enable = true,

      style = "full",

      use_virt_lines = true,
    },

    ----------------------------------------------------------------------------
    -- LISTS
    ----------------------------------------------------------------------------
    lists = {
      enable = true,

      shift_width = 2,

      marker_minus = {
        text = "•",
        hl = "MarkviewListItemMinus",
      },

      marker_plus = {
        text = "◦",
        hl = "MarkviewListItemPlus",
      },

      marker_star = {
        text = "▪",
        hl = "MarkviewListItemStar",
      },
    },

    ----------------------------------------------------------------------------
    -- INLINE CODE
    ----------------------------------------------------------------------------
    inline_codes = {
      enable = true,

      hl = "String",

      corner_left = " ",
      corner_right = " ",
    },

    ----------------------------------------------------------------------------
    -- LINKS
    ----------------------------------------------------------------------------
    links = {
      enable = true,

      hyperlinks = {
        icon = "󰌹 ",
        hl = "Underlined",
      },

      images = {
        icon = "󰥶 ",
        hl = "Special",
      },

      emails = {
        icon = "󰀓 ",
        hl = "Directory",
      },
    },
  },

  ------------------------------------------------------------------------------
  -- MARKDOWN INLINE
  ------------------------------------------------------------------------------
  markdown_inline = {
    enable = true,

    inline_codes = {
      enable = true,
    },

    hyperlinks = {
      enable = true,
    },

    images = {
      enable = true,
    },

    internal_links = {
      enable = true,
    },

    emails = {
      enable = true,
    },

    uri_autolinks = {
      enable = true,
    },

    html_entities = {
      enable = true,
    },
  },

  ------------------------------------------------------------------------------
  -- HTML
  ------------------------------------------------------------------------------
  html = {
    enable = true,

    container_elements = {
      "div",
      "section",
      "article",
      "details",
    },

    headings = {
      "h1",
      "h2",
      "h3",
      "h4",
      "h5",
      "h6",
    },

    void_elements = {
      "br",
      "hr",
      "img",
      "input",
    },
  },

  ------------------------------------------------------------------------------
  -- LATEX
  ------------------------------------------------------------------------------
  latex = {
    enable = true,

    blocks = {
      enable = true,
    },

    inlines = {
      enable = true,
    },

    commands = {
      enable = true,
    },

    escapes = {
      enable = true,
    },

    fonts = {
      enable = true,
    },

    parenthesis = {
      enable = true,
    },

    subscripts = {
      enable = true,
    },

    superscripts = {
      enable = true,
    },

    symbols = {
      enable = true,
    },

    texts = {
      enable = true,
    },
  },

  ------------------------------------------------------------------------------
  -- TYPST
  ------------------------------------------------------------------------------
  typst = {
    enable = true,
  },

  ------------------------------------------------------------------------------
  -- YAML
  ------------------------------------------------------------------------------
  yaml = {
    enable = true,
  },

  ------------------------------------------------------------------------------
  -- CUSTOM RENDERERS
  ------------------------------------------------------------------------------
  renderers = {
    markdown = {},
    html = {},
    latex = {},
  },
})

--------------------------------------------------------------------------------
-- KEYMAPS
--------------------------------------------------------------------------------

vim.keymap.set("n", "<leader>mv", "<cmd>Markview toggle<CR>", {
  desc = "Toggle Markview",
})

vim.keymap.set("n", "<leader>ms", "<cmd>Markview splitToggle<CR>", {
  desc = "Toggle Markview Split",
})

vim.keymap.set("n", "<leader>mh", "<cmd>Markview hybridToggle<CR>", {
  desc = "Toggle Hybrid Mode",
})

vim.keymap.set("n", "<leader>me", "<cmd>Markview enable<CR>", {
  desc = "Enable Markview",
})

vim.keymap.set("n", "<leader>md", "<cmd>Markview disable<CR>", {
  desc = "Disable Markview",
})

--------------------------------------------------------------------------------
-- WHICH-KEY
--------------------------------------------------------------------------------

local wk_ok, wk = pcall(require, "which-key")

if wk_ok then
  wk.add({
    {
      "<leader>m",
      group = "markview",
    },

    {
      "<leader>mv",
      desc = "Toggle Markview",
    },

    {
      "<leader>ms",
      desc = "Toggle Split Preview",
    },

    {
      "<leader>mh",
      desc = "Toggle Hybrid Mode",
    },

    {
      "<leader>me",
      desc = "Enable Markview",
    },

    {
      "<leader>md",
      desc = "Disable Markview",
    },
  })
end
