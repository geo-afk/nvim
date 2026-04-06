-- =============================================================================
--  plugins/treesitter.lua  ·  nvim-treesitter
-- =============================================================================

local utils_ok, utils = pcall(require, "utils")
utils = utils_ok and utils or {}

vim.pack.add({
	{
		src = "https://github.com/nvim-treesitter/nvim-treesitter",
		build = ":TSUpdate",
	},
})

local ok, ts = pcall(require, "nvim-treesitter.configs")
if not ok then
	return
end

ts.setup({
	ensure_installed = {
		"lua",
		"typescript",
		"tsx",
		"javascript",
		"go",
		"json",
		"jsonc",
		"html",
		"css",
		"scss",
		"markdown",
		"markdown_inline",
		"regex",
		"vim",
		"vimdoc",
		"query",
		"toml",
		"sql",
		"angular",
	},
	auto_install = true,
	highlight = { enable = true, additional_vim_regex_highlighting = false },
	indent = { enable = true, disable = { "ruby" } },

	-- [0.12] incremental_selection also powered by LSP selectionRange (v_an/v_in)
	incremental_selection = {
		enable = true,
		keymaps = {
			init_selection = "gnn",
			node_incremental = "grn",
			scope_incremental = "grc",
			node_decremental = "grm",
		},
	},
})
local function is_angular_project()
	if type(utils.is_angular_project) == "function" then
		return utils.is_angular_project()
	end
	return false
end

local function should_use_angular_parser(path)
	if not path or type(path) ~= "string" then
		return false
	end
	if not path:match("/src/app/") then
		return false
	end
	return is_angular_project()
end

vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
	pattern = { "*.component.html", "*.html" },
	callback = function(args)
		local buf = args.buf
		local path = vim.api.nvim_buf_get_name(buf)
		if should_use_angular_parser(path) then
			local okay, _ = pcall(vim.treesitter.get_parser, buf, "angular")
			if okay then
				pcall(vim.treesitter.start, buf, "angular")
			else
				pcall(vim.treesitter.start, buf, "html")
			end
		end
	end,
	desc = "Apply Angular Treesitter parser or fallback",
})
