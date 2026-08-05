$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$runtimeRoot = $repoRoot.Replace("\", "/").Replace(" ", "\ ")
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("nvim-config-tests-" + [guid]::NewGuid().ToString("N"))

$oldEnvironment = @{}
$testEnvironment = @{
  XDG_STATE_HOME = Join-Path $testRoot "state"
  XDG_CACHE_HOME = Join-Path $testRoot "cache"
  NVIM_LOG_FILE = Join-Path $testRoot "state\nvim.log"
}

$suites = @(
  "tests/audit_architecture_spec.lua"
  "tests/loader_spec.lua"
  "tests/explorer_move_spec.lua"
  "tests/explorer_search_spec.lua"
  "tests/explorer_ui_spec.lua"
  "tests/folding_spec.lua"
  "tests/angular_lsp_spec.lua"
  "tests/lightbulb_spec.lua"
  "tests/autoclose_quote_check.lua"
  "tests/pack_lock_spec.lua"
  "tests/go_performance_spec.lua"
)

try {
  New-Item -ItemType Directory -Path $testEnvironment.XDG_STATE_HOME -Force | Out-Null
  New-Item -ItemType Directory -Path $testEnvironment.XDG_CACHE_HOME -Force | Out-Null

  foreach ($name in $testEnvironment.Keys) {
    $oldEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, "Process")
    [Environment]::SetEnvironmentVariable($name, $testEnvironment[$name], "Process")
  }

  Push-Location $repoRoot
  try {
    foreach ($suite in $suites) {
      Write-Host "==> $suite"
      & nvim --headless -u NONE -i NONE --cmd "set runtimepath^=$runtimeRoot" -l $suite
      if ($LASTEXITCODE -ne 0) {
        throw "$suite failed with exit code $LASTEXITCODE"
      }
    }
  }
  finally {
    Pop-Location
  }
}
finally {
  foreach ($name in $testEnvironment.Keys) {
    [Environment]::SetEnvironmentVariable($name, $oldEnvironment[$name], "Process")
  }
  if (Test-Path -LiteralPath $testRoot) {
    Remove-Item -LiteralPath $testRoot -Recurse -Force
  }
}

Write-Host ("All {0} Neovim test suites passed." -f $suites.Count)
