param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string] $Task,
    [string] $ReceiptPath = (Join-Path (Get-Location) 'zdh-gears-receipt.json')
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'CodexGear.psm1') -Force
$profile = Select-CodexGear -Text $Task
$gear = Get-CodexGear -Profile $profile
$configArgs = New-CodexConfigArgs -Gear $gear
$bytes = [Text.Encoding]::UTF8.GetBytes($Task)
$sha = [Security.Cryptography.SHA256]::Create()
try { $taskHash = (($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') }) -join '') } finally { $sha.Dispose() }
$receipt = [pscustomobject]@{
    Schema = 'zdh-gears.execution-receipt.v1'
    CreatedAt = (Get-Date).ToUniversalTime().ToString('o')
    TaskHash = $taskHash
    SelectedProfile = $gear.Profile
    Gear = $gear.Gear
    Model = $gear.Model
    ReasoningEffort = $gear.Effort
    ServiceTier = $gear.ServiceTier
    ConfigArgs = @($configArgs)
    Applied = $false
    AppliedBy = 'zdh-gears-route.ps1'
    Note = 'Selection receipt only. A host launcher must apply ConfigArgs and record observed execution separately.'
}
$parent = Split-Path -Parent $ReceiptPath
if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
$receipt | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $ReceiptPath -Encoding UTF8
$receipt | ConvertTo-Json -Depth 8
