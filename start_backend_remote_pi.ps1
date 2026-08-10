$ErrorActionPreference = "Stop"

$backendPath = Join-Path $PSScriptRoot "pi_backend"
$pythonPath = Join-Path $backendPath ".venv\Scripts\python.exe"

if (-not (Test-Path $pythonPath)) {
    throw "Backend Python environment not found at: $pythonPath"
}

Set-Location $backendPath

if (-not $env:GAS_APP_TOKEN) {
    $env:GAS_APP_TOKEN = "local-simulation-token"
}

$env:GAS_HARDWARE_MODE = "remote_pi"

if (-not $env:GAS_PI_CONTROLLER_URL) {
    $env:GAS_PI_CONTROLLER_URL = "http://127.0.0.1:9000"
}

Write-Host "Starting Gas Flow Control backend..."
Write-Host "Hardware mode: $env:GAS_HARDWARE_MODE"
Write-Host "Pi controller: $env:GAS_PI_CONTROLLER_URL"
Write-Host "Backend address: http://127.0.0.1:8000"
Write-Host "Press Ctrl+C to stop the backend."

& $pythonPath -m uvicorn app.main:app `
    --host 127.0.0.1 `
    --port 8000
    