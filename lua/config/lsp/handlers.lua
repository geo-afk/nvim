local M = {}

-- Get capabilities with blink.cmp integration
function M.get_capabilities()
	local original_capabilities = vim.lsp.protocol.make_client_capabilities()
	return vim.tbl_deep_extend(
		"force",
		original_capabilities,
		require("blink.cmp").get_lsp_capabilities(original_capabilities)
	)
end

local lsp_rename = function()
	local curr_name = vim.fn.expand("<cword>")
	local value = vim.fn.input("LSP Rename: ", curr_name)
	local lsp_params = vim.lsp.util.make_position_params()

	if not value or #value == 0 or curr_name == value then
		return
	end

	-- request lsp rename
	lsp_params.newName = value
	vim.lsp.buf_request(0, "textDocument/rename", lsp_params, function(_, res, ctx, _)
		if not res then
			return
		end

		local client = vim.lsp.get_client_by_id(ctx.client_id)
		vim.lsp.util.apply_workspace_edit(res, client.offset_encoding)

		local changed_files_count = 0
		local changed_instances_count = 0

		if res.documentChanges then
			for _, changed_file in pairs(res.documentChanges) do
				changed_instances_count = changed_instances_count + #changed_file.edits
				changed_files_count = changed_files_count + 1
			end
		elseif res.changes then
			for _, changed_file in pairs(res.changes) do
				changed_instances_count = changed_instances_count + #changed_file
				changed_files_count = changed_files_count + 1
			end
		end

		-- compose the right print message
		vim.notify(
			string.format(
				"Renamed %s instance%s in %s file%s.",
				changed_instances_count,
				changed_instances_count == 1 and "" or "s",
				changed_files_count,
				changed_files_count == 1 and "" or "s"
			)
		)

		vim.cmd("silent! wa")
	end)
end

function M.setup_keymaps(args)
	local map = function(mode, keys, func, desc)
		vim.keymap.set(mode, keys, func, {
			buffer = args.buf,
			desc = "LSP: " .. desc,
		})
	end

	-- Hover info
	map("n", "K", function()
		vim.lsp.buf.hover({ border = "rounded" })
	end, "Show Hover Documentation")

	-- Declarations, Definitions, Implementations
	map("n", "gD", vim.lsp.buf.declaration, "Go to Declaration")
	map("n", "gd", function()
		require("utils.peek").peek_definition()
	end, "Peek Definition")

	map("n", "gi", function()
		require("utils.peek").peek_implementation()
	end, "Peek Implementation")

	-- Diagnostics
	map("n", "<leader>vd", vim.diagnostic.open_float, "Show Diagnostics Float")
	map("n", "gm", function()
		require("utils.peek").peek_diagnostics()
	end, "Peek Diagnostics")

	-- Signature help
	map("n", "<C-k>", vim.lsp.buf.signature_help, "Signature Help")

	-- Code Lens
	map({ "n", "x" }, "<leader>cc", vim.lsp.codelens.run, "Run Code Lens")
	map("n", "<leader>cC", vim.lsp.codelens.refresh, "Refresh & Display Code Lens")

	-- Inlay Hints
	map("n", "<leader>ci", function()
		local ih = vim.lsp.inlay_hint
		ih.enable(not ih.is_enabled())
	end, "Toggle Inlay Hints")

	-- Rename
	map("n", "grn", function()
		if vim.fn.exists("*lsp_rename") == 1 then
			lsp_rename()
		else
			vim.lsp.buf.rename()
		end
	end, "Rename Symbol")

	-- References & Symbols
	local tb = require("telescope.builtin")
	map("n", "gr", tb.lsp_references, "Go to References")
	map("n", "gO", tb.lsp_document_symbols, "Document Symbols")
	map("n", "gW", tb.lsp_dynamic_workspace_symbols, "Workspace Symbols")
	map("n", "grt", tb.lsp_type_definitions, "Type Definition")
end

return M
