vim.pack.add({
  {
    src = "https://github.com/geo-afk/gotools",
  },
})

local ok, gotools = pcall(require, "gotools")
if not ok then
  return
end

gotools.setup()

local function setup_go_keymaps(buf)
  local opts = {
    silent = true,
    noremap = true,
    -- buffer = buf,
  }

  local function map(lhs, cmd, desc)
    vim.keymap.set("n", lhs, "<cmd>" .. cmd .. "<CR>", vim.tbl_extend("force", opts, { desc = desc }))
  end

  -- ── Test Generation (gotests) ───────────────────────────────────────────
  map("<leader>itf", "GoTestGenFunc", "Generate test for func under cursor")
  map("<leader>ita", "GoTestGenFile", "Generate tests for whole file")
  map("<leader>itw", "GoTestGenWrite", "Generate & write tests directly")

  -- ── Test Running (gotestsum) ────────────────────────────────────────────
  map("<leader>itr", "GoTest", "Run tests (gotestsum UI)")
  map("<leader>itF", "GoTestFunc", "Run test under cursor")
  map("<leader>itA", "GoTestAll", "Run all tests")
  map("<leader>ith", "GoTestHistory", "Test run history")

  -- ── Struct Tools ────────────────────────────────────────────────────────
  map("<leader>ims", "GoFillStruct", "Fill struct with zero values")
  map("<leader>imw", "GoFillSwitch", "Fill switch with all cases")
  map("<leader>imt", "GoModifyTags", "Interactive tag editor")
  map("<leader>ime", "GoIfErr", "Insert if err check at cursor")

  -- ── Toolchain ───────────────────────────────────────────────────────────
  map("<leader>ib", "GoBuild", "go build")
  map("<leader>ir", "GoRun", "go run current file")
  map("<leader>iR", "GoRunPkg", "go run current package")
  map("<leader>if", "GoFmt", "gofmt current file")
  map("<leader>ii", "GoImports", "Organize imports")
  map("<leader>id", "GoDoc", "go doc symbol under cursor")
  map("<leader>iv", "GoVet", "go vet")
  map("<leader>iG", "GoGenerate", "go generate")
  map("<leader>iM", "GoModTidy", "go mod tidy")

  -- ── Security ────────────────────────────────────────────────────────────
  map("<leader>iV", "GoVulnCheck", "govulncheck vulnerability scan")

  -- ── Terminal & Status ───────────────────────────────────────────────────
  map("<leader>iT", "GoTerminal", "Open persistent Go terminal")
  map("<leader>is", "GotoolsStatus", "Tool status dashboard")
end

setup_go_keymaps()
--
-- vim.api.nvim_create_autocmd("FileType", {
--   pattern = "go",
--   callback = function(ev)
--     setup_go_keymaps(ev.buf)
--   end,
-- })
