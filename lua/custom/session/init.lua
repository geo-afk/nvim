local nvim_utils = require("utils.nvim")
local Loader = require("custom.loader")

local api = vim.api
local fn = vim.fn

local M = {}

local defaults = {
	enabled = true,
	auto_restore = true,
	auto_save = true,
	notify = true,
	session_dir = vim.fs.joinpath(vim.fn.stdpath("state"), "session"),
}

local state = {
	config = nil,
	restoring = false,
	restored = false,
	saved_this_exit = false,
	session_dir = nil,
	key_cache = {},
}

local function normalize(path)
	if not path or path == "" then
		return ""
	end
	if not path:find("\\") then
		return path
	end
	return path:gsub("\\", "/")
end

local function scope_key(scope)
	scope = scope ~= "" and scope or fn.getcwd()
	if state.key_cache[scope] then
		return scope, state.key_cache[scope]
	end

	local norm = normalize(scope)
	local hash = fn.sha256(norm):sub(1, 12)
	local tail = norm:gsub("^%a:[/\\]?", ""):gsub("[/\\]+", "_"):gsub("[^%w%._-]", "_"):sub(-50)
	local key = tail .. "-" .. hash
	state.key_cache[scope] = key
	return norm, key
end

local function paths(scope)
	if not state.session_dir then
		state.session_dir = normalize(state.config.session_dir)
	end
	local dir = state.session_dir
	local norm_scope, key = scope_key(scope or "")

	return {
		dir = dir,
		scope = norm_scope,
		key = key,
		vim = dir .. "/" .. key .. ".vim",
		meta = dir .. "/" .. key .. ".json",
	}
end

function M.get_paths()
	return paths()
end

local function read_json(path)
	local fd = io.open(path, "rb")
	if not fd then
		return nil
	end
	local raw = fd:read("*a")
	fd:close()
	local ok, decoded = pcall(vim.json.decode, raw)
	return ok and decoded or nil
end

local function write_json(path, value)
	local ok, encoded = pcall(vim.json.encode, value)
	if not ok then
		return false
	end
	local dir = fn.fnamemodify(path, ":h")
	if fn.isdirectory(dir) ~= 1 then
		fn.mkdir(dir, "p")
	end
	local fd = io.open(path, "wb")
	if not fd then
		return false
	end
	fd:write(encoded)
	fd:close()
	return true
end

local function is_clean_start_buffer(buf)
	if not (buf and api.nvim_buf_is_valid(buf)) then
		return false
	end
	-- Use nvim_get_option_value for better performance in loops
	local bt = vim.api.nvim_get_option_value("buftype", { buf = buf })
	local mod = vim.api.nvim_get_option_value("modified", { buf = buf })
	return api.nvim_buf_get_name(buf) == "" and bt == "" and not mod
end

local function notify(msg, level)
	if state.config.notify then
		vim.notify(msg, level or vim.log.levels.INFO, { title = "Session" })
	end
end

function M.save(opts)
	opts = opts or {}
	if not state.config.enabled or state.restoring then
		return false
	end

	local p = paths(opts.scope)
	local dir = p.dir
	if fn.isdirectory(dir) ~= 1 then
		fn.mkdir(dir, "p")
	end

	-- 1. Save buffers and tabpages via mksession
	-- Temporarily strict sessionoptions for speed and cleanliness
	local old_ssop = vim.opt.sessionoptions:get()
	vim.opt.sessionoptions = { "buffers", "tabpages" }
	vim.cmd("silent! mksession! " .. fn.fnameescape(p.vim))
	vim.opt.sessionoptions = old_ssop

	-- 2. Save custom tab order and metadata via JSON
	local ok_tab, tabline_buffers = pcall(require, "custom.tabline.buffers")
	local order = {}
	if ok_tab then
		for _, bufnr in ipairs(tabline_buffers.get_buffers()) do
			local name = api.nvim_buf_get_name(bufnr)
			if name ~= "" then
				local bt = vim.api.nvim_get_option_value("buftype", { buf = bufnr })
				if bt == "" then
					order[#order + 1] = normalize(name)
				end
			end
		end
	end

	local current_buf = api.nvim_get_current_buf()
	local meta = {
		tabline_order = order,
		current_file = normalize(api.nvim_buf_get_name(current_buf)),
		saved_at = os.time(),
	}

	if write_json(p.meta, meta) then
		if not opts.silent then
			notify("Session saved: " .. p.scope)
		end
		return true
	end
	return false
end

function M.restore(opts)
	opts = opts or {}
	local p = paths(opts.scope)
	if fn.filereadable(p.vim) ~= 1 then
		return false
	end

	state.restoring = true
	vim.g.SessionLoad = 1

	-- 1. Restore layout and buffers
	local ok, err = pcall(vim.cmd, "silent! source " .. fn.fnameescape(p.vim))
	
	if not ok then
		state.restoring = false
		vim.g.SessionLoad = nil
		notify("Failed to restore session: " .. tostring(err), vim.log.levels.ERROR)
		return false
	end

	-- 2. Restore custom tab order from JSON
	local meta = read_json(p.meta)
	if meta and type(meta.tabline_order) == "table" then
		local ok_tab, tabline_buffers = pcall(require, "custom.tabline.buffers")
		if ok_tab and tabline_buffers.restore_order then
			tabline_buffers.restore_order(meta.tabline_order)
		end
	end

	state.restoring = false
	state.restored = true
	vim.g.SessionLoad = nil

	vim.cmd("doautocmd SessionLoadPost")

	-- Cleanup empty start buffers
	-- Using a small delay instead of immediate schedule to allow UI to breathe
	vim.defer_fn(function()
		local current = api.nvim_get_current_buf()
		for _, bufnr in ipairs(api.nvim_list_bufs()) do
			if bufnr ~= current and is_clean_start_buffer(bufnr) then
				pcall(api.nvim_buf_delete, bufnr, { force = true })
			end
		end
		vim.cmd("redrawtabline")
	end, 50)

	if not opts.silent then
		notify("Session restored: " .. p.scope)
	end
	return true
end

function M.delete()
	local p = paths()
	local deleted = false
	if fn.filereadable(p.vim) == 1 then
		os.remove(p.vim)
		deleted = true
	end
	if fn.filereadable(p.meta) == 1 then
		os.remove(p.meta)
		deleted = true
	end
	if deleted then
		notify("Session deleted")
	end
	return true
end

function M.setup(opts)
	state.config = vim.tbl_deep_extend("force", defaults, opts or {})
	local group = nvim_utils.augroup("CustomSession")

	nvim_utils.command("SessionSave", function()
		M.save()
	end)
	nvim_utils.command("SessionRestore", function()
		M.restore()
	end)
	nvim_utils.command("SessionDelete", function()
		M.delete()
	end)

	if state.config.auto_save then
		nvim_utils.autocmd({ "VimLeavePre", "UILeave" }, {
			group = group,
			callback = function()
				if not state.saved_this_exit and #api.nvim_list_uis() > 0 then
					state.saved_this_exit = true
					M.save({ silent = true })
				end
			end,
		})
	end

	if state.config.auto_restore then
		-- Trigger restore on VimEnter to ensure everything is ready
		-- but use Loader.later to keep the initial dashboard snappy if present.
		Loader.later(function()
			if fn.argc() == 0 and is_clean_start_buffer(api.nvim_get_current_buf()) then
				M.restore({ silent = true })
			end
		end)
	end
end

return M
