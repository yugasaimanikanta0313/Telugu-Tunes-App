param(
    [string]$OutputDirectory = "D:\Telegram\flutter-apk"
)

$ErrorActionPreference = "Stop"
$projectDirectory = Split-Path -Parent $PSScriptRoot
$pubspecPath = Join-Path $projectDirectory "pubspec.yaml"
$signingProperties = Join-Path $projectDirectory "android\key.properties"

function Invoke-Checked {
    param([scriptblock]$Command, [string]$Description)
    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw "$Description failed with exit code $LASTEXITCODE."
    }
}

if (-not (Test-Path -LiteralPath $signingProperties)) {
    throw "Production signing is not configured. Restore android/key.properties first."
}

$pubspec = Get-Content -LiteralPath $pubspecPath -Raw
$match = [regex]::Match($pubspec, '(?m)^version:\s*([^+\r\n]+)\+(\d+)\s*$')
if (-not $match.Success) {
    throw "The version line in pubspec.yaml is invalid."
}
$versionName = $match.Groups[1].Value
$nextBuild = [int]$match.Groups[2].Value + 1
$updated = [regex]::Replace(
    $pubspec,
    '(?m)^version:\s*[^\r\n]+$',
    "version: $versionName+$nextBuild",
    1
)
Set-Content -LiteralPath $pubspecPath -Value $updated -NoNewline

Push-Location $projectDirectory
try {
    Invoke-Checked { flutter pub get } "Dependency resolution"
    Invoke-Checked { flutter analyze --no-fatal-infos } "Flutter analysis"
    Invoke-Checked { flutter test } "Flutter tests"
    Invoke-Checked { flutter build apk --release } "Android release build"
    New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
    $destination = Join-Path $OutputDirectory "telugu-tunes-$versionName+$nextBuild.apk"
    Copy-Item -LiteralPath "build\app\outputs\flutter-apk\app-release.apk" `
        -Destination $destination -Force
    Write-Output "Release created: $destination"
} finally {
    Pop-Location
}
