return {
  init_options = {
    -- Custom config. Used together with a config file found in the workspace or its parents,
    -- taking precedence for settings declared in both.
    -- Equivalent to the typos `--config` cli argument.
    config = '~/AppData/Local/nvim/typos.toml',
    -- How typos are rendered in the editor, can be one of an Error, Warning, Info or Hint.
    -- Defaults to Info.
    diagnosticSeverity = 'Info',
  },
}
