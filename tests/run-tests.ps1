#Requires -Version 7.0
param([string]$PackageRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
$pwshPath = (Get-Process -Id $PID).Path
foreach ($suite in @('routing-smoke.ps1','execution.test.ps1','package.test.ps1','installer.test.ps1','usage.test.ps1')) {
    & $pwshPath -NoProfile -File (Join-Path $PSScriptRoot $suite) -PackageRoot $PackageRoot
    if ($LASTEXITCODE -ne 0) { throw "$suite failed with exit code $LASTEXITCODE" }
}
Write-Host 'PASS: all five isolated ZDH Gears suites. No backend model run was performed.'
