local M = {}

---@param opts? table Optional configuration
function M.importLuaModule(opts)
  opts = opts or {}

  local function import(text)
    return vim.trim(text:gsub('.-:', ''))
  end

  Snacks.picker.grep_word(vim.tbl_deep_extend('force', {
    title = '󰢱 Import Lua Module',
    cmd = 'rg',
    args = { '--only-matching' },
    live = false,
    regex = true,
    search = [[local (\w+) ?= ?require\(["'](.*?)["']\)(\.[\w.]*)?]],
    ft = 'lua',
    layout = {
      preset = 'select',
      layout = {
        width = 0.65,
        height = 0.5,
      },
    },
    -- Ensure unique items by tracking what we've seen
    transform = function(item, ctx)
      ctx.meta.done = ctx.meta.done or {}
      local imp = import(item.text)
      if ctx.meta.done[imp] then
        return false
      end
      ctx.meta.done[imp] = true
      return true
    end,
    -- Clean display format
    format = function(item, _picker)
      local out = {}
      local line = item.line:gsub('^local ', '')
      Snacks.picker.highlight.format(item, line, out)
      return out
    end,
    -- Insert the import below current line
    confirm = function(picker, item)
      picker:close()
      if not item then
        return
      end
      local lnum = vim.api.nvim_win_get_cursor(0)[1]
      local imported = import(item.text)
      vim.api.nvim_buf_set_lines(0, lnum, lnum, false, { imported })
      vim.cmd.normal { 'j==', bang = true }
      vim.notify('Imported: ' .. imported, vim.log.levels.INFO)
    end,
  }, opts))
end

---@param opts? table Optional configuration
function M.betterFileOpen(opts)
  opts = opts or {}

  -- Collect git changes if in a git repo
  local changedFiles = {}
  local gitDir = Snacks.git.get_root()

  if gitDir then
    local args = { 'git', 'status', '--porcelain', '--ignored', '.' }
    local result = vim.system(args, { text = true }):wait()

    if result.code == 0 and result.stdout then
      local changes = vim.split(result.stdout, '\n', { trimempty = true })
      vim.iter(changes):each(function(line)
        local relPath = line:sub(4)
        local change = line:sub(1, 2)

        -- Normalize change indicators
        if change == '??' then
          change = ' A'
        end
        if change:find 'R' then
          relPath = relPath:gsub('.+ -> ', '')
        end

        local absPath = gitDir .. '/' .. relPath
        changedFiles[absPath] = change
      end)
    end
  end

  local currentFile = vim.api.nvim_buf_get_name(0)
  local cwdName = vim.fs.basename(vim.uv.cwd() or '.')

  Snacks.picker.files(vim.tbl_deep_extend('force', {
    title = '  ' .. cwdName,
    layout = {
      preset = 'default',
    },
    -- Exclude current file from results
    transform = function(item, _ctx)
      local itemPath = Snacks.picker.util.path(item)
      if itemPath == currentFile then
        return false
      end
      return true
    end,
    -- Add git status and hidden file indicators
    format = function(item, picker)
      local itemPath = Snacks.picker.util.path(item)
      item.status = changedFiles[itemPath]

      -- Mark hidden files
      if vim.startswith(item.file, '.') then
        item.status = '!!'
      end

      return require('snacks.picker.format').file(item, picker)
    end,
  }, opts))
end

---@param opts? table Optional configuration
function M.browseProject(opts)
  opts = opts or {}

  -- Get projects folder from config or use sensible default
  local projectsFolder = vim.g.localRepos

  if not projectsFolder then
    -- Try common project directory locations
    local home = vim.fn.expand '~'
    local candidates = {
      home .. '/projects',
      home .. '/Projects',
      home .. '/dev',
      home .. '/Development',
      home .. '/code',
      home .. '/workspace',
      vim.fn.stdpath 'data' .. '/projects',
    }

    for _, candidate in ipairs(candidates) do
      if vim.fn.isdirectory(candidate) == 1 then
        projectsFolder = candidate
        vim.g.localRepos = projectsFolder -- Cache for future use
        break
      end
    end

    -- If still not found, prompt user to set it up
    if not projectsFolder then
      vim.notify(
        'No project directory found. Please set vim.g.localRepos to your projects folder.\n' .. 'Example: vim.g.localRepos = vim.fn.expand("~/projects")',
        vim.log.levels.WARN,
        { title = 'Browse Projects' }
      )
      return
    end
  end

  -- Verify directory exists
  if vim.fn.isdirectory(projectsFolder) ~= 1 then
    vim.notify(
      'Project directory does not exist: ' .. projectsFolder .. '\n' .. 'Please update vim.g.localRepos or create the directory.',
      vim.log.levels.ERROR,
      { title = 'Browse Projects' }
    )
    return
  end

  -- Function to browse a specific project
  local function browseProjectFiles(project)
    local projectPath = vim.fs.joinpath(projectsFolder, project)

    -- Get git info if available
    local gitRoot = Snacks.git.get_root(projectPath)
    local gitInfo = ''
    if gitRoot then
      gitInfo = '  '
    end

    Snacks.picker.files(vim.tbl_deep_extend('force', {
      title = '  ' .. project .. gitInfo,
      cwd = projectPath,
      layout = {
        preset = 'default',
      },
      -- Add option to open project in explorer
      actions = {
        explorer = function(picker)
          picker:close()
          Snacks.explorer { cwd = projectPath }
        end,
      },
      win = {
        input = {
          keys = {
            ['<C-e>'] = { 'explorer', mode = { 'n', 'i' }, desc = 'Open in Explorer' },
          },
        },
      },
    }, opts))
  end

  -- Collect all projects (directories only)
  local projects = {}
  local ok, iter = pcall(vim.fs.dir, projectsFolder)

  if not ok then
    vim.notify('Failed to read project directory: ' .. projectsFolder, vim.log.levels.ERROR, { title = 'Browse Projects' })
    return
  end

  for item, type in iter do
    if type == 'directory' and not vim.startswith(item, '.') then
      table.insert(projects, item)
    end
  end

  -- Handle based on number of projects
  if #projects == 0 then
    vim.notify('No projects found in: ' .. projectsFolder, vim.log.levels.WARN, { title = 'Browse Projects' })
  elseif #projects == 1 then
    browseProjectFiles(projects[1])
  else
    -- Use custom picker for better UX
    table.sort(projects)
    local maxNameLen = 0
    local items = {}

    for i, name in ipairs(projects) do
      maxNameLen = math.max(maxNameLen, #name)
      local path = vim.fs.joinpath(projectsFolder, name)
      local gitRoot = Snacks.git.get_root(path)

      table.insert(items, {
        idx = i,
        text = name,
        name = name,
        path = path,
        is_git = gitRoot ~= nil,
      })
    end

    Snacks.picker {
      title = '  Select Project (' .. #projects .. ')',
      items = items,
      layout = {
        preset = 'select',
        layout = {
          width = math.min(80, maxNameLen + 40),
          height = math.min(20, #projects + 5),
        },
      },
      format = function(item)
        local ret = {}
        local icon = item.is_git and '  ' or '  '
        ret[#ret + 1] = { icon, item.is_git and 'SnacksPickerIcon' or 'Comment' }
        ret[#ret + 1] = { item.name, 'SnacksPickerLabel' }
        ret[#ret + 1] = { '  ', virtual = true }
        ret[#ret + 1] = { item.path, 'Comment' }
        return ret
      end,
      confirm = function(picker, item)
        picker:close()
        if item then
          browseProjectFiles(item.name)
        end
      end,
      actions = {
        cd_to_project = function(picker, item)
          if item then
            picker:close()
            vim.cmd.cd(item.path)
            vim.notify('Changed directory to: ' .. item.path, vim.log.levels.INFO)
          end
        end,
        open_terminal = function(picker, item)
          if item then
            picker:close()
            Snacks.terminal { cwd = item.path }
          end
        end,
      },
      win = {
        input = {
          keys = {
            ['<C-c>'] = { 'cd_to_project', mode = { 'n', 'i' }, desc = 'CD to Project' },
            ['<C-t>'] = { 'open_terminal', mode = { 'n', 'i' }, desc = 'Open Terminal' },
          },
        },
      },
    }
  end
end

-- Convenience function to setup default projects directory
---@param path? string Optional path to set as projects directory
function M.setup_projects_dir(path)
  if path then
    vim.g.localRepos = vim.fn.expand(path)
  else
    -- Interactive setup
    vim.ui.input({
      prompt = 'Enter projects directory path: ',
      default = vim.fn.expand '~/projects',
      completion = 'dir',
    }, function(input)
      if input and input ~= '' then
        local expanded = vim.fn.expand(input)
        vim.g.localRepos = expanded

        -- Create directory if it doesn't exist
        if vim.fn.isdirectory(expanded) ~= 1 then
          vim.fn.mkdir(expanded, 'p')
          vim.notify('Created projects directory: ' .. expanded, vim.log.levels.INFO)
        else
          vim.notify('Projects directory set to: ' .. expanded, vim.log.levels.INFO)
        end
      end
    end)
  end
end

return M
