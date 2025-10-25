-- Modern Statusline Components with Enhanced UI

local utils = require("utils")
local get_opt = vim.api.nvim_get_option_value
local hl_str = utils.hl_str
local get_hl_hex = utils.get_hl_hex

local M = {}

-- Sanitization helper
local function sanitize(str)
	if not str then
		return ""
	end
	return str:gsub("[^%w%s%-_.]", "")
end

-- Modern mode icons and colors
local mode_config = {
	["n"] = { icon = "󰋙 ", label = "N", hl = "%#StatusNormalInv#" },
	["i"] = { icon = "󰏪 ", label = "I", hl = "%#StatusInsertInv#" },
	["ic"] = { icon = "󰏪 ", label = "I", hl = "%#StatusInsertInv#" },
	["v"] = { icon = "󰈈 ", label = "V", hl = "%#StatusVisualInv#" },
	["V"] = { icon = "󰈈 ", label = "VL", hl = "%#StatusVisualInv#" },
	["\22"] = { icon = "󰈈 ", label = "VB", hl = "%#StatusVisualInv#" },
	["\22s"] = { icon = "󰈈 ", label = "VB", hl = "%#StatusVisualInv#" },
	["R"] = { icon = "󰑙 ", label = "R", hl = "%#StatusReplaceInv#" },
	["c"] = { icon = "󰘳 ", label = "C", hl = "%#StatusCommandInv#" },
	["t"] = { icon = "󰆍 ", label = "T", hl = "%#StatusCommandInv#" },
	["nt"] = { icon = "󰆍 ", label = "T", hl = "%#StatusCommandInv#" },
	["s"] = { icon = "󰒉 ", label = "S", hl = "%#StatusVisualInv#" },
}

-- Enhanced LSP function
function M.get_active_lsps()
	if not rawget(vim, "lsp") then
		return ""
	end

	local bufnr = vim.api.nvim_get_current_buf()
	local clients = vim.lsp.get_clients({ bufnr = bufnr })

	if #clients == 0 then
		return ""
	end

	local client_names = {}
	for _, client in ipairs(clients) do
		if client.name ~= "null-ls" and client.name ~= "copilot" then
			local clean_name = client.name:gsub("_", " "):gsub("^%l", string.upper)
			table.insert(client_names, clean_name)
		end
	end

	if #client_names == 0 then
		return ""
	end

	local lsp_string = table.concat(client_names, ", ")
	if #lsp_string > 25 then
		lsp_string = lsp_string:sub(1, 22) .. "..."
	end

	return M.get_or_create_hl("DiagnosticOk", "StatusLine") .. " 󰿘 " .. lsp_string .. " %* "
end

-- Enhanced Git functions
function M.get_git_branch()
	local branch = vim.b.gitsigns_head
	if not branch or branch == "" then
		local git_dir = vim.fn.finddir(".git", ".;")
		if git_dir ~= "" then
			local handle = io.popen("git branch --show-current 2>/dev/null")
			if handle then
				branch = handle:read("*a"):gsub("\n", "")
				handle:close()
			end
		end
	end

	if not branch or branch == "" then
		return ""
	end

	branch = sanitize(branch)
	if #branch > 20 then
		branch = branch:sub(1, 17) .. "..."
	end
	return M.get_or_create_hl("GitSignsAdd", "StatusLine") .. "  " .. branch .. " %* "
end

function M.get_git_added()
	local gitsigns = vim.b.gitsigns_status_dict
	if gitsigns and gitsigns.added and gitsigns.added > 0 then
		return M.get_or_create_hl("GitSignsAdd", "StatusLine") .. " 󰐙 " .. gitsigns.added .. "%* "
	end
	return ""
end

function M.get_git_changed()
	local gitsigns = vim.b.gitsigns_status_dict
	if gitsigns and gitsigns.changed and gitsigns.changed > 0 then
		return M.get_or_create_hl("GitSignsChange", "StatusLine") .. " 󰷈 " .. gitsigns.changed .. "%* "
	end
	return ""
end

function M.get_git_removed()
	local gitsigns = vim.b.gitsigns_status_dict
	if gitsigns and gitsigns.removed and gitsigns.removed > 0 then
		return M.get_or_create_hl("GitSignsDelete", "StatusLine") .. " 󰍶 " .. gitsigns.removed .. "%* "
	end
	return ""
end

function M.get_git_clean()
	local gitsigns = vim.b.gitsigns_status_dict
	if gitsigns then
		local added = gitsigns.added or 0
		local changed = gitsigns.changed or 0
		local removed = gitsigns.removed or 0

		if added == 0 and changed == 0 and removed == 0 then
			return M.get_or_create_hl("DiagnosticOk", "StatusLine") .. " 󰄬 Clean %* "
		end
	end
	return ""
end

-- Grouped git status with modern design
function M.git_status_enhanced()
	local branch = M.get_git_branch()
	if branch == "" then
		return ""
	end

	local clean = M.get_git_clean()
	if clean ~= "" then
		return branch .. clean
	end

	local added = M.get_git_added()
	local changed = M.get_git_changed()
	local removed = M.get_git_removed()

	if added == "" and changed == "" and removed == "" then
		return branch
	end

	return branch .. added .. changed .. removed
end

-- Modern mode indicator
function M.mode_modern()
	local mode = vim.fn.mode()
	local mode_info = mode_config[mode] or mode_config["n"]

	return mode_info.hl .. " " .. mode_info.icon .. mode_info.label .. " %#SLNormal#"
end

-- Existing functions (keeping compatibility)
function _G.get_lang_version(language)
	local script_path = "get_lang_version"
	local cmd = script_path .. " " .. language
	local result = vim.fn.system(cmd)

	if vim.v.shell_error ~= 0 then
		return "v?"
	end

	return result:gsub("^%s*(.-)%s*$", "%1")
end

_G.lang_versions = {}

vim.api.nvim_create_autocmd("LspAttach", {
	pattern = {
		"*.py",
		"*.lua",
		"*.go",
		"*.rs",
		"*.js",
		"*.ts",
		"*.jsx",
		"*.tsx",
		"*.java",
		"*.vue",
		"*ex",
		"*exs",
	},
	callback = function()
		local filetype = vim.bo.filetype
		local lang_v = _G.lang_versions[filetype]
		if not lang_v then
			_G.lang_versions[filetype] = _G.get_lang_version(filetype)
		end
	end,
	group = vim.api.nvim_create_augroup("idr4n/lang_version", { clear = true }),
})

local group_number = function(num, sep)
	if num < 999 then
		return tostring(num)
	else
		num = tostring(num)
		return num:reverse():gsub("(%d%d%d)", "%1" .. sep):reverse():gsub("^,", "")
	end
end

local nonprog_modes = {
	["markdown"] = true,
	["org"] = true,
	["text"] = true,
}

local isDark = vim.o.background == "dark"

local function get_theme_color(mode)
	local ok, astrotheme = pcall(require, "astrotheme")
	if not ok then
		return mode == "insert" and "#A6E3A1" or "#89B4FA"
	end

	local colors = astrotheme.config.palette or {}

	if mode == "insert" then
		return colors.green or "#A6E3A1"
	elseif mode == "visual" then
		return colors.purple or "#CBA6F7"
	elseif mode == "replace" then
		return colors.red or "#F38BA8"
	elseif mode == "command" then
		return colors.yellow or "#F9E2AF"
	else
		return colors.blue or "#89B4FA"
	end
end

M.colors = {
	yellow = "#E2B86B",
	red = isDark and "#DE6E7C" or "#D73A4A",
	blue = get_theme_color(),
	insert = get_theme_color("insert"),
	select = isDark and "#FCA7EA" or "#2188FF",
	stealth = isDark and "#4E546B" or "#A7ACBF",
	fg_hl = isDark and "#FFAFF3" or "#9A5BFF",
	bg_hl = get_hl_hex("Normal").bg and utils.lighten(get_hl_hex("Normal").bg, 0.93) or "none",
}

function M.decorator(opts)
	opts = vim.tbl_extend("force", { name = " ", align = "left" }, opts)
	local align = vim.tbl_contains({ "left", "right" }, opts.align) and opts.align or "left"
	local name = " " .. opts.name .. " "
	return (align == "right" and "%=" or "") .. hl_str("SLDecorator", name)
end

local statusline_hls = {}

function M.get_or_create_hl(hl_fg, hl_bg)
	hl_bg = hl_bg or "Normal"
	local sanitized_hl_fg = hl_fg:gsub("#", "")
	local sanitized_hl_bg = hl_bg:gsub("#", "")
	local hl_name = "SL" .. sanitized_hl_fg .. sanitized_hl_bg

	if not statusline_hls[hl_name] then
		local bg_hl
		if hl_bg:match("^#") then
			bg_hl = { bg = hl_bg }
		else
			bg_hl = vim.api.nvim_get_hl(0, { name = hl_bg })
		end

		local fg_hl
		if hl_fg:match("^#") then
			fg_hl = { fg = hl_fg }
		else
			fg_hl = vim.api.nvim_get_hl(0, { name = hl_fg })
		end

		if not bg_hl.bg then
			bg_hl = vim.api.nvim_get_hl(0, { name = "Statusline" })
		end
		if not fg_hl.fg then
			fg_hl = vim.api.nvim_get_hl(0, { name = "Statusline" })
		end

		vim.api.nvim_set_hl(0, hl_name, {
			bg = bg_hl.bg and (type(bg_hl.bg) == "string" and bg_hl.bg or ("#%06x"):format(bg_hl.bg)) or "none",
			fg = fg_hl.fg and (type(fg_hl.fg) == "string" and fg_hl.fg or ("#%06x"):format(fg_hl.fg)) or "none",
		})
		statusline_hls[hl_name] = true
	end

	return "%#" .. hl_name .. "#"
end

function M.reload_colors()
	statusline_hls = {}
	M.colors.bg_hl = get_hl_hex("Normal").bg and utils.lighten(get_hl_hex("Normal").bg, 0.93) or "none"
	M.colors.blue = get_theme_color()
	M.colors.insert = get_theme_color("insert")
end

function M.file_icon(opts)
	opts = opts or { mono = true }
	local devicons = require("nvim-web-devicons")
	local icon, icon_highlight_group = devicons.get_icon(vim.fn.expand("%:t"))
	if icon == nil then
		icon, icon_highlight_group = devicons.get_icon_by_filetype(vim.bo.filetype)
	end

	if icon == nil and icon_highlight_group == nil then
		icon = "󰈚"
		icon_highlight_group = "DevIconDefault"
	end

	if not vim.bo.modifiable then
		icon = ""
		icon_highlight_group = "SLNotModifiable"
	end

	return hl_str(icon_highlight_group, icon)
end

function M.fileinfo(opts)
	opts = opts or { add_icon = true }
	local icon = M.file_icon({ mono = false })
	local dir = utils.pretty_dirpath()()
	local pretty_dir = dir ~= "" and "󰉖 " .. dir or ""
	local path = vim.fn.expand("%:t")
	local name = (path == "" and "Empty ") or path:match("([^/\\]+)[/\\]*$")

	local modified = vim.bo.modified and hl_str("DiagnosticError", " ●") or ""

	return " "
		.. (dir ~= "" and pretty_dir .. "  " or "")
		.. (opts.add_icon and icon .. " " or "")
		.. name
		.. modified
		.. " %r%h%w "
end

local function get_vlinecount_str()
	local raw_count = vim.fn.line(".") - vim.fn.line("v")
	raw_count = raw_count < 0 and raw_count - 1 or raw_count + 1
	return group_number(math.abs(raw_count), ",")
end

function M.get_fileinfo_widget()
	local ft = get_opt("filetype", {})
	local lines = group_number(vim.api.nvim_buf_line_count(0), ",")
	local wc_table = vim.fn.wordcount()

	if not nonprog_modes[ft] then
		if not wc_table.visual_words or not wc_table.visual_chars then
			return table.concat({ hl_str("DiagnosticInfo", "󰦨"), " ", lines, " lines" })
		else
			return table.concat({
				hl_str("DiagnosticInfo", "󰩭"),
				" ",
				get_vlinecount_str(),
				" lines  ",
				group_number(wc_table.visual_chars, ","),
				" chars",
			})
		end
	end

	if not wc_table.visual_words or not wc_table.visual_chars then
		return table.concat({
			hl_str("DiagnosticInfo", "󰦨"),
			" ",
			lines,
			" lines  ",
			group_number(wc_table.words, ","),
			" words ",
		})
	else
		return table.concat({
			hl_str("DiagnosticInfo", "󰩭"),
			" ",
			get_vlinecount_str(),
			" lines  ",
			group_number(wc_table.visual_words, ","),
			" words  ",
			group_number(wc_table.visual_chars, ","),
			" chars",
		})
	end
end

function M.separator()
	return hl_str("Comment", " │ ")
end

function M.padding(nr)
	nr = nr or 1
	return string.rep(" ", nr)
end

function M.get_position()
	return " %3l:%-2c "
end

function M.search_count()
	if vim.v.hlsearch == 0 then
		return ""
	end

	local ok, count = pcall(vim.fn.searchcount, { recompute = true, maxcount = 500 })
	if (not ok or (count.current == nil)) or (count.total == 0) then
		return ""
	end

	if count.incomplete == 1 then
		return hl_str("SLMatches", " 󰍉 ?/? ")
	end

	local too_many = (">%d"):format(count.maxcount)
	local total = (((count.total > count.maxcount) and too_many) or count.total)

	return " " .. hl_str("SLMatches", (" 󰍉 %s/%s "):format(count.current, total))
end

function M.maximized_status()
	return vim.b.is_zoomed and hl_str("SLModified", " 󰊓  ") or ""
end

function M.show_macro_recording()
	local sep_left = M.get_or_create_hl("#ff6666", "StatusLine") .. ""
	local sep_right = M.get_or_create_hl("#ff6666", "StatusLine") .. "%* "

	local recording_register = vim.fn.reg_recording()
	if recording_register == "" then
		return ""
	else
		return sep_left .. M.get_or_create_hl("#212121", "#ff6666") .. "󰑋 " .. recording_register .. sep_right
	end
end

function M.lang_version()
	local filetype = vim.bo.filetype
	local lang_v = _G.lang_versions[filetype]
	return lang_v and M.get_or_create_hl("DiagnosticHint", "StatusLine") .. " (" .. filetype .. " " .. lang_v .. ") %*"
		or ""
end

function M.lsp_diagnostics_enhanced()
	local function get_severity(s)
		return #vim.diagnostic.get(0, { severity = s })
	end

	local result = {
		errors = get_severity(vim.diagnostic.severity.ERROR),
		warnings = get_severity(vim.diagnostic.severity.WARN),
		info = get_severity(vim.diagnostic.severity.INFO),
		hints = get_severity(vim.diagnostic.severity.HINT),
	}

	local total = result.errors + result.warnings + result.hints + result.info
	if not vim.bo.modifiable or total == 0 then
		return ""
	end

	local parts = {}
	if result.errors > 0 then
		table.insert(parts, M.get_or_create_hl("DiagnosticError", "StatusLine") .. " " .. result.errors .. "%* ")
	end
	if result.warnings > 0 then
		table.insert(parts, M.get_or_create_hl("DiagnosticWarn", "StatusLine") .. " " .. result.warnings .. "%* ")
	end
	if result.info > 0 then
		table.insert(parts, M.get_or_create_hl("DiagnosticInfo", "StatusLine") .. " " .. result.info .. "%* ")
	end
	if result.hints > 0 then
		table.insert(parts, M.get_or_create_hl("DiagnosticHint", "StatusLine") .. " " .. result.hints .. "%* ")
	end

	return table.concat(parts)
end

function M.scrollbar()
	local sbar_chars = { "▔", "🬂", "▀", "▄", "🬭", "▁" }
	if vim.env.TERM ~= "alacritty" then
		sbar_chars = { "▔", "🮂", "🬂", "🮃", "▀", "▄", "▃", "🬭", "▂", "▁" }
	end

	local cur_line = vim.api.nvim_win_get_cursor(0)[1]
	local lines = vim.api.nvim_buf_line_count(0)
	local i = math.floor((cur_line - 1) / lines * #sbar_chars) + 1
	local sbar = string.rep(sbar_chars[i], 2)

	return " " .. M.get_or_create_hl(get_hl_hex("Substitute").bg, M.colors.bg_hl) .. sbar .. "%* "
end

function M.scrollbar2()
	local sbar_chars = { "󰋙", "󰫃", "󰫄", "󰫅", "󰫆", "󰫇", "󰫈" }
	local cur_line = vim.api.nvim_win_get_cursor(0)[1]
	local lines = vim.api.nvim_buf_line_count(0)
	local i = math.floor((cur_line - 1) / lines * #sbar_chars) + 1
	local sbar = sbar_chars[i]

	return hl_str("DiagnosticInfo", " " .. sbar .. "  ")
end

function M.codeium_status()
	if vim.g.codeium_enabled then
		local status = vim.api.nvim_call_function("codeium#GetStatusString", {})
		local status_map = {
			[" ON"] = "󰚩",
			[" * "] = "󰔟 ",
		}
		status = status_map[status] or status
		return M.get_or_create_hl("SLBgNoneHl", "StatusLine") .. "  " .. status .. "%* "
	end
	return ""
end

function M.terminal_status()
	local is_terminal_open = false
	for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
		if vim.bo[buffer].buftype == "terminal" then
			is_terminal_open = true
		end
	end
	return is_terminal_open and M.get_or_create_hl("SLBgNoneHl", "StatusLine") .. " 󰆍 %* " or ""
end

function M.lsp_progress()
	local msg = require("utils.lsp_progress").get_progress()
	return msg ~= "" and (" " .. msg .. " ") or ""
end

function M.get_copilot_status()
	local copilot_loaded = package.loaded["copilot"] ~= nil
	local s = copilot_loaded and require("copilot-lualine") or nil
	local status = ""
	if copilot_loaded then
		if s and s.is_enabled() then
			status = " 󰚩  "
		end
		if s and s.is_loading() then
			status = " 󰔟 "
		end
		if s and s.is_error() then
			status = "  "
		end
	end
	return status
end

local zk_backlinks
local function get_zk_backlinks()
	if not zk_backlinks then
		local ok, module = pcall(require, "config.statusline.zk-backlinks")
		zk_backlinks = ok and module or false
	end
	return zk_backlinks
end

function M.BacklinkCount()
	local backlinks = get_zk_backlinks()
	if not backlinks then
		return ""
	end

	local count = backlinks.get_count()
	return count ~= "" and (" %s%s%%* "):format(M.get_or_create_hl("SLBgNoneHl", "StatusLine"), count) or ""
end

return M
