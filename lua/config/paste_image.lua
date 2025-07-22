-- lua/config/paste_image.lua
local M = {}

function M.paste_clipboard_image()
  -- Prompt for file path with a default directory (e.g., current working directory)
  local default_dir = vim.fn.getcwd() .. "/"
  local file_path = vim.fn.input("Save image as (e.g. image.png): ", default_dir, "file")
  if file_path == "" then
    print("Cancelled")
    return
  end

  -- Ensure the file has a .png extension
  if not file_path:match("%.png$") then
    file_path = file_path .. ".png"
  end

  local os_name = vim.loop.os_uname().sysname
  local cmd
  local shell

  if os_name == "Linux" then
    -- Check if xclip is installed
    if vim.fn.executable("xclip") == 0 then
      print("Error: xclip is not installed")
      return
    end
    cmd = string.format("xclip -selection clipboard -t image/png -o > %q", file_path)
    shell = "sh"
  elseif os_name == "Darwin" then
    -- Check if pngpaste is installed
    if vim.fn.executable("pngpaste") == 0 then
      print("Error: pngpaste is not installed")
      return
    end
    cmd = string.format("pngpaste %q", file_path)
    shell = "sh"
  elseif os_name == "Windows_NT" then
    -- Check if PowerShell is available
    if vim.fn.executable("powershell") == 0 then
      print("Error: PowerShell is not available")
      return
    end
    cmd = string.format(
      [[powershell -command "$img = Get-Clipboard -Format Image; if ($img -ne $null) { $img.Save('%s', 'Png') } else { exit 1 }" ]],
      file_path
    )
    shell = "cmd"
  else
    print("Unsupported OS: " .. os_name)
    return
  end

  -- Run the command asynchronously
  vim.system({ shell, "-c", cmd }, { text = true }, function(result)
    vim.schedule(function()
      if result.code == 0 then
        print("Image saved to " .. file_path)
      else
        print("Error saving image: " .. (result.stderr or "Unknown error"))
      end
    end)
  end)
end

return M
