#Requires -Version 7.0
param(
    [Parameter(Mandatory=$true)][string]$SessionPath,
    [Parameter(Mandatory=$true)][string]$RunId,
    [string]$OutputPath=''
)
$ErrorActionPreference='Stop'
if (!(Test-Path -LiteralPath $SessionPath -PathType Leaf)) { throw "Session file not found: $SessionPath" }
$result = [ordered]@{Schema='zdh-gears.usage.v1';RunId=$RunId;Status='unavailable';Reason='No exact-ID record with valid usage found. Launcher run IDs are not Codex session IDs.'}
foreach ($line in [IO.File]::ReadLines((Resolve-Path -LiteralPath $SessionPath).Path)) {
    try { $record = $line | ConvertFrom-Json -ErrorAction Stop } catch { continue }
    if ($record.run_id -cne $RunId -and $record.session_id -cne $RunId -and $record.id -cne $RunId) { continue }
    $usage = $record.usage
    $valid = $null -ne $usage
    foreach ($field in @('input_tokens','output_tokens')) {
        $value = $usage.$field
        if ($null -eq $value -or $value -is [string] -or $value -is [bool] -or $value -isnot [ValueType] -or $value -lt 0 -or [math]::Floor([double]$value) -ne $value) { $valid = $false }
    }
    foreach ($field in @('cached_input_tokens','reasoning_tokens')) {
        $value = $usage.$field
        if ($null -ne $value -and ($value -is [string] -or $value -is [bool] -or $value -isnot [ValueType] -or $value -lt 0 -or [math]::Floor([double]$value) -ne $value)) { $valid = $false }
    }
    if ($null -ne $usage.cached_input_tokens -and $usage.cached_input_tokens -gt $usage.input_tokens) { $valid = $false }
    if (-not $valid) { continue }
    $result = [ordered]@{Schema='zdh-gears.usage.v1';RunId=$RunId;Status='observed';InputTokens=$usage.input_tokens;CachedInputTokens=$usage.cached_input_tokens;OutputTokens=$usage.output_tokens;ReasoningTokens=$usage.reasoning_tokens;Basis='Exact-ID usage record supplied by the caller; not a savings calculation.'}
}
$jsonText = $result | ConvertTo-Json -Depth 8
if ($OutputPath) { [IO.File]::WriteAllText($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath), $jsonText, [Text.UTF8Encoding]::new($false)) }
$jsonText
