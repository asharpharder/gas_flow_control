$ErrorActionPreference = "Stop"

$flutterProjectPath = Join-Path $PSScriptRoot "flutter_app"
$pubspecPath = Join-Path $flutterProjectPath "pubspec.yaml"

if (-not (Test-Path $pubspecPath)) {
    throw "Flutter project not found at: $flutterProjectPath"
}

Set-Location $flutterProjectPath

Write-Host "Starting Gas Flow Control Flutter app..."
Write-Host "Press Ctrl+C to stop Flutter."

flutter run -d chrome `
    --dart-define=GAS_API_URL=http://127.0.0.1:8000 `
    --dart-define=GAS_API_TOKEN=local-simulation-token `
    --dart-define=OPERATOR_ID=development-operator
    