local M = {}

local HL_PATTERN = "%%#.-#"
local STATUSLINE_CODES = {
  ["%%="] = "",
  ["%%<"] = "",
  ["%%%-?%d*%.?%d*[T*]"] = "",
  ["%%0?%d*[%-%+ #]*%.?%d*[bBcCdDefFgGhHiIlLmMnNoOpPrRsStTvVwWXYyZzqQaA]"] = "",
}

local function normalize(segment)
  if type(segment) ~= "string" then
    return ""
  end
  return segment:gsub("^%s+", ""):gsub("%s+$", "")
end

function M.clean(segment)
  return normalize(segment)
end

function M.join(segments, separator)
  local parts = {}
  local sep = separator or " "

  for _, segment in ipairs(segments) do
    local cleaned = normalize(segment)
    if cleaned ~= "" then
      if #parts > 0 then
        parts[#parts + 1] = sep
      end
      parts[#parts + 1] = cleaned
    end
  end

  return table.concat(parts)
end

function M.statusline_width(segment)
  local cleaned = segment or ""
  cleaned = cleaned:gsub(HL_PATTERN, "")
  for pattern, replacement in pairs(STATUSLINE_CODES) do
    cleaned = cleaned:gsub(pattern, replacement)
  end
  cleaned = cleaned:gsub("%%%%", "%%")
  return vim.fn.strdisplaywidth(cleaned)
end

function M.visible_text(segment)
  local cleaned = segment or ""
  cleaned = cleaned:gsub(HL_PATTERN, "")
  for pattern, replacement in pairs(STATUSLINE_CODES) do
    cleaned = cleaned:gsub(pattern, replacement)
  end
  return cleaned:gsub("%%%%", "%%")
end

function M.truncate_middle(text, max_width)
  if not text or text == "" then
    return ""
  end
  if max_width <= 0 then
    return ""
  end
  if vim.fn.strdisplaywidth(text) <= max_width then
    return text
  end
  if max_width <= 3 then
    return text:sub(1, max_width)
  end
  local marker = "..."
  local left_w = math.floor((max_width - #marker) / 2)
  local right_w = max_width - #marker - left_w
  return text:sub(1, left_w) .. marker .. text:sub(-right_w)
end

function M.truncate_tail(text, max_width)
  if not text or text == "" then
    return ""
  end
  if max_width <= 0 then
    return ""
  end
  if vim.fn.strdisplaywidth(text) <= max_width then
    return text
  end
  if max_width <= 3 then
    return text:sub(1, max_width)
  end
  return text:sub(1, max_width - 3) .. "..."
end

function M.compact_branch(branch, max_width)
  if not branch or branch == "" then
    return ""
  end
  local text = branch:gsub("^feature/", "feat/"):gsub("^bugfix/", "fix/"):gsub("^hotfix/", "hot/")
  if vim.fn.strdisplaywidth(text) <= max_width then
    return text
  end
  local prefix, rest = text:match("^([^/]+)/(.+)$")
  if prefix and rest then
    local allowed = math.max(3, max_width - #prefix - 4)
    return prefix .. "/" .. M.truncate_tail(rest, allowed)
  end
  return M.truncate_tail(text, max_width)
end

return M
