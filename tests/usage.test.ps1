#Requires -Version 7.0
param([string]$PackageRoot = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('zdh-gears-usage-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($testRoot) | Out-Null
try {
    $usageScript = Join-Path $PackageRoot 'scripts/zdh-gears-usage.ps1'
    $path = Join-Path $testRoot 'exact.jsonl'
    $cases = @(
        @{ Name='wrong session'; Records=@(@{id='unrelated';usage=@{input_tokens=12;output_tokens=2}}); Status='unavailable' },
        @{ Name='ID alone'; Records=@(@{id='target'}); Status='unavailable' },
        @{ Name='invalid usage'; Records=@(@{id='target';usage=@{input_tokens=-1;output_tokens=2}}); Status='unavailable' },
        @{ Name='string usage'; Records=@(@{id='target';usage=@{input_tokens='12';output_tokens=2}}); Status='unavailable' },
        @{ Name='bad cached tokens'; Records=@(@{id='target';usage=@{input_tokens=12;output_tokens=2;cached_input_tokens=13}}); Status='unavailable' },
        @{ Name='exact usage'; Records=@(@{id='target';usage=@{input_tokens=12;output_tokens=2}},@{id='unrelated';usage=@{input_tokens=99;output_tokens=50}}); Status='observed' }
    )
    foreach ($case in $cases) {
        @($case.Records | ForEach-Object { $_ | ConvertTo-Json -Depth 6 -Compress }) | Set-Content $path -Encoding utf8NoBOM
        $result = & $usageScript -SessionPath $path -RunId target | ConvertFrom-Json
        if ($result.Status -ne $case.Status) { throw "Wrong usage status: $($case.Name)" }
        if ($case.Status -eq 'observed' -and ($result.InputTokens -ne 12 -or $result.OutputTokens -ne 2 -or $null -ne $result.ReasoningTokens)) { throw 'Wrong session attribution or missing fields treated as zero' }
    }
    Write-Host 'PASS: 6 exact-ID usage fixtures; missing/invalid usage stays unavailable'
} finally {
    $resolved = [IO.Path]::GetFullPath($testRoot)
    if ($resolved.StartsWith([IO.Path]::GetFullPath([IO.Path]::GetTempPath()), [StringComparison]::OrdinalIgnoreCase) -and (Split-Path $resolved -Leaf) -like 'zdh-gears-usage-*') { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
