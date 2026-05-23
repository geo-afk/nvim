-- =============================================================================
--  plugins/which-key.lua  ·  which-key.nvim (v3)
-- =============================================================================
vim.pack.add({ { src = "https://github.com/folke/which-key.nvim" } })

local ok, wk = pcall(require, "which-key")
if not ok then
  return
end

local function supports(method)
  return function()
    return #vim.lsp.get_clients({ bufnr = 0, method = method }) > 0
  end
end

wk.setup({
  preset = "helix",
  delay = 0,
  show_help = true,
  spec = {
    -- ── Groups ───────────────────────────────────────────────────────────────
    { "<leader>b", group = "Buffer", icon = { icon = "󰓩 ", hl = "MiniIconsCyan" } },
    { "<leader>c", group = "Code / LSP", icon = { icon = "󰘦 ", hl = "MiniIconsGreen" } },
    { "<leader>d", group = "Diagnostics", icon = { icon = "󱖫 ", hl = "MiniIconsRed" } },
    { "<leader>e", group = "Explorer", icon = { icon = "󰙅 ", hl = "MiniIconsBrown" } },
    -- { "<leader>f", group = "Format", icon = { icon = "󰉿 ", hl = "MiniIconsAzure" } },
    { "<leader>g", group = "Git", icon = { icon = "󰊢 ", hl = "MiniIconsOrange" } },
    { "<leader>G", group = "Go Debugger", icon = { icon = "󰃤 ", hl = "MiniIconsRed" } },
    { "<leader>n", group = "Neovim", icon = { icon = " ", hl = "MiniIconsBlue" } },
    { "<leader>p", group = "Packages / Plugins", icon = { icon = "󰏖 ", hl = "MiniIconsGreen" } },
    { "<leader>r", group = "Run / Server", icon = { icon = "󱂬 ", hl = "MiniIconsOrange" } },
    { "<leader>s", group = "Search / Find", icon = { icon = "󰍉 ", hl = "MiniIconsYellow" } },
    { "<leader>z", group = "Terminal", icon = { icon = "󰆍 ", hl = "MiniIconsGrey" } },
    { "<leader>u", group = "Utility / Undo", icon = { icon = "󰕌 ", hl = "MiniIconsPurple" } },
    { "<leader>a", group = "Actions / Autoclose", icon = { icon = "󱗼 ", hl = "MiniIconsGreen" } },
    { "<leader>w", group = "Save", icon = { icon = "󰆓 ", hl = "MiniIconsBlue" } },
    { "<leader>x", group = "Trouble / Lists", icon = { icon = "󱨧 ", hl = "MiniIconsRed" } },

    -- ── Individual Mapping Overrides (optional) ──────────────────────────────
    {
      "<leader>ca",
      icon = { icon = "󱐋 ", hl = "MiniIconsYellow" },
      cond = supports("textDocument/codeAction"),
    },
    {
      "<leader>ce",
      icon = { icon = "󰛔 ", hl = "MiniIconsGreen" },
      cond = supports("textDocument/linkedEditingRange"),
    },
    {
      "<leader>ch",
      icon = { icon = "󰌶 ", hl = "MiniIconsBlue" },
      cond = supports("textDocument/inlayHint"),
    },
    {
      "<leader>ci",
      icon = { icon = "󰦬 ", hl = "MiniIconsGreen" },
      cond = supports("textDocument/codeLens"),
    },
    {
      "<leader>ck",
      icon = { icon = "󰌌 ", hl = "MiniIconsBlue" },
      cond = function()
        return #vim.lsp.get_clients({ bufnr = 0 }) > 0
      end,
    },
    {
      "<leader>cr",
      icon = { icon = "󰑕 ", hl = "MiniIconsGreen" },
      cond = supports("textDocument/rename"),
    },
    -- { "<leader>fi", icon = { icon = "󰋼 ", hl = "MiniIconsBlue" } },
    { "<leader>gg", icon = { icon = "󰊢 ", hl = "MiniIconsGreen" } },
    { "<leader>nd", icon = { icon = "󰙏 ", hl = "MiniIconsBlue" } },
    { "<leader>nr", icon = { icon = "󰜉 ", hl = "MiniIconsBlue" } },
    { "<leader>pm", icon = { icon = "󰏖 ", hl = "MiniIconsGreen" } },
    { "<leader>uu", icon = { icon = "󰕌 ", hl = "MiniIconsPurple" } },
    { "<leader>wa", icon = { icon = "󰆓 ", hl = "MiniIconsBlue" } },
    { "<leader>ww", icon = { icon = "󰆓 ", hl = "MiniIconsBlue" } },
    -- { "<leader>tt", icon = { icon = "󰚈 ", hl = "MiniIconsGrey" } },

    -- ── Root level groups ────────────────────────────────────────────────────
    { "g", group = "Goto", icon = { icon = "󰜉 ", hl = "MiniIconsBlue" } },
    { "m", group = "Marks", icon = { icon = "󰸵 ", hl = "MiniIconsOrange" } },
    { "[", group = "Prev", icon = { icon = "󰅵 ", hl = "MiniIconsGrey" } },
    { "]", group = "Next", icon = { icon = "󰅶 ", hl = "MiniIconsGrey" } },
  },
})

vim.keymap.set("n", "<leader>?", function()
  require("which-key").show({ global = false })
end, { desc = "Buffer keymaps" })

-- The keymap for "?" is already in config/keymaps.lua, but keeping it here
-- as a buffer-local helper is also fine. I'll stick to the one in keymaps.lua.
