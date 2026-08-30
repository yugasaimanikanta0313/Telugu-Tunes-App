$ErrorActionPreference = 'Stop'
$toolRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $toolRoot

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
  throw 'Docker Desktop is required. Install or start Docker Desktop, then run this file again.'
}

docker info *> $null
if ($LASTEXITCODE -ne 0) {
  throw 'Docker Desktop is not running. Start it and run this file again.'
}

docker compose up --build
if ($LASTEXITCODE -ne 0) {
  throw "IndicTrans2 container failed with exit code $LASTEXITCODE."
}
