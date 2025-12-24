-- Load the toggle module and create the command

vim.api.nvim_create_user_command('ToggleAngularFile', toggle_angular_file, {})

vim.keymap.set('n', '<leader>at', ':ToggleAngularFile<CR>', { buffer = true, desc = 'Toggle between Angular .ts and .html' })
