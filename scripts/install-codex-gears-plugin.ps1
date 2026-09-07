param(
    [string] $CodexHome = (Join-Path $env:USERPROFILE '.codex'),
    [string] $UserPluginRoot = (Join-Path $env:USERPROFILE 'plugins'),
    [string] $PersonalMarketplaceRoot = (Join-Path $env:USERPROFILE '.agents\plugins'),
    [string] $RepoRoot = ''
)

$ErrorActionPreference = 'Stop'

$pluginName = 'codex-gears'
$marketplaceName = 'personal'
$pluginSource = $null
$scriptDir = Split-Path -Parent $PSScriptRoot
$hasPluginMarker = Test-Path -LiteralPath (Join-Path $scriptDir '.codex-plugin\plugin.json')
$repoRoot = Split-Path -Parent $scriptDir
$hasRepoPluginMarker = Test-Path -LiteralPath (Join-Path $repoRoot '.codex-plugin\plugin.json')
if (-not $RepoRoot) {
    if ($hasPluginMarker) {
        $pluginSource = $scriptDir
    } elseif ($hasRepoPluginMarker) {
        $pluginSource = $repoRoot
    } else {
        $RepoRoot = $repoRoot
        $pluginSource = Join-Path $RepoRoot ('plugins\' + $pluginName)
    }
} else {
    $pluginSource = Join-Path $RepoRoot ('plugins\' + $pluginName)
}

$userPluginPath = Join-Path $UserPluginRoot $pluginName
$manifestPath = Join-Path $pluginSource '.codex-plugin\plugin.json'
$marketplacePath = Join-Path $PersonalMarketplaceRoot 'marketplace.json'
$cacheRoot = Join-Path $CodexHome ("plugins\cache\$marketplaceName\$pluginName")
$configPath = Join-Path $CodexHome 'config.toml'

if (-not (Test-Path -LiteralPath $pluginSource)) {
    throw "Plugin source missing: $pluginSource"
}
if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "Plugin manifest missing: $manifestPath"
}

$pluginJson = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$version = [string]$pluginJson.version
$cachePath = Join-Path $cacheRoot $version

function Copy-PluginSource {
    param([string] $Source, [string] $Destination)

    if (Test-Path -LiteralPath $Destination) {
        Remove-Item -LiteralPath $Destination -Recurse -Force
    }

    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    Get-ChildItem -LiteralPath $Source -Force |
        ForEach-Object {
            Copy-Item -LiteralPath $_.FullName -Destination $Destination -Recurse -Force
        }
}

function Set-PluginEnabled {
    param([string] $Path)

    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path) | Out-Null

    if (Test-Path -LiteralPath $Path) {
        $text = Get-Content -LiteralPath $Path -Raw
    } else {
        $text = ''
    }

    $pluginBlockHeader = '[plugins."codex-gears@personal"]'
    $pluginPattern = '(?ms)^\[plugins\."codex-gears@personal"\]\r?\n.*?(?=^\[|\z)'
    $replacement = "$pluginBlockHeader`r`nenabled = true`r`n"

    if ($text -match $pluginPattern) {
        $text = [regex]::Replace($text, $pluginPattern, $replacement, 1)
    } else {
        if ($text.Trim().Length -gt 0) {
            $text = $text.TrimEnd() + "`r`n`r`n"
        }
        $text += $replacement
    }

    Set-Content -LiteralPath $Path -Value ($text.TrimEnd() + "`r`n") -Encoding utf8NoBOM
}

function Set-PersonalMarketplace {
    param([string] $Path)

    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path) | Out-Null

    if (Test-Path -LiteralPath $Path) {
        $marketplace = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    } else {
        $marketplace = [pscustomobject]@{
            name = $marketplaceName
            interface = [pscustomobject]@{ displayName = 'Personal' }
            plugins = @()
        }
    }

    if (-not $marketplace.name) {
        $marketplace | Add-Member -NotePropertyName name -NotePropertyValue $marketplaceName
    }
    if (-not $marketplace.interface) {
        $marketplace | Add-Member -NotePropertyName interface -NotePropertyValue ([pscustomobject]@{ displayName = 'Personal' })
    }
    if ($null -eq $marketplace.plugins) {
        $marketplace | Add-Member -NotePropertyName plugins -NotePropertyValue @()
    }

    $entry = [pscustomobject]@{
        name = $pluginName
        source = [pscustomobject]@{
            source = 'local'
            path = './plugins/' + $pluginName
        }
        policy = [pscustomobject]@{
            installation = 'AVAILABLE'
            authentication = 'ON_INSTALL'
        }
        category = 'Productivity'
        version = $version
    }

    $plugins = @($marketplace.plugins | Where-Object { $_.name -ne $pluginName })
    $plugins += $entry
    $marketplace.plugins = $plugins

    $json = $marketplace | ConvertTo-Json -Depth 12
    Set-Content -LiteralPath $Path -Value ($json.TrimEnd() + "`r`n") -Encoding utf8NoBOM
}

Copy-PluginSource -Source $pluginSource -Destination $userPluginPath
Copy-PluginSource -Source $pluginSource -Destination $cachePath
Set-PersonalMarketplace -Path $marketplacePath
Set-PluginEnabled -Path $configPath

Write-Host "Installed ZDH Gears plugin source: $userPluginPath"
Write-Host "Installed ZDH Gears plugin cache: $cachePath"
Write-Host "Updated marketplace: $marketplacePath"
Write-Host "Updated plugin status in: $configPath"
Write-Host 'Restart Codex Desktop or open a fresh session to load plugin changes.'
