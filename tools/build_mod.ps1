$gameDir = "C:\Program Files (x86)\Steam\steamapps\common\Batomon Showdown Demo"
$pckKey = "YOUR_PCK_KEY_HERE"
$pckVersion = "2.4.3.0"
$pckExplorer = "$gameDir\_tools\pckexplorer\GodotPCKExplorer.Console.exe"
$srcDir = "$PSScriptRoot\..\src"
$outputPck = "$PSScriptRoot\..\batomon_showdown.pck"

# Locate the original PCK backup
$origPck = $null
foreach ($candidate in @("$gameDir\batomon_showdown.pck.orig", "$gameDir\BATOMO~1.ORI")) {
    if (Test-Path $candidate) { $origPck = $candidate; break }
}
if (-not $origPck) {
    Write-Host "ERROR: Original PCK backup not found." -ForegroundColor Red
    Write-Host "Looked for: batomon_showdown.pck.orig or BATOMO~1.ORI in $gameDir" -ForegroundColor Red
    exit 1
}

Write-Host "=== Building Leaderboard Mod PCK ===" -ForegroundColor Cyan
Write-Host "Using original: $origPck" -ForegroundColor Gray
Write-Host "Patching with mod files...       " -ForegroundColor Yellow
& $pckExplorer -pc "$origPck" "$srcDir" $outputPck $pckVersion "" $pckKey files

if ($LASTEXITCODE -eq 0) {
    Write-Host "Success! Modded PCK: $outputPck" -ForegroundColor Green
    Write-Host "Size: $((Get-Item $outputPck).Length / 1MB) MB" -ForegroundColor Green
} else {
    Write-Host "Failed to build PCK (exit code: $LASTEXITCODE)" -ForegroundColor Red
}
