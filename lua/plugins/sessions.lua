return {
	'rmagatti/auto-session',
	lazy = false,
	---@type AutoSession.Config
	opts = {
		-- log_level = "debug",
		suppressed_dirs = { '~/', '~/Documents', '~/Desktop', '~/Music', '/' },
		session_lens = {
			picker = "telescope", -- "telescope"|"snacks"|"fzf"|"select"|nil Pickers are detected automatically but you can also manually choose one. Falls back to vim.ui.select
			load_on_setup = true, -- Enable Telescope extension registration at startup for :Telescope session-lens
			previewer = "summary", -- Use session summary previews for a clean overview
			mappings = {
				-- Mode can be a string or a table, e.g. {"i", "n"} for both insert and normal mode
				delete_session = { "i", "<C-d>" },
				alternate_session = { "i", "<C-s>" },
				copy_session = { "i", "<C-y>" },
			},
			-- picker_opts = {
			-- 	-- Apply a modern dropdown theme for compact, floating UI
			-- 	theme = "dropdown",
			-- 	-- Enable borders for a polished look
			-- 	border = true,
			-- 	-- Customize borders to rounded for a modern aesthetic (optional; requires Neovim 0.10+)
			-- 	borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
			-- 	-- Layout configuration for a neat, centered, non-intrusive picker
			-- 	layout_config = {
			-- 		width = 0.5, -- 80% of window width
			-- 		height = 0.5, -- 50% of window height
			-- 		horizontal = "center", -- Center horizontally
			-- 		vertical = "center", -- Center vertically
			-- 		prompt_position = "top", -- Place prompt at the top for better flow
			-- 	},
			-- 	-- Preview configuration for balanced session previews
			-- 	preview = {
			-- 		width = 0.5, -- 50% width for previews (e.g., session summary)
			-- 	},
			-- },
		},
	},
	config = function(_, opts)
		-- Setup with customized options
		require('auto-session').setup(opts)
		-- Keymaps for sessions
		local map = function(keys, cmd, desc)
			vim.keymap.set('n', keys, cmd, { desc = desc })
		end
		map('<leader>ws', '<cmd>AutoSession save<CR>', 'Save session')
		map('<leader>wr', '<cmd>AutoSession restore<CR>', 'Restore last session')
		map('<leader>wd', '<cmd>AutoSession delete<CR>', 'Delete current session')
		map('<leader>wf', '<cmd>AutoSession search<CR>', 'Search for sessions')
	end,
}
