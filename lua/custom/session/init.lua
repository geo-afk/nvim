local nvim_utils = require("utils.nvim")
local Loader = require("custom.loader")

local api = vim.api
local fn = vim.fn

local M = {}

local defaults = {
	enabled = true,
	auto_restore = true,
	auto_save = true,
	notify = false,
	session_dir = vim.fs.joinpath(vim.fn.stdpath("state"), "session"),
}

local state = {
	config = nil,
	restoring = false,
	restored = false,
	saved_this_exit = false,
}

local function normalize(path)
	return vim.fs.normalize(path or "")
end

local function scope_key(scope)
	scope = normalize(scope ~= "" and scope or fn.getcwd())
	local hash = fn.sha256(scope):sub(1, 12)
	local tail = scope:gsub("^%a:[/\\]?", ""):gsub("[/\\]+", "_"):gsub("[^%w%._-]", "_"):sub(-50)
	return tail .. "-" .. hash
end

local function paths(scope)
	local dir = normalize(state.config.session_dir)
	local key = scope_key(scope)
	return {
		dir = dir,
		scope = normalize(scope ~= "" and scope or fn.getcwd()),
		key = key,
		meta = normalize(vim.fs.joinpath(dir, key .. "-session.json")),
	}
end

function M.get_paths()
	return vim.deepcopy(paths())
end

local function read_json(path)
	if fn.filereadable(path) ~= 1 then
		return nil
	end
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
	local tmp = path .. ".tmp"
	local fd = io.open(tmp, "wb")
	if not fd then
		return false
	end
	fd:write(encoded)
	fd:close()
	local renamed = os.rename(tmp, path)
	if not renamed then
		os.remove(tmp)
	end
	return renamed
end

local function is_clean_start_buffer(buf)
	if not (buf and api.nvim_buf_is_valid(buf)) then
		return false
	end
	return api.nvim_buf_get_name(buf) == "" and vim.bo[buf].buftype == "" and not vim.bo[buf].modified
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
	local current_buf = api.nvim_get_current_buf()
	local current_file = ""
	if api.nvim_buf_is_valid(current_buf) and vim.bo[current_buf].buftype == "" then
		current_file = normalize(api.nvim_buf_get_name(current_buf))
	end

	local ok_tab, tabline_buffers = pcall(require, "custom.tabline.buffers")
	local order = {}
	if ok_tab then
		for _, bufnr in ipairs(tabline_buffers.get_buffers()) do
			local name = api.nvim_buf_get_name(bufnr)
			if name ~= "" and vim.bo[bufnr].buftype == "" then
				order[#order + 1] = normalize(name)
			end
		end
	end

	local meta = {
		cwd = p.scope,
		tabline_order = order,
		current_file = current_file,
		saved_at = os.time(),
	}

	if write_json(p.meta, meta) then
		if not opts.silent then
			notify("Session saved")
		end
		return true
	end
	return false
end

function M.restore(opts)
	opts = opts or {}
	local p = paths(opts.scope)
	local meta = read_json(p.meta)
	if not meta then
		return false
	end

	state.restoring = true
	vim.g.SessionLoad = 1

	if meta.cwd and meta.cwd ~= "" and fn.isdirectory(meta.cwd) == 1 then
		pcall(api.nvim_set_current_dir, meta.cwd)
	end

	if type(meta.tabline_order) == "table" then
		for _, file in ipairs(meta.tabline_order) do
			if file ~= "" and fn.filereadable(file) == 1 then
				vim.cmd("silent! badd " .. fn.fnameescape(file))
			end
		end
		local ok_tab, tabline_buffers = pcall(require, "custom.tabline.buffers")
		if ok_tab and tabline_buffers.restore_order then
			tabline_buffers.restore_order(meta.tabline_order)
		end
	end

	if meta.current_file and meta.current_file ~= "" and fn.filereadable(meta.current_file) == 1 then
		vim.cmd("silent! edit " .. fn.fnameescape(meta.current_file))
	elseif type(meta.tabline_order) == "table" and #meta.tabline_order > 0 then
		vim.cmd("silent! edit " .. fn.fnameescape(meta.tabline_order[1]))
	end

	state.restoring = false
	state.restored = true
	vim.g.SessionLoad = nil

	vim.cmd("doautocmd SessionLoadPost")

	vim.schedule(function()
		for _, bufnr in ipairs(api.nvim_list_bufs()) do
			if is_clean_start_buffer(bufnr) and bufnr ~= api.nvim_get_current_buf() then
				pcall(api.nvim_buf_delete, bufnr, { force = true })
			end
		end
		vim.cmd("redrawtabline")
	end)

	if not opts.silent then
		notify("Session restored")
	end
	return true
end

function M.delete()
	local p = paths()
	if fn.filereadable(p.meta) == 1 then
		return os.remove(p.meta) ~= nil
	end
	return true
end

function M.restart()
	if M.save({ silent = true }) then
		vim.cmd("restart")
	end
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
	nvim_utils.command("SessionRestart", function()
		M.restart()
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
		Loader.later(function()
			vim.schedule(function()
				if fn.argc() == 0 and is_clean_start_buffer(api.nvim_get_current_buf()) then
					M.restore({ silent = true })
				end
			end)
		end)
	end

	vim.keymap.set("n", "<leader>nr", M.restart, { desc = "Restart Neovim" })
end

return M
