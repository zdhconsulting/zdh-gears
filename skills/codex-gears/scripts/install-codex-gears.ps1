[CmdletBinding()]
param([switch] $Update, [string] $CodexCommand = 'codex', [string] $CodexHome, [string] $SourceModulePath)
$ErrorActionPreference = 'Stop'
if ($PSBoundParameters.ContainsKey('CodexHome') -or $PSBoundParameters.ContainsKey('SourceModulePath')) {
    throw 'CodexHome and SourceModulePath are obsolete. This installer no longer copies modules or writes Codex configuration directly; use the native plugin installer without those parameters.'
}
$pluginRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$installer = Join-Path $pluginRoot 'scripts\install-codex-gears-plugin.ps1'
if (-not (Test-Path -LiteralPath $installer)) { throw "Packaged native installer is missing: $installer" }
& $installer -Update:$Update -CodexCommand $CodexCommand
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
