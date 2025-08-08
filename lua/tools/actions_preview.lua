-- lua/plugins/actions-preview.lua
return {
    {
        "aznhe21/actions-preview.nvim",
        event = "LspAttach",
        dependencies = {
            "nvim-telescope/telescope.nvim",
        },
        config = function()
            require("actions-preview").setup({
                -- Use Telescope as the backend for a better UI experience
                backend = "telescope",
                telescope = {
                    sorting_strategy = "ascending",
                    layout_strategy = "vertical",
                    layout_config = {
                        width = 0.8,
                        height = 0.9,
                        prompt_position = "top",
                        preview_cutoff = 20,
                        preview_height = function(_, _, max_lines)
                            return max_lines - 15
                        end,
                    },
                },
                -- Optional: Configure diff context lines
                diff = {
                    ctxlen = 3,
                },
            })
            -- Keybinding to trigger code actions preview
            vim.keymap.set({ "n", "v" }, "<leader>ca", require("actions-preview").code_actions, {
                desc = "Code Actions Preview",
            })
        end,
    },
}
