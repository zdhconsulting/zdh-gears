#Requires -Version 7.0
param(
    [Parameter(Mandatory = $true, Position = 0)][ValidateNotNullOrEmpty()][string] $Task,
    [ValidateSet('auto', 'boost', 'save-tokens')][string] $Mode,
    [string] $ReceiptPath = ''
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'ZdhGearReceipt.psm1') -Force
$receipt = New-ZdhGearReceipt -Task $Task -Mode $Mode -ReceiptPath $ReceiptPath
Save-ZdhGearReceipt -Receipt $receipt
$receipt | ConvertTo-Json -Depth 8
