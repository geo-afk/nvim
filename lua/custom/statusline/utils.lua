local M = {}

local HL_PATTERN = "%%#.-#"
local STATUSLINE_CODES = {
  ['%%='] = '',
  ['%%<'] = '',
  ['%%%-?%d*%.?%d*[T*]'] = '',
  ['%%0?%d*[%-%+ #]*%.?%d*[bBcCdDefFgGhHiIlLmMnNoOpPrRsStTvVwWXYyZzqQaA]'] = '',
}

local function normalize(segment)
  if type(segment) ~= 'string' then
    return ''
  end
  return segment:gsub('^%s+', ''):gsub('%s+$', '')
end

function M.clean(segment)
  return normalize(segment)
end

function M.join(segments, separator)
  local parts = {}
  local sep = separator or ' '

  for _, segment in ipairs(segments) do
    local cleaned = normalize(segment)
    if cleaned ~= '' then
      if #parts > 0 then
        parts[#parts + 1] = sep
      end
      parts[#parts + 1] = cleaned
    end
  end

  return table.concat(parts)
end

function M.statusline_width(segment)
  local cleaned = segment or ''
  cleaned = cleaned:gsub(HL_PATTERN, '')
  for pattern, replacement in pairs(STATUSLINE_CODES) do
    cleaned = cleaned:gsub(pattern, replacement)
  end
  cleaned = cleaned:gsub('%%%%', '%%')
  return vim.fn.strdisplaywidth(cleaned)
end

return M
