-- Smart line breaking function for Neovim written in Lua
-- Breaks long lines at a specified length with preference for punctuation

local M = {}

-- Main function to break lines with smart punctuation handling
function M.smart_line_break(start_line, end_line, length)
  local bufnr = vim.api.nvim_get_current_buf()

  -- Track how many lines we've added to adjust the range
  local lines_added = 0

  -- Process each line in the range
  for line_num = start_line, end_line do
    -- Adjust for lines we've added
    local adjusted_line_num = line_num + lines_added
    local current_line = vim.api.nvim_buf_get_lines(bufnr, adjusted_line_num - 1, adjusted_line_num, false)[1]
    local line_length = #current_line

    -- Skip if line is already shorter than target length
    if line_length <= length then
      goto continue
    end

    local position = 0
    local lines_to_add = {}

    -- Process the line until we've gone through it entirely
    while position < line_length do
      --print("Processing line: " .. adjusted_line_num .. ", position: " .. position)
      -- Default break point is exactly at length or end of line
      local break_point = math.min(position + length, line_length)
      if break_point == line_length then
        goto extract
      end

      do
        -- Define threshold for punctuation search (20% of target length)
        local punctuation_threshold = math.floor(length * 0.2)
        local punctuation_min = math.max(position +1, break_point - punctuation_threshold)
        --local punctuation_max = math.min(break_point + punctuation_threshold, line_length)
        local punctuation_max = break_point

        -- Try to find punctuation within threshold
        local punct_pos = -1
        for i = punctuation_max, punctuation_min, -1 do
          local char = string.sub(current_line, i, i)
          if char:match('[,.;:!?>%]})]') then
            punct_pos = i
            break
          elseif char:match('[<({%[]') then
            punct_pos = i - 1
            break
          elseif char:match('[\'"`]') then
            local next_char = string.sub(current_line, i + 1, i + 1)
            if not next_char:match('%w') then
              punct_pos = i
              break
            end
          end
        end

        -- If punctuation found, use it as break point
        if punct_pos ~= -1 then
          break_point = punct_pos
        else
          -- Otherwise look for spaces near the target length
          -- First try backward
          for i = break_point, position +1, -1 do
            if string.sub(current_line, i, i) == " " then
              break_point = i -1
              break
            end
          end
        end
      end

      -- Extract the chunk of text
      ::extract::
      local line_chunk = string.sub(current_line, position + 1, break_point)
      table.insert(lines_to_add, vim.trim(line_chunk))

      -- Move position to after the break (skip spaces)
      position = break_point
      while position < line_length and string.sub(current_line, position + 1, position + 1) == " " do
        position = position + 1
      end
    end -- end while

    -- Replace original line with our new broken lines
    vim.api.nvim_buf_set_lines(bufnr, adjusted_line_num - 1, adjusted_line_num, false, lines_to_add)

    -- Update our line addition counter
    lines_added = lines_added + #lines_to_add - 1

    ::continue::
  end
end

-- Create a user command for Neovim
vim.api.nvim_create_user_command(
  'SmartBreak',
  function(opts)
    local length = tonumber(opts.args)
    if not length or length <= 0 then
      vim.notify("Please provide a positive number for line length", vim.log.levels.ERROR)
      return
    end

    local start_line, end_line
    if opts.range == 2 then
      -- Range was specified
      start_line = opts.line1
      end_line = opts.line2
    else
      -- Use current line if no range
      start_line = vim.api.nvim_win_get_cursor(0)[1]
      end_line = start_line
    end

    M.smart_line_break(start_line, end_line, length)
  end,
  {
    nargs = 1,
    range = true,
    desc = 'Smart line breaking at specified length with punctuation preference'
  }
)

return M

-- vim: ts=2 sts=2 sw=2 et
