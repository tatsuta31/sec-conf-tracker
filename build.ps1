# build.ps1
# Regenerates index.html (published full page) from _head.html + preview.html (body).
# Commits & pushes when there are changes. Deterministic, zero LLM tokens.
#
# NOTE: This script is intentionally ASCII-only. Windows PowerShell 5.1 reads a
# BOM-less .ps1 as Shift-JIS, which corrupts embedded Japanese. So all Japanese
# lives in _head.html / preview.html (read as UTF-8 via .NET), never inline here.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File build.ps1          # rebuild + commit + push
#   powershell -ExecutionPolicy Bypass -File build.ps1 -NoPush  # rebuild only

param([switch]$NoPush)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

$headPath = Join-Path $root '_head.html'
$bodyPath = Join-Path $root 'preview.html'
foreach ($p in @($headPath, $bodyPath)) {
    if (-not (Test-Path $p)) { throw "required file not found: $p" }
}

# .NET ReadAllText defaults to UTF-8 (BOM-aware) regardless of PowerShell's file encoding.
$head = [System.IO.File]::ReadAllText($headPath)
$body = [System.IO.File]::ReadAllText($bodyPath)
$footer = "</body>`r`n</html>`r`n"
$html = $head + $body + $footer

# Write UTF-8 without BOM (a BOM before <!doctype> can confuse some parsers).
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText((Join-Path $root 'index.html'), $html, $utf8NoBom)
Write-Host "[build] index.html regenerated"

if ($NoPush) { Write-Host "[build] -NoPush: skipping git"; exit 0 }

$changed = git status --porcelain
if ([string]::IsNullOrWhiteSpace($changed)) {
    Write-Host "[build] no changes; nothing to commit"
    exit 0
}
git add -A
$stamp = Get-Date -Format "yyyy-MM-dd HH:mm"
git commit -m "Rebuild site ($stamp)"
git push
Write-Host "[build] committed & pushed -> https://tatsuta31.github.io/sec-conf-tracker/"
