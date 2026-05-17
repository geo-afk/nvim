vim.pack.add({
  {
    src = "https://github.com/geo-afk/gotools",
  },
})

local ok, go_tool = pcall(require, "gotools")

if ok then
  go_tool.setup({
    tools = {
      gotests = { bin = "gotests", install = "go install github.com/cweill/gotests/gotests@latest" },
      gomodifytags = { bin = "gomodifytags", install = "go install github.com/fatih/gomodifytags@latest" },
      iferr = { bin = "iferr", install = "go install github.com/koron/iferr@latest" },
      gotestsum = { bin = "gotestsum", install = "go install gotest.tools/gotestsum@latest" },
      fillstruct = {
        bin = "fillstruct",
        install = "go install github.com/davidrjenni/reftools/cmd/fillstruct@latest",
      },
      fillswitch = {
        bin = "fillswitch",
        install = "go install github.com/davidrjenni/reftools/cmd/fillswitch@latest",
      },
      govulncheck = { bin = "govulncheck", install = "go install golang.org/x/vuln/cmd/govulncheck@latest" },
    },
    ui = {
      border = "rounded",
      blend = 10,
      width_ratio = 0.6,
      height_ratio = 0.6,
      preview_ratio = 0.45,
    },
    gotests = {
      template_dir = nil,
      named_return = false,
      parallel = false,
      subtests = true,
    },
    gotestsum = {
      format = "testname",
      rerun_fails = 1,
      watch = false,
    },
    gomodifytags = {
      transform = "snakecase",
      skip_unexported = false,
    },
    keymaps = {
      enable = true,
      prefix = "<leader>i",
    },
    terminal = {
      direction = "float",
      persist = true,
    },
  })
end
