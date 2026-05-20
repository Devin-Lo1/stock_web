param(
    [string]$ApiBaseUrl = ""
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$mobileDir = Join-Path $repoRoot "mobile_app"
$flutter = "D:\flutter\bin\flutter.bat"

function Get-LanApiBaseUrl {
    $ipAddress = Get-NetIPConfiguration |
        Where-Object { $null -ne $_.IPv4DefaultGateway -and $null -ne $_.IPv4Address } |
        ForEach-Object { $_.IPv4Address.IPAddress } |
        Where-Object { $_ -and $_ -notlike "169.254*" } |
        Select-Object -First 1

    if (-not $ipAddress) {
        throw "Unable to detect LAN IPv4 address. Pass -ApiBaseUrl http://<computer-ip>:8000 explicitly."
    }

    return "http://${ipAddress}:8000"
}

if (-not (Test-Path $flutter)) {
    throw "Flutter executable not found: $flutter"
}

if ([string]::IsNullOrWhiteSpace($ApiBaseUrl)) {
    $ApiBaseUrl = Get-LanApiBaseUrl
}

Write-Host "Building debug APK with API_BASE_URL=$ApiBaseUrl"

Push-Location $mobileDir
try {
    & $flutter build apk --debug "--dart-define=API_BASE_URL=$ApiBaseUrl"
} finally {
    Pop-Location
}
