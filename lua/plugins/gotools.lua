vim.pack.add({
  {
    src = "https://github.com/geo-afk/gotools",
  },
})

local ok_gotools, gotools = pcall(require, "gotools")
if not ok_gotools then
  vim.notify("failed to load gotools", vim.log.levels.ERROR)
  return
end

local ok_wk, which_key = pcall(require, "which-key")
if not ok_wk then
  vim.notify("failed to load which-key", vim.log.levels.ERROR)
  return
end

gotools.setup()

local function setup_go_keymaps(buf)
  local opts = {
    silent = true,
    noremap = true,
    buffer = buf,
  }

  local function map(lhs, cmd, desc)
    vim.keymap.set("n", lhs, "<cmd>" .. cmd .. "<CR>", vim.tbl_extend("force", opts, { desc = desc }))
  end

  -- ── Test Generation ──────────────────────────────────────────────────────
  map("<leader>itf", "GoTestGenFunc", "Generate test for func")
  map("<leader>ita", "GoTestGenFile", "Generate tests for file")
  map("<leader>itw", "GoTestGenWrite", "Generate & write tests")

  -- ── Test Running ─────────────────────────────────────────────────────────
  map("<leader>itr", "GoTest", "Run tests")
  map("<leader>itF", "GoTestFunc", "Run test under cursor")
  map("<leader>itA", "GoTestAll", "Run all tests")
  map("<leader>ith", "GoTestHistory", "Test history")

  -- ── Struct Tools ─────────────────────────────────────────────────────────
  map("<leader>ims", "GoFillStruct", "Fill struct")
  map("<leader>imw", "GoFillSwitch", "Fill switch")
  map("<leader>imt", "GoModifyTags", "Modify tags")
  map("<leader>ime", "GoIfErr", "Insert if err")

  -- ── Toolchain ────────────────────────────────────────────────────────────
  map("<leader>ib", "GoBuild", "Go build")
  map("<leader>ir", "GoRun", "Go run file")
  map("<leader>iR", "GoRunPkg", "Go run package")
  map("<leader>if", "GoFmt", "Go fmt")
  map("<leader>ii", "GoImports", "Go imports")
  map("<leader>id", "GoDoc", "Go doc")
  map("<leader>iv", "GoVet", "Go vet")
  map("<leader>iG", "GoGenerate", "Go generate")
  map("<leader>iM", "GoModTidy", "Go mod tidy")

  -- ── Security ─────────────────────────────────────────────────────────────
  map("<leader>iV", "GoVulnCheck", "Go vulnerability scan")

  -- ── Terminal & Status ────────────────────────────────────────────────────
  map("<leader>iT", "GoTerminal", "Go terminal")
  map("<leader>is", "GotoolsStatus", "Gotools status")

  which_key.add({
    { "<leader>i", group = "Go Tooling" },

    { "<leader>it", group = "Tests" },
    { "<leader>itf", desc = "Generate test for func" },
    { "<leader>ita", desc = "Generate tests for file" },
    { "<leader>itw", desc = "Generate & write tests" },
    { "<leader>itr", desc = "Run tests" },
    { "<leader>itF", desc = "Run test under cursor" },
    { "<leader>itA", desc = "Run all tests" },
    { "<leader>ith", desc = "Test history" },

    { "<leader>im", group = "Struct Tools" },
    { "<leader>ims", desc = "Fill struct" },
    { "<leader>imw", desc = "Fill switch" },
    { "<leader>imt", desc = "Modify tags" },
    { "<leader>ime", desc = "Insert if err" },

    { "<leader>ib", desc = "Go build" },
    { "<leader>ir", desc = "Go run file" },
    { "<leader>iR", desc = "Go run package" },
    { "<leader>if", desc = "Go fmt" },
    { "<leader>ii", desc = "Go imports" },
    { "<leader>id", desc = "Go doc" },
    { "<leader>iv", desc = "Go vet" },
    { "<leader>iG", desc = "Go generate" },
    { "<leader>iM", desc = "Go mod tidy" },

    { "<leader>iV", desc = "Go vulnerability scan" },

    { "<leader>iT", desc = "Go terminal" },
    { "<leader>is", desc = "Gotools status" },
  }, {
    buffer = buf,
  })
end

local group = vim.api.nvim_create_augroup("GoToolsKeymaps", { clear = true })

vim.api.nvim_create_autocmd("FileType", {
  group = group,
  pattern = "go",
  callback = function(ev)
    setup_go_keymaps(ev.buf)
  end,
})

-- Handle already-open Go buffers
for _, buf in ipairs(vim.api.nvim_list_bufs()) do
  if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype == "go" then
    setup_go_keymaps(buf)
  end
end
