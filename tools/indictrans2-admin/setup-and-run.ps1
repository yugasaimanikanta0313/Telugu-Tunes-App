$ErrorActionPreference = 'Stop'
$toolRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$environmentPath = Join-Path $toolRoot '.venv'

if (-not (Test-Path $environmentPath)) {
  py -3.11 -m venv $environmentPath
}

$python = Join-Path $environmentPath 'Scripts\python.exe'
& $python -m pip install --upgrade pip
& $python -m pip install -r (Join-Path $toolRoot 'requirements.txt')
& $python (Join-Path $toolRoot 'server.py')
