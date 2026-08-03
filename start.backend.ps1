$ErrorActionPreference = "Stop"

$backendPath = Join-Path $PSScriptRoot "pi_backend"
$pythonPath = Join-Path $backendPath ".venv\Scripts\python.exe"

if (-not (Test-Path $pythonPath)) {
    throw "Backend Python environment not found at: $pythonPath"
}

Set-Location $backendPath

$env:GAS_APP_TOKEN = "local-simulation-token"

Write-Host "Starting Gas Flow Control backend..."
Write-Host "Backend address: http://127.0.0.1:8000"
Write-Host "Press Ctrl+C to stop the backend."

& $pythonPath -m uvicorn app.main:app `
    --reload `
    --host 127.0.0.1 `
    --port 8000
    