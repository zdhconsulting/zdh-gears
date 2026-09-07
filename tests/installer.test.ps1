param([string]$PackageRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
$installer = Join-Path $PackageRoot 'scripts/install-codex-gears-plugin.ps1'
$legacyInstaller = Join-Path $PackageRoot 'skills/codex-gears/scripts/install-codex-gears.ps1'
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ("codex-gears-installer-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot | Out-Null
function New-FakeCodex {
    param([hashtable] $Scenario)
    $caseRoot = Join-Path $testRoot ([guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $caseRoot | Out-Null
    $Scenario | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $caseRoot 'scenario.json') -Encoding utf8
    $fake = Join-Path $caseRoot 'codex.ps1'
    @'
param([Parameter(ValueFromRemainingArguments)][string[]] $CliArgs)
Add-Content -LiteralPath (Join-Path $PSScriptRoot 'commands.log') -Value ($CliArgs -join '|')
$scenario = Get-Content -Raw (Join-Path $PSScriptRoot 'scenario.json') | ConvertFrom-Json
$key = $CliArgs -join ' '
if ($scenario.fail -eq $key) { [Console]::Error.WriteLine('simulated failure'); exit 23 }
if ($key -eq 'plugin marketplace list --json') { $scenario.marketplaces | ConvertTo-Json -Depth 10 -Compress; exit 0 }
if ($key -eq 'plugin list --json') { $scenario.plugins | ConvertTo-Json -Depth 10 -Compress; exit 0 }
'{}'
'@ | Set-Content -LiteralPath $fake -Encoding utf8
    return $fake
}
function Get-Commands([string] $Fake) {
    $path = Join-Path (Split-Path -Parent $Fake) 'commands.log'
    if (Test-Path $path) { return @(Get-Content $path) }
    return @()
}
function Assert-Throws([scriptblock] $Action, [string] $Pattern) {
    try { & $Action; throw 'Expected command to throw.' }
    catch { if ($_.Exception.Message -eq 'Expected command to throw.' -or $_.Exception.Message -notmatch $Pattern) { throw } }
}
try {
    $empty = @{ marketplaces = @{ marketplaces = @() }; plugins = @{ installed = @(); available = @() } }
    $fake = New-FakeCodex $empty
    & $installer -CodexCommand $fake | Out-Null
    $commands = Get-Commands $fake
    $expected = "plugin|list|--json`nplugin|marketplace|list|--json`nplugin|marketplace|add|https://github.com/zdhconsulting/zdh-gears.git|--json`nplugin|add|codex-gears@zdh-gears|--json"
    if (($commands -join "`n") -ne $expected) { throw 'Missing-marketplace flow used unexpected commands.' }

    $canonical = @{ marketplaces = @{ marketplaces = @(@{ name='zdh-gears'; root='x'; marketplaceSource=@{ sourceType='git'; source='https://github.com/zdhconsulting/zdh-gears.git' } }) }; plugins = @{ installed = @(@{ pluginId='codex-gears@zdh-gears'; name='codex-gears' }); available=@() } }
    $fake = New-FakeCodex $canonical
    & $installer -Update -CodexCommand $fake | Out-Null
    $commands = Get-Commands $fake
    if ($commands -notcontains 'plugin|marketplace|upgrade|zdh-gears|--json') { throw 'Update did not use native marketplace upgrade.' }
    if ($commands -match 'remove') { throw 'Update must not remove the plugin.' }

    $badSource = @{ marketplaces = @{ marketplaces = @(@{ name='zdh-gears'; marketplaceSource=@{ sourceType='git'; source='https://example.test/other.git' } }) }; plugins = @{ installed=@(); available=@() } }
    $fake = New-FakeCodex $badSource
    Assert-Throws { & $installer -CodexCommand $fake } 'different source'
    if ((Get-Commands $fake).Count -ne 2) { throw 'Source conflict should stop before mutation.' }

    $conflict = @{ marketplaces = $canonical.marketplaces; plugins = @{ installed = @(@{ pluginId='codex-gears@personal'; name='codex-gears' }); available=@() } }
    $fake = New-FakeCodex $conflict
    Assert-Throws { & $installer -CodexCommand $fake } 'conflicting codex-gears'
    if ((Get-Commands $fake).Count -ne 1) { throw 'Identity conflict should stop before marketplace mutation.' }
    if ((Get-Commands $fake) -contains 'plugin|add|codex-gears@zdh-gears|--json') { throw 'Identity conflict should stop before install.' }

    $failure = @{ marketplaces=$empty.marketplaces; plugins=$empty.plugins; fail='plugin add codex-gears@zdh-gears --json' }
    $fake = New-FakeCodex $failure
    Assert-Throws { & $installer -CodexCommand $fake } 'failed \(23\)'
    Assert-Throws { & $legacyInstaller -SourceModulePath 'obsolete.psm1' -CodexCommand $fake } 'obsolete'
    'Installer tests passed.'
} finally {
    $resolved = [IO.Path]::GetFullPath($testRoot)
    if ($resolved.StartsWith([IO.Path]::GetFullPath([IO.Path]::GetTempPath()), [StringComparison]::OrdinalIgnoreCase) -and (Split-Path $resolved -Leaf) -like 'codex-gears-installer-*') { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
