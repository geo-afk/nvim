return {
    'nvimdev/dashboard-nvim',
    event = 'VimEnter',
    config = function()
        require('dashboard').setup {
            theme = 'hyper',
            config = {
                week_header = {
                    enable = true,
                },
                shortcut = {
                    { desc = '󰊳 Update Plugins', group = '@property', action = 'Lazy update', key = 'u' },
                    {
                        desc = '🔍 Find Files',
                        group = 'Label',
                        action = 'Telescope find_files',
                        key = 'f',
                    },
                    {
                        desc = '📜 Recent Files',
                        group = 'DiagnosticHint',
                        action = 'Telescope oldfiles',
                        key = 'r',
                    },
                    {
                        desc = '⚙️ Config',
                        group = 'Number',
                        action = 'Telescope find_files cwd=~/AppData/Local/nvim',
                        key = 'c',
                    },
                    {
                        desc = '🚪 Quit',
                        group = 'Error',
                        action = 'qa',
                        key = 'q',
                    },
                },
                project = { enable = true, limit = 5, icon = '📁 ', label = 'Projects', action = 'Telescope find_files cwd=' },
                mru = { enable = true, limit = 8, icon = '📄 ', label = 'Recent Files', cwd_only = false },
                footer = { '', '🚀 Powered by nvimdev/dashboard-nvim' },
            },
            hide = {
                statusline = true,
                tabline = true,
                winbar = true,
            },
        }
    end,
    dependencies = { { 'nvim-tree/nvim-web-devicons' } }
}
