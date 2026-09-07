#Requires -Version 7.0
param(
    [Parameter(Mandatory = $true, Position = 0)][ValidateNotNullOrEmpty()][string] $Task,
    [ValidateSet('auto', 'boost', 'save-tokens')][string] $Mode,
    [string] $ReceiptPath = '',
    [string] $CodexCommand = 'codex',
    [switch] $DryRun,
    [switch] $PassThru
)
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($Task)) { throw 'Task must contain text.' }
Import-Module (Join-Path $PSScriptRoot 'ZdhGearReceipt.psm1') -Force
$receipt = New-ZdhGearReceipt -Task $Task -Mode $Mode -ReceiptPath $ReceiptPath
Save-ZdhGearReceipt -Receipt $receipt
if ($DryRun) {
    $receipt | ConvertTo-Json -Depth 8
    exit 0
}
$timer = [Diagnostics.Stopwatch]::StartNew()
$exitCode = 1
$previousOutputEncoding = $OutputEncoding
try {
    $command = Get-Command -Name $CodexCommand -CommandType Application, ExternalScript -ErrorAction Stop | Select-Object -First 1
    $receipt.Status = 'execution_running'
    Save-ZdhGearReceipt -Receipt $receipt
    # Stdin keeps quotes, Unicode and leading dashes out of CLI option parsing.
    # Only the three selected configuration settings are overridden.
    $OutputEncoding = [Text.UTF8Encoding]::new($false)
    $global:LASTEXITCODE = 0
    $configArgs = @($receipt.ConfigArgs)
    $Task | & $command.Source exec @configArgs '-'
    $invocationSucceeded = $?
    $exitCode = $LASTEXITCODE
    if (-not $invocationSucceeded -and $exitCode -eq 0) { $exitCode = 1 }
    $receipt.ArgumentsPassed = $true
    $receipt.ObservedExitCode = $exitCode
    $receipt.Status = if ($exitCode -eq 0) { 'execution_succeeded' } else { 'execution_failed' }
    if ($exitCode -ne 0) { $receipt.ErrorCode = 'codex_exit_nonzero' }
} catch [System.Management.Automation.CommandNotFoundException] {
    $receipt.Status = 'launch_failed'
    $receipt.ErrorCode = 'command_not_found'
    $exitCode = 127
} catch {
    $receipt.Status = 'execution_failed'
    $receipt.ErrorCode = 'invocation_exception'
    $exitCode = 1
} finally {
    $OutputEncoding = $previousOutputEncoding
    $timer.Stop()
    $receipt.CompletedAt = [datetimeoffset]::UtcNow.ToString('o')
    $receipt.ElapsedMilliseconds = $timer.ElapsedMilliseconds
    Save-ZdhGearReceipt -Receipt $receipt
}
if ($PassThru) { $receipt | ConvertTo-Json -Depth 8 }
Write-Host "Receipt: $($receipt.ReceiptPath) ($($receipt.Status); configuration $($receipt.ConfigurationStatus))"
exit $exitCode
