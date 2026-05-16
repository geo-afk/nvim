local M = {}

-- ── Highlight Groups ──────────────────────────────────────────────────────────
local function setup_highlights()
  local groups = {
    SwagKeyword = "Type",
    SwagName = "Identifier",
    SwagLocation = "Function",
    SwagType = "Keyword",
    SwagRequired = "Constant",
    SwagDesc = "String",
    SwagCode = "Number",
    SwagBrace = "Special",
    SwagMethod = "Function",
    SwagPath = "String",
    SwagModel = "Type",
    SwagComment = "Comment",
  }
  for group, link in pairs(groups) do
    vim.api.nvim_set_hl(0, group, { link = link, default = true })
  end
end

-- ── Namespace ─────────────────────────────────────────────────────────────────
local ns = vim.api.nvim_create_namespace("swag_annotations")

-- ── Pre-compiled Patterns (compiled once at module load) ──────────────────────
local PATTERNS = (function()
  local raw = {
    {
      regex = [[@\(title\|version\|description\|termsOfService\|contact\.[a-z]\+\|license\.[a-z]\+\|host\|BasePath\|accept\|produce\|query\.collection\.format\|schemes\|externalDocs\.[a-z]\+\|x-[a-zA-Z0-9_-]\+\)]],
      hl = "SwagKeyword",
    },
    {
      regex = [[@\(Summary\|Description\|ID\|Tags\|Accept\|Produce\|Security\|deprecated\)]],
      hl = "SwagKeyword",
    },
    {
      regex = [[@\(Param\|Success\|Failure\|response\|Header\|Router\|deprecatedrouter\|securityDefinitions\|securitydefinitions\|in\|name\|tokenUrl\|authorizationurl\|scope\)]],
      hl = "SwagKeyword",
    },
  }
  local compiled = {}
  for _, p in ipairs(raw) do
    compiled[#compiled + 1] = { re = vim.regex(p.regex), hl = p.hl }
  end
  return compiled
end)()

local RE = {
  prefix = vim.regex([=[^//\s*]=]),
  param_words = vim.regex([=[@Param\s\+\zs\(\S\+\)\s\+\(\S\+\)\s\+\(\S\+\)\s\+\(\S\+\)]=]),
  status_code = vim.regex([=[\s\zs\d\{3\}\ze\s]=]),
  brace_type = vim.regex([=[{\zs[^}]\+\ze}]=]),
  model = vim.regex([=[}\s*\zs\S\+]=]),
  router_method = vim.regex("\\[\\zs\\(get\\|post\\|put\\|delete\\|head\\|options\\|patch\\|trace\\)\\ze\\]"),
  quoted_string = vim.regex([=["[^"]*"]=]),
  godoc = vim.regex([=[godoc$]=]),
}

-- ── Per-buffer Debounce Timers ────────────────────────────────────────────────
local _timers = {}

local function cleanup_timer(bufnr)
  local t = _timers[bufnr]
  if t then
    t:stop()
    t:close()
    _timers[bufnr] = nil
  end
end

-- ── Helpers ───────────────────────────────────────────────────────────────────
local function set_extmark(bufnr, row, s, e, hl, priority)
  vim.api.nvim_buf_set_extmark(bufnr, ns, row, s, {
    end_col = e,
    hl_group = hl,
    priority = priority,
  })
end

---Apply a pre-compiled regex to every match on a line (not just the first).
local function apply_all_matches(bufnr, row, line, re, hl, priority)
  local len = #line
  local offset = 0
  while offset < len do
    local s, e = re:match_str(line:sub(offset + 1))
    if not s then
      break
    end
    set_extmark(bufnr, row, s + offset, e + offset, hl, priority)
    if e == 0 then
      break
    end -- guard against zero-length matches
    offset = offset + e
  end
end

-- ── Core Highlighter ──────────────────────────────────────────────────────────
local function highlight_swag(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, "go")
  if not ok or not parser then
    return
  end

  local tree = parser:parse()[1]
  if not tree then
    return
  end
  local root = tree:root()

  -- Neovim caches query.parse internally; calling it here is safe.
  local query = vim.treesitter.query.parse(
    "go",
    [[
    ((comment) @comment (#lua-match? @comment "^//%s*@"))
  ]]
  )

  for _, node in query:iter_captures(root, bufnr, 0, -1) do
    local start_row, _, end_row, _ = node:range()
    local lines = vim.api.nvim_buf_get_lines(bufnr, start_row, end_row + 1, false)

    for i, line in ipairs(lines) do
      local row = start_row + i - 1

      -- 1. "//" prefix
      local _, pe = RE.prefix:match_str(line)
      if pe then
        set_extmark(bufnr, row, 0, pe, "SwagComment", 200)
      end

      -- 2. Keywords — all matches per line
      for _, p in ipairs(PATTERNS) do
        apply_all_matches(bufnr, row, line, p.re, p.hl, 210)
      end

      -- 3. @Param name location type required "desc"
      if line:find("@Param", 1, true) then
        local s = RE.param_words:match_str(line)
        if s then
          local after = line:sub(s + 1)
          local words = {}
          for w in after:gmatch("%S+") do
            words[#words + 1] = w
          end
          local hls = { "SwagName", "SwagLocation", "SwagType", "SwagRequired" }
          local pos = s
          for j = 1, math.min(#words, #hls) do
            local ws, we = line:find(words[j], pos + 1, true)
            if ws then
              set_extmark(bufnr, row, ws - 1, we, hls[j], 220)
              pos = we
            end
          end
        end
      end

      -- 4. @Success / @Failure / @response  <code> {type} model "desc"
      if line:find("@Success", 1, true) or line:find("@Failure", 1, true) or line:find("@response", 1, true) then
        local cs, ce = RE.status_code:match_str(line)
        if cs then
          set_extmark(bufnr, row, cs, ce, "SwagCode", 220)
        end

        local ts, te = RE.brace_type:match_str(line)
        if ts then
          set_extmark(bufnr, row, ts - 1, te + 1, "SwagBrace", 220) -- { }
          set_extmark(bufnr, row, ts, te, "SwagType", 221) -- content
          local ms, me = RE.model:match_str(line)
          if ms then
            set_extmark(bufnr, row, ms, me, "SwagModel", 220)
          end
        end
      end

      -- 5. @Router path [method]
      if line:find("@Router", 1, true) then
        local ms, me = RE.router_method:match_str(line)
        if ms then
          set_extmark(bufnr, row, ms - 1, me + 1, "SwagBrace", 220) -- [ ]
          set_extmark(bufnr, row, ms, me, "SwagMethod", 221) -- verb
        end
      end

      -- 6. Quoted strings — all matches per line
      apply_all_matches(bufnr, row, line, RE.quoted_string, "SwagDesc", 230)

      -- 7. godoc keyword
      if line:find("godoc", 1, true) then
        local gs, ge = RE.godoc:match_str(line)
        if gs then
          set_extmark(bufnr, row, gs, ge, "Bold", 210)
        end
      end
    end
  end
end

-- ── Debounced Entry Point ─────────────────────────────────────────────────────
local function debounced_highlight(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local t = _timers[bufnr]
  if not t then
    t = vim.uv.new_timer()
    _timers[bufnr] = t
  end

  t:stop()
  t:start(
    50,
    0,
    vim.schedule_wrap(function()
      highlight_swag(bufnr)
    end)
  )
end

-- ── Setup ─────────────────────────────────────────────────────────────────────
function M.setup()
  setup_highlights()

  local group = vim.api.nvim_create_augroup("SwagHighlight", { clear = true })

  vim.api.nvim_create_autocmd({ "FileType", "BufEnter", "TextChanged", "InsertLeave" }, {
    group = group,
    pattern = "go",
    callback = function(ev)
      debounced_highlight(ev.buf)
    end,
  })

  -- Release per-buffer timers to avoid libuv handle leaks.
  vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
    group = group,
    pattern = "*.go",
    callback = function(ev)
      cleanup_timer(ev.buf)
    end,
  })
end

return M
