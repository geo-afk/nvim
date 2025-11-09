local Completion = {}
local M = {} -- Config reference

local function setup_completion(config)
  M.config = config
end

function Completion:get_completions(text, mode)
  local items = {}
  if mode == ":" then
    local prefix = text:match("%S+$") or ""
    -- Commands (use built-in getcompletion for native support)
    local commands = vim.fn.getcompletion(prefix, "cmdline")
    for _, cmd in ipairs(commands) do
      table.insert(items, {
        text = cmd,
        kind = "Command",
        group = "Commands",
        priority = 100,
      })
    end
    -- Quick actions (enhanced with more modern examples)
    if text == "" or #prefix < 3 then
      local quick_actions = {
        { text = "w",       desc = "Write (save) current buffer", group = "Quick Actions" },
        { text = "q",       desc = "Quit current window",         group = "Quick Actions" },
        { text = "wq",      desc = "Write and quit",              group = "Quick Actions" },
        { text = "qa",      desc = "Quit all windows",            group = "Quick Actions" },
        { text = "e ",      desc = "Edit a file",                 group = "File Operations" },
        { text = "bnext",   desc = "Next buffer",                 group = "Buffers" },
        { text = "bprev",   desc = "Previous buffer",             group = "Buffers" },
        { text = "bd",      desc = "Delete buffer",               group = "Buffers" },
        { text = "split",   desc = "Split window horizontally",   group = "Windows" },
        { text = "vsplit",  desc = "Split window vertically",     group = "Windows" },
        { text = "tabnew",  desc = "Create new tab",              group = "Tabs" },
        { text = "tabnext", desc = "Next tab",                    group = "Tabs" },
        { text = "tabprev", desc = "Previous tab",                group = "Tabs" },
        { text = "LspInfo", desc = "LSP Information",             group = "LSP" }, -- Modern addition
        { text = "Mason",   desc = "Package Manager",             group = "Tools" }, -- Assuming Mason
      }
      for _, action in ipairs(quick_actions) do
        table.insert(items, {
          text = action.text,
          kind = "Action",
          group = action.group,
          desc = action.desc,
          priority = 150,
        })
      end
    end
    -- History (limited to recent, avoid duplicates)
    for i = 1, 10 do
      local hist = vim.fn.histget("cmd", -i)
      if hist and hist ~= "" and hist ~= text and not vim.tbl_contains(items, hist) then
        table.insert(items, {
          text = hist,
          kind = "History",
          group = "Recent Commands",
          priority = 80,
        })
      end
    end
  elseif mode == "/" or mode == "?" then
    local word = vim.fn.expand("<cword>")
    if word and word ~= "" then
      table.insert(items, {
        text = word,
        kind = "Word",
        group = "Current Context",
        desc = "Word under cursor",
        priority = 100,
      })
    end
    for i = 1, 8 do
      local hist = vim.fn.histget("search", -i)
      if hist and hist ~= "" and hist ~= text then
        table.insert(items, {
          text = hist,
          kind = "History",
          group = "Recent Searches",
          priority = 80,
        })
      end
    end
  end
  self:score_items(items, text)
  return self:group_items(items)
end

function Completion:score_items(items, query)
  local q = query:lower()
  for _, item in ipairs(items) do
    local score = item.priority or 0
    local text = item.text:lower()
    if text == q then
      score = score + 300
    elseif vim.startswith(text, q) then
      score = score + 200 - (#text - #q)
    elseif text:find(q, 1, true) then
      score = score + 100
    end
    if M.config.completion.fuzzy and q ~= "" then
      local matched = true
      local last_idx = 0
      local pos_score = 0
      for i = 1, #q do
        local char = q:sub(i, i)
        local idx = text:find(char, last_idx + 1, true)
        if not idx then
          matched = false
          break
        end
        pos_score = pos_score + (100 - idx)
        last_idx = idx
      end
      if matched then
        score = score + 50 + (pos_score / #q)
      end
    end
    item.score = score
  end
end

function Completion:group_items(items)
  table.sort(items, function(a, b)
    return (a.score or 0) > (b.score or 0)
  end)
  if not M.config.features.group_completions then
    return items
  end
  local groups = {}
  local group_order = {}
  for _, item in ipairs(items) do
    local group = item.group or "Other"
    if not groups[group] then
      groups[group] = {}
      table.insert(group_order, group)
    end
    table.insert(groups[group], item)
  end
  local result = {}
  for _, group_name in ipairs(group_order) do
    local group_items = groups[group_name]
    local max = M.config.completion.max_items_per_group
    if #group_items > 0 then
      table.insert(result, {
        is_header = true,
        text = group_name,
        count = #group_items,
      })
      for i = 1, math.min(#group_items, max) do
        table.insert(result, group_items[i])
      end
      if #group_items > max then
        table.insert(result, {
          is_more = true,
          count = #group_items - max,
        })
      end
    end
  end
  return result
end

return { Completion = Completion, setup = setup_completion }
