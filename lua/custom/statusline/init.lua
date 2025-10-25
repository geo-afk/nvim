-- Modern Statusline Configuration with Enhanced UI

local ut = require("utils")
local c = require("custom.statusline.components")
local colors = c.colors
local normal_hl = vim.api.nvim_get_hl(0, { name = "Normal" })
local statusline_hl = vim.api.nvim_get_hl(0, { name = "StatusLine" })
local fg_lighten = normal_hl.bg and ut.darken(string.format("#%06x", normal_hl.bg), 0.6) or colors.stealth

-- Enhanced modern color palette
local modern_colors = {
	accent_blue = "#7AA2F7",
	accent_green = "#9ECE6A",
	accent_purple = "#BB9AF7",
	accent_orange = "#FF9E64",
	accent_cyan = "#7DCFFF",
	subtle_fg = "#565F89",
	border = "#414868",
}

-- Create sleek highlight groups with modern aesthetics
vim.api.nvim_set_hl(0, "SLBgNoneHl", { fg = colors.fg_hl, bg = "none" })
vim.api.nvim_set_hl(0, "StatusReplace", { bg = colors.red, fg = statusline_hl.bg, bold = true })
vim.api.nvim_set_hl(0, "StatusInsert", { bg = colors.insert, fg = statusline_hl.bg, bold = true })
vim.api.nvim_set_hl(0, "StatusVisual", { bg = colors.select, fg = statusline_hl.bg, bold = true })
vim.api.nvim_set_hl(0, "StatusNormal", { bg = colors.blue, fg = statusline_hl.bg, bold = true })
vim.api.nvim_set_hl(0, "StatusCommand", { bg = colors.yellow, fg = statusline_hl.bg, bold = true })
vim.api.nvim_set_hl(0, "StatusReplaceInv", { fg = colors.red, bg = statusline_hl.bg, bold = true })
vim.api.nvim_set_hl(0, "StatusInsertInv", { fg = colors.insert, bg = statusline_hl.bg, bold = true })
vim.api.nvim_set_hl(0, "StatusVisualInv", { fg = colors.select, bg = statusline_hl.bg, bold = true })
vim.api.nvim_set_hl(0, "StatusNormalInv", { fg = colors.blue, bg = statusline_hl.bg, bold = true })
vim.api.nvim_set_hl(0, "StatusCommandInv", { fg = colors.yellow, bg = statusline_hl.bg, bold = true })
vim.api.nvim_set_hl(0, "SLNotModifiable", { fg = colors.yellow, bg = statusline_hl.bg })
vim.api.nvim_set_hl(0, "SLNormal", { fg = fg_lighten, bg = statusline_hl.bg })
vim.api.nvim_set_hl(0, "SLModified", { fg = "#FF7EB6", bg = statusline_hl.bg })
vim.api.nvim_set_hl(0, "SLMatches", { fg = colors.bg_hl, bg = colors.fg_hl, bold = true })
vim.api.nvim_set_hl(0, "SLDecorator", { fg = "#1F2335", bg = modern_colors.accent_blue, bold = true })
vim.api.nvim_set_hl(0, "SLSection", { fg = modern_colors.subtle_fg, bg = statusline_hl.bg })

-- Create a visual divider
local function divider()
	return c.get_or_create_hl(modern_colors.border, "StatusLine") .. " ▏%* "
end

-- Status line function with modern, clean layout
function Status_line()
	local filetype = vim.bo.filetype
	local filetypes = {
		"neo-tree",
		"minifiles",
		"NvimTree",
		"oil",
		"TelescopePrompt",
		"fzf",
		"snacks_picker_input",
	}

	-- Special handling for file explorers
	if vim.tbl_contains(filetypes, filetype) then
		local home_dir = os.getenv("HOME") or os.getenv("USERPROFILE")
		local dir

		if filetype == "NvimTree" then
			local api = require("nvim-tree.api")
			local node = api.tree.get_node_under_cursor()
			dir = node.absolute_path
		else
			dir = vim.fn.getcwd()
		end

		if home_dir then
			dir = dir:gsub("^" .. home_dir, "~")
		end

		local ft = (filetype == "snacks_picker_input" and "Snacks") or filetype:sub(1, 1):upper() .. filetype:sub(2)

		return c.decorator({ name = ft .. ": " .. dir, align = "left" })
	end

	-- Modern statusline layout
	local components = {
		-- Left section: Mode + File info
		c.padding(),
		c.mode_modern(),
		c.padding(),
		c.fileinfo({ add_icon = true }),
		c.BacklinkCount(),

		-- Center section: Status indicators
		"%=",
		c.maximized_status(),
		c.show_macro_recording(),
		c.lsp_progress(),
		"%=",

		-- Right section: Language, LSP, Git, Diagnostics
		_G.show_more_info and c.lang_version() or "",
		c.get_active_lsps(), -- Always show active LSPs

		-- Git information (enhanced)
		c.git_status_enhanced(),

		-- Separators and status indicators
		c.terminal_status(),
		c.codeium_status(),
		c.get_copilot_status(),

		-- Search and file stats
		c.search_count(),
		c.padding(),
		divider(),
		c.get_fileinfo_widget(),
		c.padding(),

		-- Position and filetype
		divider(),
		c.get_position(),
		c.padding(),
		c.get_or_create_hl(modern_colors.accent_cyan, "StatusLine") .. " " .. vim.bo.filetype:upper() .. " %*",
		c.padding(2),

		-- Scrollbar and diagnostics
		c.scrollbar2(),
		c.padding(),

		-- Diagnostics with modern icons
		c.lsp_diagnostics_enhanced(),
		c.padding(),
	}

	return table.concat(components)
end

-- Alternative compact layout (toggle with _G.compact_statusline)
function Status_line_compact()
	local filetype = vim.bo.filetype
	local filetypes = {
		"neo-tree",
		"minifiles",
		"NvimTree",
		"oil",
		"TelescopePrompt",
		"fzf",
		"snacks_picker_input",
	}

	if vim.tbl_contains(filetypes, filetype) then
		local home_dir = os.getenv("HOME") or os.getenv("USERPROFILE")
		local dir

		if filetype == "NvimTree" then
			local api = require("nvim-tree.api")
			local node = api.tree.get_node_under_cursor()
			dir = node.absolute_path
		else
			dir = vim.fn.getcwd()
		end

		if home_dir then
			dir = dir:gsub("^" .. home_dir, "~")
		end

		local ft = (filetype == "snacks_picker_input" and "Snacks") or filetype:sub(1, 1):upper() .. filetype:sub(2)

		return c.decorator({ name = ft .. ": " .. dir, align = "left" })
	end

	-- Compact layout - minimal but informative
	local components = {
		c.padding(),
		c.mode_modern(),
		c.fileinfo({ add_icon = true }),

		"%=",
		c.show_macro_recording(),
		c.lsp_progress(),
		"%=",

		c.get_active_lsps(),
		c.git_status_enhanced(),
		c.codeium_status(),
		c.get_copilot_status(),

		divider(),
		c.get_position(),
		c.padding(),
		vim.bo.filetype:upper(),
		c.padding(),
		c.lsp_diagnostics_enhanced(),
		c.padding(),
	}

	return table.concat(components)
end

-- Set the active statusline (use compact mode if enabled)
vim.o.statusline = _G.compact_statusline and '%!luaeval("Status_line_compact()")' or '%!luaeval("Status_line()")'

-- Toggle functions for convenience
_G.toggle_statusline_mode = function()
	_G.compact_statusline = not _G.compact_statusline
	vim.o.statusline = _G.compact_statusline and '%!luaeval("Status_line_compact()")' or '%!luaeval("Status_line()")'
	vim.cmd("redrawstatus")
end

_G.toggle_statusline_info = function()
	_G.show_more_info = not _G.show_more_info
	vim.cmd("redrawstatus")
end

-- Keybindings for toggling (optional - add to your keymaps)
-- vim.keymap.set('n', '<leader>us', function() _G.toggle_statusline_mode() end,
--   { desc = 'Toggle statusline mode' })
-- vim.keymap.set('n', '<leader>ui', function() _G.toggle_statusline_info() end,
--   { desc = 'Toggle statusline info' })
