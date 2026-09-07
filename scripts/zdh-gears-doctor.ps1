#Requires -Version 7.0
param([switch]$Json, [switch]$PackageOnly, [string]$CodexCommand = 'codex')
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$checks = [Collections.Generic.List[object]]::new()
function Add-Check([string]$Name, [bool]$Ok, [string]$Detail) { $checks.Add([pscustomobject]@{ Name=$Name; Ok=$Ok; Detail=$Detail }) }
$version = $null
try {
    $manifest = Get-Content -LiteralPath (Join-Path $root '.codex-plugin/plugin.json') -Raw | ConvertFrom-Json
    $version = $manifest.version
    Add-Check 'manifest' ($manifest.name -eq 'codex-gears' -and $version -match '^\d+\.\d+\.\d+$') 'Package identity and semantic version'
    $marketplacePath = Join-Path $root '.agents/plugins/marketplace.json'
    if (Test-Path -LiteralPath $marketplacePath) {
        $marketplace = Get-Content -LiteralPath $marketplacePath -Raw | ConvertFrom-Json
        $entry = @($marketplace.plugins | Where-Object name -EQ 'codex-gears')
        Add-Check 'marketplace-version' ($marketplace.name -eq 'zdh-gears' -and $entry.Count -eq 1 -and $entry[0].version -eq $version) 'Source manifest/version parity'
    }
    foreach ($field in @('composerIcon','logo')) {
        $asset = $manifest.interface.$field
        $assetOk = $asset -is [string] -and $asset.StartsWith('./assets/') -and -not ($asset -split '/' -contains '..')
        if ($assetOk) { $assetOk = Test-Path -LiteralPath (Join-Path $root $asset) -PathType Leaf }
        Add-Check $field $assetOk 'Supported interface asset binding'
    }
} catch { Add-Check 'manifest' $false 'Manifest could not be read or parsed' }
foreach ($relative in @('scripts/CodexGear.psm1','scripts/ZdhGearReceipt.psm1','scripts/zdh-gears-route.ps1','scripts/zdh-gears-exec.ps1','skills/codex-gears/SKILL.md')) {
    Add-Check $relative (Test-Path -LiteralPath (Join-Path $root $relative) -PathType Leaf) 'Required package file'
}
try {
    Import-Module (Join-Path $root 'scripts/CodexGear.psm1') -Force
    $expected = @{
        fast=@('gpt-5.6-sol','low','fast'); balanced=@('gpt-6-astra','low','standard'); standard=@('gpt-6-astra','low','standard')
        deep=@('gpt-6-astra','high','standard'); review=@('gpt-6-astra','high','standard'); max=@('gpt-6-astra','ultra','standard')
        boost=@('gpt-6-astra','ultra','fast'); saver=@('gpt-5.3-codex-spark','low','standard'); 'save-tokens'=@('gpt-5.3-codex-spark','low','standard')
        'saver-compact'=@('gpt-5.6-luna','low','standard'); 'saver-work'=@('gpt-5.6-sol','low','standard'); 'saver-risk'=@('gpt-6-astra','high','standard')
    }
    foreach ($name in $expected.Keys) {
        $gear = Get-CodexGear -Profile $name
        Add-Check "profile-$name" ((@($gear.Model,$gear.Effort,$gear.ServiceTier) -join '|') -eq ($expected[$name] -join '|')) 'Selected model, effort and tier (account availability untested)'
    }
} catch { Add-Check 'gear-matrix' $false 'Router could not provide the complete expected matrix' }
$cliVersion = $null
if (-not $PackageOnly) {
    try {
        $command = Get-Command -Name $CodexCommand -CommandType Application,ExternalScript -ErrorAction Stop | Select-Object -First 1
        $global:LASTEXITCODE = 0
        $cliVersion = (& $command.Source --version | Out-String).Trim()
        $cliOk = $LASTEXITCODE -eq 0 -and $cliVersion -match '^codex-cli '
        Add-Check 'codex-cli' $cliOk 'CLI executable/version only; no model run or credential check'
    } catch { Add-Check 'codex-cli' $false 'Codex CLI not found or could not execute' }
}
$result = [pscustomobject]@{
    Schema='zdh-gears.doctor.v2'; PackageVersion=$version; Ok=(@($checks | Where-Object { -not $_.Ok }).Count -eq 0)
    Scope= $(if ($PackageOnly) { 'package_only' } else { 'package_and_cli' }); Checks=@($checks); CliVersion=$cliVersion
    ConfigurationStatus='unverified'; ModelAvailability='not_checked'; Credentials='not_checked'
    Activation='Plugin supplies guidance. The launcher requests configuration once per invocation.'
}
if ($Json) { $result | ConvertTo-Json -Depth 6 } else { $checks | Format-Table -AutoSize; Write-Host $result.Activation }
if (-not $result.Ok) { exit 1 }
