param(
    [string] $CodexHome = "$env:USERPROFILE\.codex",
    [string] $SourceModulePath
)

$skillRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent $skillRoot
$repoRoot = Split-Path -Parent $repoRoot
$candidateSources = @()

if ($SourceModulePath) {
    $candidateSources += $SourceModulePath
}
$candidateSources += Join-Path $repoRoot "scripts\CodexGear.psm1"
$candidateSources += Join-Path $skillRoot "assets\CodexGear.psm1"

$moduleSource = $null
foreach ($candidate in $candidateSources) {
    if (Test-Path -LiteralPath $candidate) {
        $moduleSource = (Resolve-Path $candidate).Path
        break
    }
}

if (-not $moduleSource) {
    Write-Error "Cannot locate CodexGear.psm1. Pass -SourceModulePath explicitly."
    exit 1
}

$scriptsDir = Join-Path $CodexHome "scripts"
New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null
$moduleDestination = Join-Path $scriptsDir "CodexGear.psm1"
Copy-Item -LiteralPath $moduleSource -Destination $moduleDestination -Force

$manifest = @"
{
  "PackName": "codex-gears",
  "Version": "1.0.0",
  "InstalledAt": "$(Get-Date -Format o)",
  "SourceModulePath": "$($moduleSource -replace '\\', '\\\\')"
}
"@

Set-Content -LiteralPath (Join-Path $scriptsDir "codex-gears.share.json") -Value $manifest -Encoding UTF8

Write-Host "Installed codex-gears shared module to $moduleDestination"
Write-Host "Share manifest: $(Join-Path $scriptsDir 'codex-gears.share.json')"
Write-Host "Run: pwsh -NoProfile -ExecutionPolicy Bypass -File scripts\codex-gear-test.ps1 to validate"
