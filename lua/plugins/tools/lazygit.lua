return {
	{
		"floaty-term",
		dir = vim.fn.stdpath("config") .. "/lua/custom/floating_terminal", -- Path to the directory containing floaty-term.lua
		config = function()
			require("custom.floating_terminal.terminal").setup({
				width_ratio = 0.7,
				height_ratio = 0.7,
				border = "rounded",
				title = "LazyGit",
			})
			vim.keymap.set("n", "<leader>tg", function()
				require("custom.floating_terminal.terminal").create_terminal("lazygit")
			end, { noremap = true, silent = true, desc = "Open lazygit in floating terminal" })
		end,
	},
}
