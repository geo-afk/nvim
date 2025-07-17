return {
  {
    "ray-x/starry.nvim",
    config = function()
      local ok, starry = pcall(require, "starry")

      if not ok or starry == nil then
        vim.notify("ray-x/starry.nvim not loaded", vim.log.levels.WARN)
        return
      end

      starry.setup({
        -- Enable italic comments
        italic_comments = true,
        -- Customize text contrast
        text_contrast = {
          lighter = false, -- Higher contrast for lighter style
          darker = false, -- Higher contrast for darker style
        },
        -- Disable features if desired
        disable = {
          background = true, -- Set to true for transparent background
          term_colors = false, -- Disable setting terminal colors
          eob_lines = false, -- Make end-of-buffer lines invisible
        },
        -- Set the theme style
        style = {
          name = "moonlight", -- Options: dracula, oceanic, dracula_blood, deep ocean, darker, palenight, monokai, mariana, emerald, middlenight_blue
          disable = {}, -- List of styles to disable, e.g., {'bold', 'underline'}
          fix = true, -- Fix some highlight issues
          darker_contrast = false, -- More contrast for darker style
          daylight_switch = false, -- Enable day/night style switching
          deep_black = false, -- Enable deeper black background
        },
        -- Custom colors
        custom_colors = {
          variable = "#f797d7",
        },
        -- Custom highlights
        custom_highlights = {
          LineNr = { fg = "#777777" },
          Identifier = { fg = "#ff4797" },
          -- Example: Override Treesitter @string highlight
          ["@string"] = {
            fg = "#339922", -- Foreground color
            bg = "NONE", -- Background color
            sp = "#779988", -- Special color (e.g., for underlines)
            bold = false,
            italic = false,
            underline = false,
          },
        },
      })

      -- Set the colorscheme
      vim.cmd("colorscheme starry")
    end,
  },
}
