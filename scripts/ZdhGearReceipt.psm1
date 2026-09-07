Import-Module (Join-Path $PSScriptRoot 'CodexGear.psm1') -Force

function New-ZdhGearReceipt {
    param([Parameter(Mandatory = $true)][string] $Task, [string] $Mode, [string] $ReceiptPath)
    $requestArgs = @{ Text = $Task }
    if ($Mode) { $requestArgs.Mode = $Mode }
    $inputRequest = Resolve-CodexGearInput @requestArgs
    $gear = Get-CodexGear -Profile (Select-CodexGear @requestArgs)
    $runId = [guid]::NewGuid().ToString()
    if (-not $ReceiptPath) { $ReceiptPath = Join-Path (Get-Location) "zdh-gears-receipt-$runId.json" }
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $taskHash = -join ($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Task)) | ForEach-Object { $_.ToString('x2') }) }
    finally { $sha.Dispose() }
    $manifest = Get-Content -LiteralPath (Join-Path $PSScriptRoot '../.codex-plugin/plugin.json') -Raw | ConvertFrom-Json
    [pscustomobject][ordered]@{
        Schema = 'zdh-gears.execution-receipt.v3'
        PackageVersion = $manifest.version
        RunId = $runId
        ReceiptPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ReceiptPath)
        CreatedAt = [datetimeoffset]::UtcNow.ToString('o')
        CompletedAt = $null
        ElapsedMilliseconds = $null
        TaskHash = $taskHash
        Mode = $inputRequest.Mode
        SelectedProfile = $gear.Profile
        Gear = $gear.Gear
        Model = $gear.Model
        ReasoningEffort = $gear.Effort
        ServiceTier = $gear.ServiceTier
        ConfigArgs = @(New-CodexConfigArgs -Gear $gear)
        RequestedConfiguration = [pscustomobject]@{ Model = $gear.Model; ReasoningEffort = $gear.Effort; ServiceTier = $gear.ServiceTier }
        ObservedConfiguration = $null
        ConfigurationStatus = 'unverified'
        ArgumentsPassed = $false
        Applied = $false
        Status = 'selected'
        ObservedExitCode = $null
        ErrorCode = $null
        Note = 'Selection and process outcome are separate from backend configuration. No backend observation was collected; Applied remains false.'
    }
}

function Save-ZdhGearReceipt {
    param([Parameter(Mandatory = $true)][object] $Receipt)
    $parent = Split-Path -Parent $Receipt.ReceiptPath
    [IO.Directory]::CreateDirectory($parent) | Out-Null
    $temporaryPath = Join-Path $parent ('.zdh-receipt-' + [guid]::NewGuid().ToString('N') + '.tmp')
    try {
        [IO.File]::WriteAllText($temporaryPath, ($Receipt | ConvertTo-Json -Depth 8) + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
        Move-Item -LiteralPath $temporaryPath -Destination $Receipt.ReceiptPath -Force
    } finally {
        if (Test-Path -LiteralPath $temporaryPath) { Remove-Item -LiteralPath $temporaryPath -Force }
    }
}

Export-ModuleMember -Function New-ZdhGearReceipt, Save-ZdhGearReceipt
