#Requires -Version 7.0
param([string]$PackageRoot = (Split-Path -Parent $PSScriptRoot), [switch]$KeepTemp)
$ErrorActionPreference = 'Stop'
$temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) ('zdh-gears-execution-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($temporaryRoot) | Out-Null
$previousCapture = $env:ZDH_TEST_CAPTURE
$previousExit = $env:ZDH_TEST_EXIT
$pwshPath = (Get-Process -Id $PID).Path
function Assert([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
try {
    $fake = Join-Path $temporaryRoot 'fake codex.ps1'
    @('$prompt = @($input) -join "`n"', '[pscustomobject]@{ Arguments=@($args); Prompt=$prompt } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $env:ZDH_TEST_CAPTURE', 'exit ([int]$env:ZDH_TEST_EXIT)') | Set-Content -LiteralPath $fake -Encoding utf8NoBOM
    $env:ZDH_TEST_CAPTURE = Join-Path $temporaryRoot 'captured.json'
    $env:ZDH_TEST_EXIT = '0'
    $execPath = Join-Path $PackageRoot 'scripts/zdh-gears-exec.ps1'
    $routePath = Join-Path $PackageRoot 'scripts/zdh-gears-route.ps1'
    $index = 0
    foreach ($modeCase in @(
        @('auto','gpt-5.6-sol','low','fast','rename one label'),
        @('boost','gpt-6-astra','ultra','fast','rename one label'),
        @('save-tokens','gpt-5.3-codex-spark','low','standard','rename one label'),
        @('save-tokens','gpt-5.6-luna','low','standard','add a contact form'),
        @('save-tokens','gpt-5.6-sol','low','standard','debug one failing unit test'),
        @('save-tokens','gpt-6-astra','high','standard','implement authentication')
    )) {
        $receiptPath = Join-Path $temporaryRoot "run-$index.json"
        & $pwshPath -NoProfile -File $execPath -Task $modeCase[4] -Mode $modeCase[0] -CodexCommand $fake -ReceiptPath $receiptPath *> $null
        Assert ($LASTEXITCODE -eq 0) 'Fixture launcher failed'
        $captured = Get-Content -LiteralPath $env:ZDH_TEST_CAPTURE -Raw | ConvertFrom-Json
        $expectedArgs = @('exec','-c',('model="{0}"' -f $modeCase[1]),'-c',('model_reasoning_effort="{0}"' -f $modeCase[2]),'-c',('service_tier="{0}"' -f $modeCase[3]),'-')
        Assert (($captured.Arguments -join '|') -ceq ($expectedArgs -join '|')) 'Launcher did not pass exact selected arguments'
        Assert ($captured.Prompt -ceq $modeCase[4]) 'Prompt changed in stdin transport'
        $receipt = Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json
        Assert ($receipt.Mode -eq $modeCase[0] -and $receipt.Status -eq 'execution_succeeded' -and $receipt.ObservedExitCode -eq 0) 'Wrong process receipt'
        Assert ($receipt.ArgumentsPassed -and -not $receipt.Applied -and $receipt.ConfigurationStatus -eq 'unverified' -and $null -eq $receipt.ObservedConfiguration) 'Successful process must not claim backend observation'
        Assert ($receipt.RequestedConfiguration.Model -eq $modeCase[1]) 'Missing requested config'
        $index++
    }
    $special = "--help`nquotes: `"double`" 'single' & ; `$() שלום 😀"
    $receiptPath = Join-Path $temporaryRoot 'special.json'
    $specialOutput = & $pwshPath -NoProfile -File $execPath "-Task:$special" -CodexCommand $fake -ReceiptPath $receiptPath 2>&1
    if ($LASTEXITCODE -ne 0) { Write-Host ($specialOutput | Out-String) }
    Assert ($LASTEXITCODE -eq 0) 'Special prompt launch failed'
    $captured = Get-Content -LiteralPath $env:ZDH_TEST_CAPTURE -Raw | ConvertFrom-Json
    Assert ($captured.Prompt -ceq $special) 'Leading dashes, quotes, multiline or Unicode were changed'
    Assert ($captured.Arguments[-1] -eq '-' -and -not ($captured.Arguments -contains '--help')) 'Prompt interpreted as CLI option'
    Assert (-not ((Get-Content $receiptPath -Raw).Contains('שלום'))) 'Receipt persisted prompt text'
    $env:ZDH_TEST_EXIT = '23'
    $receiptPath = Join-Path $temporaryRoot 'failed.json'
    & $pwshPath -NoProfile -File $execPath -Task 'show git status' -CodexCommand $fake -ReceiptPath $receiptPath *> $null
    Assert ($LASTEXITCODE -eq 23) 'Native process exit code was not preserved'
    $receipt = Get-Content $receiptPath -Raw | ConvertFrom-Json
    Assert ($receipt.Status -eq 'execution_failed' -and $receipt.ObservedExitCode -eq 23 -and $receipt.ConfigurationStatus -eq 'unverified') 'Failure mislabeled as config mismatch'
    $receiptPath = Join-Path $temporaryRoot 'missing.json'
    & $pwshPath -NoProfile -File $execPath -Task 'show git status' -CodexCommand (Join-Path $temporaryRoot 'missing.exe') -ReceiptPath $receiptPath *> $null
    Assert ($LASTEXITCODE -eq 127) 'Missing command did not fail'
    $receipt = Get-Content $receiptPath -Raw | ConvertFrom-Json
    Assert ($receipt.Status -eq 'launch_failed' -and -not $receipt.ArgumentsPassed -and $null -eq $receipt.ObservedExitCode) 'Missing command falsely claims execution'
    $receiptPath = Join-Path $temporaryRoot 'dry.json'
    & $pwshPath -NoProfile -File $execPath -Task 'rename one label' -Mode save-tokens -CodexCommand (Join-Path $temporaryRoot 'missing.exe') -ReceiptPath $receiptPath -DryRun *> $null
    Assert ($LASTEXITCODE -eq 0) 'DryRun tried to resolve or launch CLI'
    $receipt = Get-Content $receiptPath -Raw | ConvertFrom-Json
    Assert ($receipt.Status -eq 'selected' -and -not $receipt.ArgumentsPassed -and $receipt.Model -eq 'gpt-5.3-codex-spark') 'DryRun receipt incorrect'
    Push-Location $temporaryRoot
    try {
        Import-Module (Join-Path $PackageRoot 'scripts/ZdhGearReceipt.psm1') -Force
        $relativeReceipt = New-ZdhGearReceipt -Task 'show git status' -ReceiptPath './relative.json'
        Assert ($relativeReceipt.ReceiptPath -eq (Join-Path $temporaryRoot 'relative.json')) 'Relative receipt ignored PowerShell location'
        Save-ZdhGearReceipt -Receipt $relativeReceipt
        Assert (Test-Path -LiteralPath (Join-Path $temporaryRoot 'relative.json')) 'Relative receipt written outside current location'
        & $pwshPath -NoProfile -File $routePath 'rename one label' *> $null
        Assert ($LASTEXITCODE -eq 0) 'Selection receipt failed'
        & $pwshPath -NoProfile -File $routePath 'rename one label' *> $null
        Assert ($LASTEXITCODE -eq 0) 'Second selection receipt failed'
        $receipts = @(Get-ChildItem -Filter 'zdh-gears-receipt-*.json')
        Assert ($receipts.Count -eq 2) 'Selection receipts overwrite previous run'
    } finally { Pop-Location }
    Write-Host 'PASS: launcher modes/argv/stdin/Unicode, process failures, missing CLI, DryRun, unique receipts; backend configuration remains unverified'
} finally {
    $env:ZDH_TEST_CAPTURE = $previousCapture
    $env:ZDH_TEST_EXIT = $previousExit
    $resolved = [IO.Path]::GetFullPath($temporaryRoot)
    if ($KeepTemp) { Write-Host "Test artifacts: $resolved" }
    elseif ($resolved.StartsWith([IO.Path]::GetFullPath([IO.Path]::GetTempPath()), [StringComparison]::OrdinalIgnoreCase) -and (Split-Path $resolved -Leaf) -like 'zdh-gears-execution-*') { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
