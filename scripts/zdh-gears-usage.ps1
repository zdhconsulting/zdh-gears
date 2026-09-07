param(
 [Parameter(Mandatory=$true)][string]$SessionPath,
 [Parameter(Mandatory=$true)][string]$RunId,
 [string]$OutputPath=''
)
$ErrorActionPreference='Stop'
if (!(Test-Path -LiteralPath $SessionPath)) { throw "Session file not found: $SessionPath" }
$lines=Get-Content -LiteralPath $SessionPath
$matches=@()
foreach($line in $lines){ try { $o=$line|ConvertFrom-Json } catch { continue }; if($o.run_id -eq $RunId -or $o.session_id -eq $RunId -or $o.id -eq $RunId){$matches+=$o} }
if($matches.Count -eq 0){$result=[pscustomobject]@{Schema='zdh-gears.usage.v1';RunId=$RunId;Status='unavailable';Reason='No matching run or session record found.'}} else {$u=$matches[-1].usage; $result=[pscustomobject]@{Schema='zdh-gears.usage.v1';RunId=$RunId;Status='observed';InputTokens=$u.input_tokens;CachedInputTokens=$u.cached_input_tokens;OutputTokens=$u.output_tokens;ReasoningTokens=$u.reasoning_tokens;Records=$matches.Count}}
if($OutputPath){$result|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $OutputPath -Encoding UTF8}; $result|ConvertTo-Json -Depth 8
