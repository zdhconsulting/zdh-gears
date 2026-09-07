param(
    [Parameter(Mandatory = $true, Position = 0)] [string] $Task,
    [string] $ReceiptPath = '',
    [string] $CodexCommand = 'codex',
    [switch] $PassThru
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'CodexGear.psm1') -Force
$profile = Select-CodexGear -Text $Task
$gear = Get-CodexGear -Profile $profile
$configArgs = @(New-CodexConfigArgs -Gear $gear)
$bytes = [Text.Encoding]::UTF8.GetBytes($Task)
$sha = [Security.Cryptography.SHA256]::Create()
try { $taskHash = (($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') }) -join '') } finally { $sha.Dispose() }
$runId = [guid]::NewGuid().ToString()
if ([string]::IsNullOrWhiteSpace($ReceiptPath)) { $ReceiptPath = Join-Path (Get-Location) "zdh-gears-receipt-$runId.json" }
$started = (Get-Date).ToUniversalTime()
$receipt = [ordered]@{
    Schema = 'zdh-gears.execution-receipt.v2'; RunId = $runId; CreatedAt = $started.ToString('o')
    TaskHash = $taskHash; SelectedProfile = $gear.Profile; Gear = $gear.Gear; Model = $gear.Model
    ReasoningEffort = $gear.Effort; ServiceTier = $gear.ServiceTier; ConfigArgs = $configArgs
    ArgumentsPassed = $false; Status = 'configuration_unverified'; AppliedBy = 'zdh-gears-exec.ps1'
}
$parent = Split-Path -Parent $ReceiptPath
if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
try {
    $receipt.ArgumentsPassed = $true; $receipt.Status = 'execution_running'
    $receipt | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $ReceiptPath -Encoding UTF8
    & $CodexCommand exec @configArgs -- $Task
    if ($LASTEXITCODE -ne 0) { throw "Codex exited with code $LASTEXITCODE" }
    $receipt.Status = 'execution_succeeded'; $receipt.ObservedExitCode = 0
} catch {
    $receipt.Status = 'execution_failed'; $receipt.Error = $_.Exception.Message
    $receipt.ObservedExitCode = if ($null -ne $LASTEXITCODE) { $LASTEXITCODE } else { 1 }; throw
} finally {
    $receipt.CompletedAt = (Get-Date).ToUniversalTime().ToString('o')
    $receipt | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $ReceiptPath -Encoding UTF8
}
if ($PassThru) { $receipt | ConvertTo-Json -Depth 8 }
