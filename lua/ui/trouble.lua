return {
    "folke/trouble.nvim",
    cmd = "Trouble",
    opts = {
        use_diagnostic_signs = true,
        auto_preview = true,
        group = true,
        signs = {
            error = "",
            warning = "",
            hint = "",
            information = "",
            other = "",
        },
        indent_lines = true,
        fold_open = "",
        fold_closed = "",
    },
    keys = {
        {
            "<leader>xx",
            function()
                require("trouble").toggle()
            end,
            desc = "Trouble: Toggle",
        },
        {
            "<leader>xw",
            function()
                require("trouble").toggle("workspace_diagnostics")
            end,
            desc = "Trouble: Workspace",
        },
        {
            "<leader>xd",
            function()
                require("trouble").toggle("document_diagnostics")
            end,
            desc = "Trouble: Document",
        },
        {
            "<leader>xq",
            function()
                require("trouble").toggle("quickfix")
            end,
            desc = "Trouble: Quickfix",
        },
        {
            "<leader>xl",
            function()
                require("trouble").toggle("loclist")
            end,
            desc = "Trouble: LocList",
        },
    },
}
