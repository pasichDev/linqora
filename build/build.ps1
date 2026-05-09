$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = Split-Path -Parent $ScriptDir
$Out = $ScriptDir

Push-Location "$Root\LinqoraHost"
try {
    Write-Host "Building CLI (headless)..."
    go build -tags cli -o "$Out\linqora.exe" .\cmd\
    if ($LASTEXITCODE -ne 0) { throw "CLI build failed" }
    Write-Host "  -> $Out\linqora.exe"

    Write-Host "Building GUI (full)..."
    go build -o "$Out\linqorahost.exe" .\cmd\
    if ($LASTEXITCODE -ne 0) { throw "GUI build failed" }
    Write-Host "  -> $Out\linqorahost.exe"

    Write-Host "Done."
} finally {
    Pop-Location
}
