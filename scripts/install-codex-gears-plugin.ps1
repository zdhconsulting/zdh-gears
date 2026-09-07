[CmdletBinding()]
param([switch] $Update, [string] $CodexCommand = 'codex')
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSVersion.Major -lt 7) { throw 'PowerShell 7 or newer is required. Run this installer with pwsh.' }
$marketplaceName = 'zdh-gears'
$marketplaceSource = 'https://github.com/zdhconsulting/zdh-gears.git'
$pluginId = 'codex-gears@zdh-gears'
function Invoke-CodexJson {
    param([Parameter(Mandatory)][string[]] $Arguments)
    $output = & $CodexCommand @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Codex command failed ($LASTEXITCODE): codex $($Arguments -join ' ')`n$($output -join "`n")" }
    try { return (($output -join "`n") | ConvertFrom-Json) }
    catch { throw "Codex command returned invalid JSON: codex $($Arguments -join ' ')" }
}
$pluginResult = Invoke-CodexJson @('plugin', 'list', '--json')
$conflicts = @($pluginResult.installed | Where-Object {
    $installedId = if ($_.pluginId) { [string]$_.pluginId } else { [string]$_.name }
    $installedId -eq 'codex-gears' -or ($installedId -like 'codex-gears@*' -and $installedId -ne $pluginId)
})
if ($conflicts.Count -gt 0) {
    $identities = ($conflicts | ForEach-Object { if ($_.pluginId) { $_.pluginId } else { $_.name } }) -join ', '
    throw "A conflicting codex-gears plugin identity is installed ($identities). Remove it explicitly before installing $pluginId."
}
$marketplaceResult = Invoke-CodexJson @('plugin', 'marketplace', 'list', '--json')
$namedMarketplace = @($marketplaceResult.marketplaces | Where-Object { $_.name -eq $marketplaceName })
if ($namedMarketplace.Count -gt 1) { throw "Multiple '$marketplaceName' marketplaces are configured. Resolve the duplicate entries before installing." }
if ($namedMarketplace.Count -eq 1) {
    $configured = $namedMarketplace[0].marketplaceSource
    if ($configured.sourceType -ne 'git' -or $configured.source -ne $marketplaceSource) { throw "Marketplace '$marketplaceName' is configured from a different source. Expected $marketplaceSource; refusing to overwrite it." }
    if ($Update) { Invoke-CodexJson @('plugin', 'marketplace', 'upgrade', $marketplaceName, '--json') | Out-Null }
} else {
    Invoke-CodexJson @('plugin', 'marketplace', 'add', $marketplaceSource, '--json') | Out-Null
}
Invoke-CodexJson @('plugin', 'add', $pluginId, '--json') | Out-Null
Write-Host "Installed $pluginId through the native Codex plugin manager."
if ($Update) { Write-Host "Refreshed marketplace $marketplaceName before installation." }
Write-Host 'Start a fresh Codex task to load the plugin.'
