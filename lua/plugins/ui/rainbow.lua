return {
	"HiPhish/rainbow-delimiters.nvim",
	event = "VeryLazy",
	config = function()
		require("rainbow-delimiters.setup").setup({
			highlight = {
				"RainbowDelimiters1",
				"RainbowDelimiters2",
				"RainbowDelimiters3",
				"RainbowDelimiters4",
				"RainbowDelimiters5",
				"RainbowDelimiters6",
				"RainbowDelimiters7",
			},
		})
	end,
}
