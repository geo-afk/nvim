return {
  {
    dir = "C:/Users/KoolAid/AppData/Local/nvim/lua/custom",
    name = "live-server",
    lazy = true,
    cmd = {
      "LiveServerRestart",
      "LiveServerStart",
      "LiveServerStop",
      "VimLeavePre",
    },
    config = function()
      require("custom.init").setup()
    end,
  },
}
