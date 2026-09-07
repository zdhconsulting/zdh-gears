param([switch]$Json)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$checks = @()
$manifest = Join-Path $root '.codex-plugin/plugin.json'
$module = Join-Path $root 'scripts/CodexGear.psm1'
$checks += [pscustomobject]@{ Name='manifest'; Ok=(Test-Path $manifest); Detail=$manifest }
$checks += [pscustomobject]@{ Name='router'; Ok=(Test-Path $module); Detail=$module }
$checks += [pscustomobject]@{ Name='codex-cli'; Ok=($null -ne (Get-Command codex -ErrorAction SilentlyContinue)); Detail='codex on PATH' }
Import-Module $module -Force
$matrix = Get-CodexGearMatrix
$checks += [pscustomobject]@{ Name='gear-matrix'; Ok=($matrix.fast.Model -eq 'gpt-5.6-sol' -and $matrix.max.Model -eq 'gpt-6-astra' -and $matrix.max.Effort -eq 'ultra'); Detail='GPT-5.6 low / Astra medium-high-extra' }
$result = [pscustomobject]@{ Schema='zdh-gears.doctor.v1'; Ok=(@($checks | Where-Object { -not $_.Ok }).Count -eq 0); Checks=$checks }
if ($Json) { $result | ConvertTo-Json -Depth 6 } else { $checks | Format-Table -AutoSize; if (-not $result.Ok) { exit 1 } }
