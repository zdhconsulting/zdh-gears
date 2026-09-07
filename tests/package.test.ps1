#Requires -Version 7.0
param([string]$PackageRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
function Assert([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
$manifest = Get-Content (Join-Path $PackageRoot '.codex-plugin/plugin.json') -Raw | ConvertFrom-Json
$marketplace = Get-Content (Join-Path $PackageRoot '.agents/plugins/marketplace.json') -Raw | ConvertFrom-Json
Assert ($manifest.name -eq 'codex-gears' -and $marketplace.name -eq 'zdh-gears') 'Incorrect package identity'
Assert ($marketplace.plugins.Count -eq 1 -and $marketplace.plugins[0].name -eq $manifest.name -and $marketplace.plugins[0].version -eq $manifest.version) 'Package and marketplace versions differ'
Assert ($marketplace.plugins[0].source.path -eq './') 'Standalone package source root changed'
$allowed = @('id','name','version','description','skills','apps','mcpServers','interface','author','homepage','repository','license','keywords')
foreach ($property in $manifest.PSObject.Properties.Name) { Assert ($allowed -contains $property) "Unsupported manifest key: $property" }
foreach ($property in @('composerIcon','logo')) {
    $relative = $manifest.interface.$property
    Assert ($relative -like './assets/*' -and -not ($relative -split '/' -contains '..')) "Invalid asset binding: $property"
    Assert (Test-Path -LiteralPath (Join-Path $PackageRoot $relative) -PathType Leaf) "Missing asset: $property"
}
foreach ($relative in @('scripts/ZdhGearReceipt.psm1','scripts/zdh-gears-route.ps1','scripts/zdh-gears-exec.ps1','scripts/zdh-gears-doctor.ps1','scripts/install-codex-gears-plugin.ps1','tests/run-tests.ps1')) {
    Assert (Test-Path -LiteralPath (Join-Path $PackageRoot $relative) -PathType Leaf) "Missing package file: $relative"
}
foreach ($relative in @('README.md','skills/codex-gears/SKILL.md','skills/codex-gears/references/codex-gears-pack-contract.md')) {
    $documentation = Get-Content (Join-Path $PackageRoot $relative) -Raw
    Assert ($documentation -match 'gpt-5.3-codex-spark' -and $documentation -match 'gpt-6-astra' -and $documentation -match 'gpt-5.6-sol' -and $documentation -match 'gpt-5.6-luna') "Incomplete mode model documentation: $relative"
    Assert ($documentation -match 'unverified') "Missing backend verification limit: $relative"
    Assert ($documentation -notmatch 'scripts[\\/]codex-gear-test.ps1|plugins/codex-gears') "Stale package paths: $relative"
    Assert ($documentation -notmatch '(?im)^.*Save Tokens.*(?:favors|prefers|uses) GPT-5.6') "Stale saver description: $relative"
}
$pwshPath = (Get-Process -Id $PID).Path
$doctorPath = Join-Path $PackageRoot 'scripts/zdh-gears-doctor.ps1'
$diagnosis = & $pwshPath -NoProfile -File $doctorPath -PackageOnly -Json | ConvertFrom-Json
Assert ($LASTEXITCODE -eq 0 -and $diagnosis.Ok -and $diagnosis.Scope -eq 'package_only' -and $diagnosis.ConfigurationStatus -eq 'unverified') 'Package doctor failed or overstated proof'
$diagnosis = & $pwshPath -NoProfile -File $doctorPath -CodexCommand 'zdh-deliberately-missing-cli-19ad' -Json | ConvertFrom-Json
Assert ($LASTEXITCODE -ne 0 -and -not $diagnosis.Ok) 'JSON doctor must fail when CLI is unavailable'
Write-Host 'PASS: package identity/version/assets/documentation, package-only doctor, failure exit semantics'
