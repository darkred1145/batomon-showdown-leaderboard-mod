$gameDir = "C:\Program Files (x86)\Steam\steamapps\common\Batomon Showdown Demo"
$pckKey = "YOUR_PCK_KEY_HERE"
$pckVersion = "2.4.3.0"
$pckExplorer = "$gameDir\_tools\pckexplorer\GodotPCKExplorer.Console.exe"
$srcDir = "$PSScriptRoot\..\src"
$outputPck = "$PSScriptRoot\..\batomon_showdown.pck"

if (-not (Test-Path $gameDir\batomon_showdown.pck.orig)) {
    Write-Host "ERROR: Original PCK not found at $gameDir\batomon_showdown.pck.orig" -ForegroundColor Red
    exit 1
}

Write-Host "=== Building Leaderboard Mod PCK ===" -ForegroundColor Cyan
Write-Host "Patching original PCK with mod files..." -ForegroundColor Yellow
& $pckExplorer -pc "$gameDir\batomon_showdown.pck.orig" "$srcDir" $outputPck $pckVersion "" $pckKey

if ($LASTEXITCODE -eq 0) {
    Write-Host "Success! Modded PCK: $outputPck" -ForegroundColor Green
    Write-Host "Size: $((Get-Item $outputPck).Length / 1MB) MB" -ForegroundColor Green
} else {
    Write-Host "Failed to build PCK (exit code: $LASTEXITCODE)" -ForegroundColor Red
}
