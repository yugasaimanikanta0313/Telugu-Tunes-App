$ErrorActionPreference = 'Stop'
$toolRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$environmentPath = Join-Path $toolRoot '.venv'

if (-not (Test-Path $environmentPath)) {
  $candidates = @(
    'C:\Python311\python.exe',
    'C:\Python310\python.exe',
    'C:\tools\miniconda3\python.exe',
    (Get-Command python -ErrorAction SilentlyContinue).Source
  ) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique
  $basePython = $null
  foreach ($candidate in $candidates) {
    $version = & $candidate -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')"
    if ($version -in @('3.9', '3.10', '3.11', '3.12')) {
      $basePython = $candidate
      break
    }
  }
  if (-not $basePython) {
    throw 'Install 64-bit Python 3.9, 3.10, 3.11, or 3.12, then run this file again.'
  }
  & $basePython -m venv $environmentPath
}

$python = Join-Path $environmentPath 'Scripts\python.exe'
& $python -m pip install --upgrade pip
& $python -m pip install -r (Join-Path $toolRoot 'requirements.txt')
& $python (Join-Path $toolRoot 'server.py')
