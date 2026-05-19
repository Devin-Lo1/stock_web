param(
    [string]$ApiBaseUrl = "http://192.168.1.4:8000"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$mobileDir = Join-Path $repoRoot "mobile_app"
$flutter = "D:\flutter\bin\flutter.bat"

if (-not (Test-Path $flutter)) {
    throw "Flutter executable not found: $flutter"
}

Push-Location $mobileDir
try {
    & $flutter build apk --debug "--dart-define=API_BASE_URL=$ApiBaseUrl"
} finally {
    Pop-Location
}
