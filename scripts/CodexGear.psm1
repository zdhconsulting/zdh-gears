function Get-CodexGearMatrix {
    $matrix = [ordered]@{
        fast = [pscustomobject]@{
            Profile = "fast"
            Gear = "low"
            Model = "gpt-5.6-sol"
            Effort = "low"
            ServiceTier = "fast"
            Command = "exec"
            Purpose = "Low-scope work on GPT-5.6 with low reasoning: simple coding, status checks, typos, copy, links, and obvious one-file fixes."
        }
        balanced = [pscustomobject]@{
            Profile = "balanced"
            Gear = "medium"
            Model = "gpt-6-astra"
            Effort = "low"
            ServiceTier = "standard"
            Command = "exec"
            Purpose = "Compatibility alias for medium gear. Normal implementation work runs on Astra with low reasoning."
        }
        standard = [pscustomobject]@{
            Profile = "standard"
            Gear = "medium"
            Model = "gpt-6-astra"
            Effort = "low"
            ServiceTier = "standard"
            Command = "exec"
            Purpose = "Clear name for medium gear: normal implementation work on Astra with low reasoning."
        }
        deep = [pscustomobject]@{
            Profile = "deep"
            Gear = "high"
            Model = "gpt-6-astra"
            Effort = "high"
            ServiceTier = "standard"
            Command = "exec"
            Purpose = "High gear on Astra with high reasoning for debugging, CI/test failures, regressions, multi-file work, deploy problems, and verification-heavy tasks."
        }
        max = [pscustomobject]@{
            Profile = "max"
            Gear = "xhigh"
            Model = "gpt-6-astra"
            Effort = "ultra"
            ServiceTier = "standard"
            Command = "exec"
            Purpose = "Architecture, auth, security, billing, database, permissions, production-risk, or ambiguous complex failures on Astra with ultra reasoning."
        }
        review = [pscustomobject]@{
            Profile = "review"
            Gear = "review"
            Model = "gpt-6-astra"
            Effort = "high"
            ServiceTier = "standard"
            Command = "exec"
            Purpose = "High gear on Astra with high reasoning for explicit code review, PR review, diff review, or commit review."
        }
    }
    foreach ($alias in @(
        @{ Name = 'boost'; Target = 'max'; ServiceTier = 'fast'; Purpose = 'Boost Mode: Astra with ultra reasoning and fast service.' },
        @{ Name = 'saver'; Target = 'fast'; Model = 'gpt-5.3-codex-spark'; ServiceTier = 'standard'; Purpose = 'Save Tokens Mode: Spark with low reasoning for mechanical work.' },
        @{ Name = 'save-tokens'; Target = 'fast'; Model = 'gpt-5.3-codex-spark'; ServiceTier = 'standard'; Purpose = 'Alias for the mechanical Save Tokens profile.' },
        @{ Name = 'saver-compact'; Target = 'balanced'; Model = 'gpt-5.6-luna'; Purpose = 'Save Tokens Mode: Luna with low reasoning for recognized bounded implementation.' },
        @{ Name = 'saver-work'; Target = 'balanced'; Model = 'gpt-5.6-sol'; Purpose = 'Save Tokens Mode: Sol with low reasoning for explicitly bounded debugging.' },
        @{ Name = 'saver-risk'; Target = 'deep'; Purpose = 'Save Tokens Mode: Astra with high reasoning for sensitive, broad or intrinsically difficult work.' }
    )) {
        $target = $matrix[$alias.Target]
        $matrix[$alias.Name] = [pscustomobject]@{
            Profile = $alias.Name
            Gear = $target.Gear
            Model = if ($alias.Model) { $alias.Model } else { $target.Model }
            Effort = $target.Effort
            ServiceTier = if ($alias.ServiceTier) { $alias.ServiceTier } else { $target.ServiceTier }
            Command = $target.Command
            Purpose = $alias.Purpose
        }
    }
    return $matrix
}

function ConvertTo-ChatGatewayTaskText {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Text
    )

    return (($Text -replace "\s+", " ").Trim().ToLowerInvariant())
}

function Get-ChatGatewayTaskKey {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Text,
        [string] $Project = "Gateway"
    )

    $normalizedTask = ConvertTo-ChatGatewayTaskText -Text $Text
    $normalizedProject = ConvertTo-ChatGatewayTaskText -Text $Project
    $bytes = [System.Text.Encoding]::UTF8.GetBytes("$normalizedProject`n$normalizedTask")
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hashBytes = $sha.ComputeHash($bytes)
        return (($hashBytes | ForEach-Object { $_.ToString("x2") }) -join "")
    } finally {
        $sha.Dispose()
    }
}

function Test-ChatGatewayFreshnessSensitive {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Text
    )

    $normalized = ConvertTo-ChatGatewayTaskText -Text $Text
    return ($normalized -match "\b(today|tonight|tomorrow|yesterday|latest|current|recent|newest|news|live|now|as of|this week|this month|this quarter|price|pricing|stock|market|weather|schedule|score|standings|exchange rate|rate limit)\b")
}

function Get-ChatGatewayCacheEntry {
    param(
        [Parameter(Mandatory = $true)]
        [string] $CodexHome,
        [Parameter(Mandatory = $true)]
        [string] $Task,
        [string] $Project = "Gateway",
        [int] $TtlDays = 14,
        [switch] $IgnoreFreshness
    )

    $key = Get-ChatGatewayTaskKey -Text $Task -Project $Project
    $cachePath = Join-Path $CodexHome "cache\chatgpt-bridge\$key.json"

    if (-not $IgnoreFreshness -and (Test-ChatGatewayFreshnessSensitive -Text $Task)) {
        return [pscustomobject]@{
            Hit = $false
            Status = "freshness-bypass"
            Reason = "Task appears time-sensitive; cache reuse is disabled."
            Key = $key
            Path = $cachePath
            Entry = $null
        }
    }

    if (-not (Test-Path -LiteralPath $cachePath)) {
        return [pscustomobject]@{
            Hit = $false
            Status = "miss"
            Reason = "No exact completed ChatGPT result is cached for this project/task."
            Key = $key
            Path = $cachePath
            Entry = $null
        }
    }

    try {
        $entry = Get-Content -LiteralPath $cachePath -Raw | ConvertFrom-Json
    } catch {
        return [pscustomobject]@{
            Hit = $false
            Status = "invalid"
            Reason = "Cache entry could not be parsed: $($_.Exception.Message)"
            Key = $key
            Path = $cachePath
            Entry = $null
        }
    }

    $completedAt = $null
    if ($entry.CompletedAt) {
        try { $completedAt = [datetime]::Parse($entry.CompletedAt) } catch { $completedAt = $null }
    }
    if ($completedAt -and $TtlDays -gt 0 -and $completedAt -lt (Get-Date).AddDays(-1 * $TtlDays)) {
        return [pscustomobject]@{
            Hit = $false
            Status = "stale"
            Reason = "Cached result is older than $TtlDays day(s)."
            Key = $key
            Path = $cachePath
            Entry = $entry
        }
    }

    $handoffPath = if ($entry.HandoffPath) { $entry.HandoffPath } else { "" }
    $responsePath = if ($entry.ResponsePath) { $entry.ResponsePath } else { "" }
    $hasUsableText = ($handoffPath -and (Test-Path -LiteralPath $handoffPath)) -or
        ($responsePath -and (Test-Path -LiteralPath $responsePath))
    if (-not $hasUsableText) {
        return [pscustomobject]@{
            Hit = $false
            Status = "missing-artifact"
            Reason = "Cache metadata exists, but the handoff/response file is missing."
            Key = $key
            Path = $cachePath
            Entry = $entry
        }
    }

    return [pscustomobject]@{
        Hit = $true
        Status = "hit"
        Reason = "Exact completed ChatGPT result found."
        Key = $key
        Path = $cachePath
        Entry = $entry
    }
}

function Get-ChatGatewaySavingsEstimate {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Text,
        [string] $Route = "codex",
        [object[]] $ChatGPTSignals = @(),
        [string] $CodexFallbackProfile = "fast",
        [switch] $CacheHit
    )

    $wordCount = [regex]::Matches($Text, "\S+").Count
    $signalText = (($ChatGPTSignals | ForEach-Object { "$_" }) -join " ").ToLowerInvariant()
    $turns = 0
    $tokens = 0

    if ($Route -eq "chatgpt" -or $Route -eq "deepseek") {
        $turns = 1
        $tokens = 9000 + ([math]::Min($wordCount, 800) * 25)
        if ($signalText -match "research|strategy|ideas") { $tokens += 5000 }
        if ($signalText -match "design|creative|logo|image") { $tokens += 9000; $turns = 2 }
        if ($signalText -match "summary|explanation") { $tokens += 3000 }
        if ($Route -eq "deepseek") {
            if ($signalText -match "low-cost|volume|bulk|first-pass|seo|long-form|draft") { $tokens += 6000; $turns = 2 }
            if ($tokens -gt 4000) { $tokens = [int]($tokens * 0.9) }
        }
    } elseif ($Route -eq "hybrid") {
        $turns = 1
        $tokens = 6000 + ([math]::Min($wordCount, 600) * 18)
    }

    if ($Route -eq "chatgpt" -or $Route -eq "deepseek" -or $Route -eq "hybrid") {
        if ($CodexFallbackProfile -eq "deep") { $tokens += 6000 }
        if ($CodexFallbackProfile -eq "max") { $tokens += 12000 }
        if ($CacheHit) { $tokens += 3000 }
    }

    return [pscustomobject]@{
        Basis = "heuristic"
        AvoidedCodexTurns = $turns
        EstimatedAvoidedCodexTokens = [int]$tokens
        Note = "Not billing data; this is a routing pressure estimate for comparing gateway savings."
    }
}

function New-ChatGatewayHybridSplit {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Text
    )

    $codexTarget = "the local project"
    $fileMatch = [regex]::Match($Text, "\b[\w.-]+\.(ts|tsx|js|jsx|py|ps1|cmd|md|json|yml|yaml|toml|css|html|sql|sh|bat|cs|go|rs|java|php|rb)\b")
    if ($fileMatch.Success) {
        $codexTarget = $fileMatch.Value
    } elseif ($Text -match "(?i)\b(this project|project folder|site|app|repo|repository|workspace)\b") {
        $codexTarget = $Matches[1]
    }

    $chatTask = @"
Original hybrid request:
$Text

Do only the detachable ChatGPT-safe part: writing, brainstorming, strategy, summary, or design direction/generation. Do not inspect or claim access to local files, repo state, accounts, secrets, logs, tests, builds, git, deployment, or browser verification.

Return the useful deliverable and a CODEX_RETURN_PACKET. In "Codex next action", tell Codex exactly how to apply or verify the result locally in $codexTarget.
"@.Trim()

    $codexTask = "After importing the ChatGPT return packet, apply or verify the result locally in $codexTarget. Inspect files before editing and run the relevant local checks."

    return [pscustomobject]@{
        ChatGPTTask = $chatTask
        CodexTask = $codexTask
        LocalTarget = $codexTarget
        WillDispatchChatGPT = $true
        RequiresCodexAfterReturn = $true
    }
}

function Get-CodexLatestTokenSnapshot {
    param(
        [Parameter(Mandatory = $true)]
        [string] $CodexHome,
        [int] $MaxFiles = 8,
        [int] $Tail = 250,
        [int] $CacheSeconds = 60
    )

    $cachePath = Join-Path $CodexHome "cache\codex-latest-token-snapshot.json"
    if ($CacheSeconds -gt 0 -and (Test-Path -LiteralPath $cachePath)) {
        try {
            $cacheFile = Get-Item -LiteralPath $cachePath -ErrorAction Stop
            if ($cacheFile.LastWriteTime -gt (Get-Date).AddSeconds(-1 * $CacheSeconds)) {
                $cached = Get-Content -LiteralPath $cachePath -Raw | ConvertFrom-Json
                if ($cached) {
                    $cached | Add-Member -NotePropertyName FromCache -NotePropertyValue $true -Force
                    return $cached
                }
            }
        } catch {
            # Ignore stale or invalid telemetry cache and rescan.
        }
    }

    $sessionsDir = Join-Path $CodexHome "sessions"
    if (-not (Test-Path -LiteralPath $sessionsDir)) {
        return $null
    }

    $candidateFiles = @()
    for ($dayOffset = 0; $dayOffset -lt 4; $dayOffset++) {
        $day = (Get-Date).AddDays(-1 * $dayOffset)
        $dayDir = Join-Path $sessionsDir (Join-Path $day.ToString("yyyy") (Join-Path $day.ToString("MM") $day.ToString("dd")))
        if (Test-Path -LiteralPath $dayDir) {
            $candidateFiles += @(Get-ChildItem -LiteralPath $dayDir -Filter "*.jsonl" -File -ErrorAction SilentlyContinue)
        }
    }

    if ($candidateFiles.Count -eq 0) {
        $candidateFiles = @(Get-ChildItem -LiteralPath $sessionsDir -Recurse -Filter "*.jsonl" -File -ErrorAction SilentlyContinue)
    }

    $files = $candidateFiles |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First $MaxFiles

    foreach ($file in $files) {
        try {
            $lines = Get-Content -LiteralPath $file.FullName -Tail $Tail -ErrorAction Stop
        } catch {
            continue
        }

        for ($i = $lines.Count - 1; $i -ge 0; $i--) {
            $line = $lines[$i]
            if ($line -notmatch '"token_count"') { continue }
            try {
                $record = $line | ConvertFrom-Json
                if ($record.payload.type -ne "token_count") { continue }
                $usage = $record.payload.info.total_token_usage
                $lastUsage = $record.payload.info.last_token_usage
                $limits = if ($record.rate_limits) { $record.rate_limits } elseif ($record.payload.rate_limits) { $record.payload.rate_limits } else { $null }
                $snapshot = [pscustomobject]@{
                    SessionPath = $file.FullName
                    Timestamp = $record.timestamp
                    TotalTokens = $usage.total_tokens
                    InputTokens = $usage.input_tokens
                    CachedInputTokens = $usage.cached_input_tokens
                    OutputTokens = $usage.output_tokens
                    ReasoningOutputTokens = $usage.reasoning_output_tokens
                    LastTurnTokens = $lastUsage.total_tokens
                    ModelContextWindow = $record.payload.info.model_context_window
                    PlanType = if ($limits) { $limits.plan_type } else { $null }
                    PrimaryUsedPercent = if ($limits -and $limits.primary) { $limits.primary.used_percent } else { $null }
                    PrimaryWindowMinutes = if ($limits -and $limits.primary) { $limits.primary.window_minutes } else { $null }
                    PrimaryResetsAt = if ($limits -and $limits.primary) { $limits.primary.resets_at } else { $null }
                    SecondaryUsedPercent = if ($limits -and $limits.secondary) { $limits.secondary.used_percent } else { $null }
                    SecondaryWindowMinutes = if ($limits -and $limits.secondary) { $limits.secondary.window_minutes } else { $null }
                    SecondaryResetsAt = if ($limits -and $limits.secondary) { $limits.secondary.resets_at } else { $null }
                    FromCache = $false
                }
                try {
                    New-Item -ItemType Directory -Path (Split-Path -Parent $cachePath) -Force | Out-Null
                    $snapshot | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $cachePath -Encoding UTF8
                } catch {
                    # Telemetry cache is best-effort.
                }
                return $snapshot
            } catch {
                continue
            }
        }
    }

    return $null
}

function Get-CodexGear {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Profile
    )

    $matrix = Get-CodexGearMatrix
    if (-not $matrix.Contains($Profile)) {
        throw "Unknown Codex gear profile: $Profile"
    }
    return $matrix[$Profile]
}

function Resolve-CodexGearInput {
    param(
        [Parameter(Mandatory = $true)][string] $Text,
        [ValidateSet('auto', 'boost', 'save-tokens')][string] $Mode
    )
    $taskText = $Text.Trim()
    # Only a leading imperative mode directive is a request. Describing or
    # negating a mode elsewhere in the task must not activate it.
    $directive = [regex]::Match($taskText, '(?is)^(?:(?:enable|use|turn\s+on)\s+)?(?<mode>auto\s+selection(?:\s+mode)?|boost\s+mode|save(?:-|\s+)tokens\s+mode)(?:\s*:\s*|\s*[.!]?\s*$)')
    $resolvedMode = if ($Mode) { $Mode } else { 'auto' }
    if ($directive.Success) {
        if (-not $Mode) {
            $resolvedMode = switch -Regex ($directive.Groups['mode'].Value) {
                '^boost' { 'boost'; break }
                '^save' { 'save-tokens'; break }
                default { 'auto' }
            }
        }
        $taskText = $taskText.Substring($directive.Length)
    }
    [pscustomobject]@{ Mode = $resolvedMode; Text = $taskText }
}

function Select-CodexTaskProfile {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()][string] $Text
    )

    $normalized = ($Text -replace '\s+', ' ').Trim().ToLowerInvariant()
    $lowProfile = 'fast'
    $explicitReview =
        $normalized -match "\b(code|pr|pull request|diff|commit)\s+review\b" -or
        $normalized -match "\breview\s+(the\s+|this\s+)?(code|pr|pull request|diff|commit|changes)\b"

    # Destructive actions and intrinsically difficult work take precedence over
    # review intent, cosmetic wording, and requests to be quick or use low gear.
    if ($normalized -match '\b(delete|deleting|deletion|purge|wipe|truncate|drop|destroy|erase)\b' -or
        $normalized -match '\b(remove|removing)\b.*\b(records?|data|tables?|accounts?|backups?|directories|files?)\b' -or
        $normalized -match '\b(distributed consensus|consensus algorithm|raft|paxos|byzantine|race condition|deadlock|threading|data loss|production[- ]risk)\b') {
        return 'max'
    }

    # A bounded presentation edit can mention a sensitive topic without changing
    # that system. Require a whole-task match and reject additional actions.
    $surfaceEdit = $normalized -match '^(?:please )?(?:rename|reword|change|fix|correct|update)\s+(?:(?:the|a|one|single)\s+)?(?:[\w-]+\s+){0,3}(?:heading|label|title|typo|spelling|text|copy|color|spacing)(?:\s+(?:in|on|from|to)\s+[^.;!?]+)?[.!]?$'
    $additionalWork = $normalized -match '\b(and|then|also|plus|implement|design|build|create|enable|disable|bypass|grant|revoke|deploy|migrate|refactor|debug|rotate|reset|replace|across|all|code|logic|behavior|execute|vulnerability|flaw|failure|failing|regression)\b|[;&]'
    if ($surfaceEdit -and -not $additionalWork -and -not $explicitReview) {
        return $lowProfile
    }

    $score = 0

    $mediumPatterns = @(
        "\badd\b", "\bbuild\b", "\bcreate\b", "\bfix\b", "\bform\b",
        "\bpage\b", "\bcomponent\b", "\bstyle\b", "\bmobile\b", "\bresponsive\b",
        "\bscript\b", "\bhelper\b", "\bintegrate\b", "\bwire\b", "\bimplement\b"
    )
    foreach ($pattern in $mediumPatterns) {
        if ($normalized -match $pattern) { $score += 1 }
    }

    $highHits = 0
    $highPatterns = @(
        "\bdebug\b", "\bfailing\b", "\btest\b", "\bci\b", "\breview\b",
        "\bregression\b", "\bperformance\b", "\brefactor\b", "\bmigration\b",
        "\bmulti[- ]file\b", "\bacross the site\b", "\bproduction\b", "\bdeploy\b",
        "\bruntime crash\b", "\berror popup\b", "\bverify\b"
    )
    foreach ($pattern in $highPatterns) {
        if ($normalized -match $pattern) {
            $score += 2
            $highHits += 1
        }
    }

    $maxHits = 0
    $maxPatterns = @(
        "\barchitecture\b", "\bsecurity\b", "\bauth\b", "\bauthentication\b", "\bauthorization\b", "\boauth\b", "\bbilling\b",
        "\bpayments?\b", "\bdatabase\b", "\bdata loss\b", "\bpermissions?\b",
        "\bstrategy\b", "\bcomplex\b", "\brace condition\b", "\bthreading\b",
        "\bsecrets?\b", "\bapi keys?\b", "\bwebhooks?\b", "\bproduction-risk\b"
    )
    foreach ($pattern in $maxPatterns) {
        if ($normalized -match $pattern) {
            $score += 3
            $maxHits += 1
        }
    }

    # Sensitive nouns alone are not execution intent (e.g. 'authentication').
    # Require a substantive action or an explicit failure/risk signal.
    $substantiveWork = $normalized -match '\b(add|build|create|fix|implement|design|change|update|configure|enable|disable|integrate|wire|migrate|migration|refactor|debug|review|audit|verify|test|rotate|reset|replace|deploy|grant|revoke|bypass|repair|investigate|resolve)\b'
    $riskSignal = $normalized -match '\b(failing|regression|vulnerability|breach|outage|crash|race condition|data loss|production[- ]risk)\b'
    if ($maxHits -gt 0 -and ($substantiveWork -or $riskSignal)) { return "max" }
    if ($explicitReview) { return 'review' }
    if ($highHits -gt 0) { return "deep" }
    # Fast is an allowlist, not the absence of recognized difficult keywords.
    $simpleRead = $normalized -match '^(?:please )?(?:show me|list|check whether|does)\b.*\b(?:files?|folders?|labels?|links?|status|exist)\b[?.]?$' -or
        $normalized -match '^(?:please )?(?:show |check |get )?(?:the )?(?:git |build |task )?status[?.]?$'
    if ($simpleRead -and -not $substantiveWork -and -not $additionalWork -and $maxHits -eq 0) { return $lowProfile }
    # Unknown and underspecified requests retain Astra instead of silently
    # downgrading to the low-scope model.
    if ($score -le 3) { return "balanced" }
    return "deep"
}

function Select-CodexGear {
    param(
        [Parameter(Mandatory = $true)][string] $Text,
        [ValidateSet('auto', 'boost', 'save-tokens')][string] $Mode
    )
    $inputRequest = if ($Mode) { Resolve-CodexGearInput -Text $Text -Mode $Mode } else { Resolve-CodexGearInput -Text $Text }
    if ($inputRequest.Mode -eq 'boost') { return 'boost' }
    $profile = Select-CodexTaskProfile -Text $inputRequest.Text
    if ($inputRequest.Mode -ne 'save-tokens') { return $profile }

    $normalized = ($inputRequest.Text -replace '\s+', ' ').Trim().ToLowerInvariant()
    if (-not $normalized) { return 'saver' }
    if ($profile -eq 'max') { return 'saver-risk' }
    if ($profile -eq 'review') { return 'review' }

    # Scope and risk outrank a cheap-model request. A bounded phrase embedded in
    # broader work cannot downshift that whole request to Luna or Sol.
    $broadWork = $normalized -match '\b(production|prod|deploy(?:ment)?|migrat(?:e|ion)|multi[- ]file|codebase|repository[- ]wide|across|entire|all|every|system[- ]wide|multiple|several|full|whole|rebuild|rewrite|redesign|overhaul|from scratch)\b' -or
        $normalized -match '\b(build|create|implement) (?:(?:an?|the) )?(?:application|app|platform|system)\b'
    $compoundWork = $normalized -match '\b(and|then|also|plus)\b|[,;&]|[.!?]\s+\S'
    if ($broadWork) { return 'saver-risk' }
    if ($profile -eq 'fast' -and -not $compoundWork) { return 'saver' }
    $boundedDebug = $normalized -match '^(?:please )?(?:debug|fix|investigate|resolve) (?:(?:one|a single|a specific|an isolated) (?:failing |broken )?(?:unit test|test|helper|component|function)|(?:a )?(?:bug|regression|failure) in (?:one|a single|a specific|an isolated) (?:unit test|test|helper|component|function))(?: in [\w./\\-]+)?[.!]?$'
    if ($profile -eq 'deep') {
        if ($boundedDebug -and -not $compoundWork) { return 'saver-work' }
        return 'deep'
    }
    $boundedImplementation = $normalized -match '^(?:please )?(?:add|build|create|implement|fix|style|update|change) (?:(?:the|a|an|one|single) )?(?:(?!(?:with|including|containing|that)\b)[\w-]+ ){0,3}(?:form|component|helper|page|button|label|heading|link|style|function|card)(?: (?:in|on|for|to) [\w./\\-]+)?[.!]?$'
    if ($boundedImplementation -and -not $compoundWork) { return 'saver-compact' }
    # Unknown requests retain Astra low. No availability-based retries or
    # assumptions about remaining allowance are made by this deterministic rule.
    if ($profile -eq 'fast') { return 'balanced' }
    return $profile
}

function Select-AiWorkRoute {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Text,
        [switch] $ForceCodex,
        [switch] $ForceChatGPT
    )

    $normalized = $Text.ToLowerInvariant()
    $signals = New-Object System.Collections.Generic.List[string]

    $forceCodexTag = $normalized -match "\[(codex|force-codex)\]" -or $normalized -match "(?:^|\s)--(codex|force-codex)\b"
    $forceChatGptTag = $normalized -match "\[(chatgpt|gpt|force-chatgpt)\]" -or $normalized -match "(?:^|\s)--(chatgpt|gpt|force-chatgpt)\b"
    $localOnlyDirective = $normalized -match "\b(local only|local-only|run locally|execute locally|keep this local|local-first|internal local context only|only local)\b"

    if ($localOnlyDirective) {
        $signals.Add("local restriction stated")
        return [pscustomobject]@{
            Route = "codex"
            Reason = "A local-only restriction was stated."
            Confidence = "high"
            Signals = $signals.ToArray()
        }
    }

    if ($ForceCodex -or $forceCodexTag) {
        $signals.Add("explicit Codex override")
        return [pscustomobject]@{
            Route = "codex"
            Reason = "Explicit Codex override was provided."
            Confidence = "high"
            Signals = $signals.ToArray()
        }
    }

    if ($ForceChatGPT -or $forceChatGptTag) {
        $signals.Add("explicit ChatGPT override")
        return [pscustomobject]@{
            Route = "chatgpt"
            Reason = "Explicit ChatGPT override was provided."
            Confidence = "high"
            Signals = $signals.ToArray()
        }
    }

    $gearOverride = $normalized -match "\[(low|fast|medium|balanced|high|deep|xhigh|max|review)\]" -or
        $normalized -match "(?:^|\s)--(low|fast|medium|balanced|standard|high|deep|xhigh|max|review)\b"
    if ($gearOverride) {
        $signals.Add("explicit Codex gear override")
        return [pscustomobject]@{
            Route = "codex"
            Reason = "A Codex gear override was provided, so the optimizer will not divert it."
            Confidence = "high"
            Signals = $signals.ToArray()
        }
    }

    $codexSignals = [ordered]@{
        "local files or repo context" = "(\b(repo|repository|codebase|workspace|local files?|filesystem|folder|directory|path|cwd)\b|[a-z]:\\|\.codex|agents\.md)"
        "code/build/test/git work" = "(\b(code|codebase|implement|implementation|component|page|route|api|endpoint|database|migration|schema|script|fix|bug|debug|tests|build|lint|typecheck|git|commit|branch|push|pull request|pr|ci|github actions|deploy|deployment|logs?|stack trace|crash|terminal|shell|powershell|cmd|npm|pnpm|yarn|python|node)\b|\b(failing|broken|unit|integration|e2e|smoke|regression)\s+tests?\b|\b(run|rerun|execute|write|add)\s+tests?\b)"
        "browser or app verification" = "\b(browser|chrome|screenshot|playwright|localhost|127\.0\.0\.1|app verification|responsive|mobile|desktop qa)\b"
        "connected apps or private account state" = "\b(gmail|email inbox|inbox|slack|notion|linear|jira|github|vercel|supabase|stripe|datadog|sentry|google analytics|search console|cloudflare|zapier|make\.com|connector|mcp|app session)\b"
        "local asset generation or export" = "(\b(save|export|download|render)\b.*\b(logos?|images?|assets?|png|jpe?g|svg|webp|pdf)\b|\b(logos?|images?|assets?|png|jpe?g|svg|webp|pdf)\b.*\b(save|export|download|render)\b)"
        "sensitive or production risk" = "\b(auth|oauth|security|secret|token|permissions?|billing|payments?|production|prod|owner button|env vars?|api key)\b"
        "specific file path or extension" = "\b[\w.-]+\.(ts|tsx|js|jsx|py|ps1|cmd|md|json|yml|yaml|toml|css|html|sql|sh|bat|cs|go|rs|java|php|rb)\b"
    }
    foreach ($entry in $codexSignals.GetEnumerator()) {
        if ($normalized -match $entry.Value) {
            $signals.Add($entry.Key)
        }
    }

    if ($signals.Count -gt 0) {
        return [pscustomobject]@{
            Route = "codex"
            Reason = "The task appears to need Codex-local context, tools, verification, or sensitive handling."
            Confidence = "high"
            Signals = $signals.ToArray()
        }
    }

    $chatGptSignals = [ordered]@{
        "writing or copy" = "\b(write|rewrite|draft|polish|edit|improve|email|message|post|copy|tone|headline|tagline|slogan)\b"
        "ideas or strategy" = "\b(brainstorm|ideate|ideas?|naming|name ideas|domain names?|strategy|plan|critique|second opinion|options?|pros and cons|positioning|offer|angle|campaign|go-to-market|gtm)\b"
        "summary or explanation" = "\b(summarize|summary|outline|explain|teach|learn|notes?|meeting notes|synthesis|classify)\b"
        "research or comparison without local execution" = "\b(research|compare|competitor|market scan|best practices|examples?|sources?|literature|overview|look up|lookup|latest|current|recent|newest|today|what is|who is)\b"
        "translation or transformation" = "\b(translate|transcribe cleanup|condense|expand|turn .* into|convert .* into)\b"
        "design direction" = "\b(moodboard|layout concept|design direction|ad concept|poster concept|social concept|image prompt|color palette|typography|logos?|logo concepts?|brand identity|visual identity|wordmark|brand mark)\b"
    }
    foreach ($entry in $chatGptSignals.GetEnumerator()) {
        if ($normalized -match $entry.Value) {
            $signals.Add($entry.Key)
        }
    }

    if ($signals.Count -gt 0) {
        return [pscustomobject]@{
            Route = "chatgpt"
            Reason = "The task is a high-confidence non-repo handoff that can preserve Codex usage."
            Confidence = "high"
            Signals = $signals.ToArray()
        }
    }

    return [pscustomobject]@{
        Route = "codex"
        Reason = "No high-confidence ChatGPT handoff signal was found."
        Confidence = "low"
        Signals = @()
    }
}

function Select-ChatGatewayRoute {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Text,
        [switch] $ForceCodex,
        [switch] $ForceChatGPT
    )

    $normalized = $Text.ToLowerInvariant()
    $codexSignals = New-Object System.Collections.Generic.List[string]
    $chatGptSignals = New-Object System.Collections.Generic.List[string]
    $localOnlyDirective = $normalized -match "\b(local only|local-only|run locally|execute locally|keep this local|local-first|internal local context only|only local)\b"

    $forceCodexTag = $normalized -match "\[(codex|force-codex)\]" -or $normalized -match "(?:^|\s)--(codex|force-codex)\b"
    $forceChatGptTag = $normalized -match "\[(chatgpt|gpt|force-chatgpt)\]" -or $normalized -match "(?:^|\s)--(chatgpt|gpt|force-chatgpt)\b"

    if ($localOnlyDirective) {
        return [pscustomobject]@{
            Route = "codex"
            Dispatch = "codex-auto"
            Reason = "A local-only restriction was stated, so provider routing is suppressed."
            Confidence = "high"
            AskFirst = $false
            CodexSignals = @("local restriction stated")
            ChatGPTSignals = @()
            NextAction = "Dispatch through codex-auto with local execution only."
        }
    }

    if ($ForceCodex -or $forceCodexTag) {
        $codexSignals.Add("explicit Codex override")
        return [pscustomobject]@{
            Route = "codex"
            Dispatch = "codex-auto"
            Reason = "Explicit Codex override was provided."
            Confidence = "high"
            AskFirst = $false
            CodexSignals = $codexSignals.ToArray()
            ChatGPTSignals = @()
            NextAction = "Dispatch through codex-auto with credit optimization disabled."
        }
    }

    if ($ForceChatGPT -or $forceChatGptTag) {
        $chatGptSignals.Add("explicit ChatGPT override")
        return [pscustomobject]@{
            Route = "chatgpt"
            Dispatch = "chatgpt-auto-route"
            Reason = "Explicit ChatGPT override was provided."
            Confidence = "high"
            AskFirst = $false
            CodexSignals = @()
            ChatGPTSignals = $chatGptSignals.ToArray()
            NextAction = "Prepare a ChatGPT bridge session with a compact return packet."
        }
    }

    $gearOverride = $normalized -match "\[(low|fast|medium|balanced|high|deep|xhigh|max|review)\]" -or
        $normalized -match "(?:^|\s)--(low|fast|medium|balanced|standard|high|deep|xhigh|max|review)\b"
    if ($gearOverride) {
        $codexSignals.Add("explicit Codex gear override")
    }

    $codexSignalDefs = [ordered]@{
        "local files or repo context" = "(\b(repo|repository|codebase|workspace|local files?|filesystem|folder|directory|path|cwd|project folder|this project)\b|[a-z]:\\|\.codex|agents\.md)"
        "code/build/test/git work" = "(\b(code|codebase|implement|implementation|component|page|route|api|endpoint|database|migration|schema|script|fix|bug|debug|tests|build|lint|typecheck|git|commit|branch|push|pull request|pr|ci|github actions|deploy|deployment|logs?|stack trace|crash|terminal|shell|powershell|cmd|npm|pnpm|yarn|python|node)\b|\b(failing|broken|unit|integration|e2e|smoke|regression)\s+tests?\b|\b(run|rerun|execute|write|add)\s+tests?\b)"
        "browser or app verification" = "\b(browser|chrome|screenshot|playwright|localhost|127\.0\.0\.1|app verification|responsive|mobile|desktop qa)\b"
        "connected apps or private account state" = "\b(gmail|email inbox|inbox|slack|notion|linear|jira|github|vercel|supabase|stripe|datadog|sentry|google analytics|search console|cloudflare|zapier|make\.com|connector|mcp|app session)\b"
        "local asset generation or export" = "(\b(save|export|download|render|wire|apply)\b.*\b(logos?|images?|assets?|png|jpe?g|svg|webp|pdf|site|page|project|folder)\b|\b(logos?|images?|assets?|png|jpe?g|svg|webp|pdf)\b.*\b(save|export|download|render|wire|apply)\b)"
        "sensitive or production risk" = "\b(auth|oauth|security|secret|token|permissions?|billing|payments?|production|prod|owner button|env vars?|api key)\b"
        "specific file path or extension" = "\b[\w.-]+\.(ts|tsx|js|jsx|py|ps1|cmd|md|json|yml|yaml|toml|css|html|sql|sh|bat|cs|go|rs|java|php|rb)\b"
    }

    $chatGptSignalDefs = [ordered]@{
        "writing or copy" = "\b(write|rewrite|draft|polish|edit|improve|email|message|post|copy|tone|headline|tagline|slogan|cold email|sales copy)\b"
        "ideas or strategy" = "\b(brainstorm|ideate|ideas?|naming|name ideas|domain names?|strategy|plan|critique|second opinion|options?|pros and cons|positioning|offer|angle|campaign|go-to-market|gtm)\b"
        "summary or explanation" = "\b(summarize|summary|outline|explain|teach|learn|notes?|meeting notes|synthesis|classify|pasted text)\b"
        "research or comparison without local execution" = "\b(research|compare|competitor|market scan|best practices|examples?|sources?|literature|overview|look up|lookup|latest|current|recent|newest|today|what is|who is)\b"
        "translation or transformation" = "\b(translate|transcribe cleanup|condense|expand|turn .* into|convert .* into)\b"
        "design or creative generation" = "\b(moodboard|layout concept|design direction|ad concept|poster concept|social concept|image prompt|color palette|typography|logos?|logo sheet|logo concepts?|brand identity|visual identity|wordmark|brand mark|visual mockup|ad creative)\b"
    }

    foreach ($entry in $codexSignalDefs.GetEnumerator()) {
        if ($normalized -match $entry.Value -and -not $codexSignals.Contains($entry.Key)) {
            $codexSignals.Add($entry.Key)
        }
    }
    foreach ($entry in $chatGptSignalDefs.GetEnumerator()) {
        if ($normalized -match $entry.Value) {
            $chatGptSignals.Add($entry.Key)
        }
    }

    $hasSensitiveSignal = $codexSignals.Contains("sensitive or production risk") -or
        $codexSignals.Contains("connected apps or private account state")
    $hasCodexSignals = $codexSignals.Count -gt 0
    $hasChatGptSignals = $chatGptSignals.Count -gt 0

    if ($hasSensitiveSignal) {
        return [pscustomobject]@{
            Route = "codex"
            Dispatch = "codex-auto"
            Reason = "Sensitive, account, connector, or production-risk work must stay in Codex unless explicitly forced."
            Confidence = "high"
            AskFirst = $true
            CodexSignals = $codexSignals.ToArray()
            ChatGPTSignals = $chatGptSignals.ToArray()
            NextAction = "Keep in Codex; use ChatGPT only for a bounded second opinion after approval if needed."
        }
    }

    if ($hasCodexSignals -and $hasChatGptSignals) {
        return [pscustomobject]@{
            Route = "hybrid"
            Dispatch = "ask-first"
            Reason = "The task mixes detachable ChatGPT work with local Codex execution."
            Confidence = "medium"
            AskFirst = $true
            CodexSignals = $codexSignals.ToArray()
            ChatGPTSignals = $chatGptSignals.ToArray()
            NextAction = "Ask before splitting: ChatGPT should do the detachable thinking or creative pass, then Codex should apply or verify locally."
        }
    }

    if ($hasChatGptSignals) {
        return [pscustomobject]@{
            Route = "chatgpt"
            Dispatch = "chatgpt-auto-route"
            Reason = "The task is high-confidence detachable work and can preserve Codex usage."
            Confidence = "high"
            AskFirst = $false
            CodexSignals = @()
            ChatGPTSignals = $chatGptSignals.ToArray()
            NextAction = "Prepare a ChatGPT bridge session with a compact return packet."
        }
    }

    if ($hasCodexSignals) {
        return [pscustomobject]@{
            Route = "codex"
            Dispatch = "codex-auto"
            Reason = "The task appears to need local files, tools, verification, or Codex execution."
            Confidence = "high"
            AskFirst = $false
            CodexSignals = $codexSignals.ToArray()
            ChatGPTSignals = @()
            NextAction = "Dispatch through codex-auto with credit optimization disabled."
        }
    }

    return [pscustomobject]@{
        Route = "codex"
        Dispatch = "codex-auto"
        Reason = "No high-confidence ChatGPT handoff signal was found."
        Confidence = "low"
        AskFirst = $true
        CodexSignals = @()
        ChatGPTSignals = @()
        NextAction = "Keep in Codex unless the user explicitly forces ChatGPT."
    }
}

function Select-AiProviderRoute {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Text,
        [string] $Project = "General",
        [string] $Cwd = "",
        [switch] $ForceCodex,
        [switch] $ForceChatGPT,
        [switch] $ForceDeepSeek
    )

    $normalized = $Text.ToLowerInvariant()
    $projectText = "$Project $Cwd".ToLowerInvariant()
    $deepSeekSignals = New-Object System.Collections.Generic.List[string]
    $chatGptStrengthSignals = New-Object System.Collections.Generic.List[string]
    $localOnlyDirective = $normalized -match "\b(local only|local-only|run locally|execute locally|keep this local|local-first|internal local context only|only local)\b"

    $forceCodexTag = $normalized -match "\[(codex|force-codex)\]" -or $normalized -match "\s--(codex|force-codex)\b"
    $forceChatGptTag = $normalized -match "\[(chatgpt|gpt|force-chatgpt)\]" -or $normalized -match "\s--(chatgpt|gpt|force-chatgpt)\b"
    $forceDeepSeekTag = $normalized -match "\[(deepseek|force-deepseek)\]" -or $normalized -match "(?:^|\s)--(deepseek|force-deepseek)\b"

    if ($localOnlyDirective -and -not $ForceCodex) {
        $base = Select-ChatGatewayRoute -Text $Text -ForceCodex
        return [pscustomobject]@{
            Route = "codex"
            Provider = "codex"
            Dispatch = $base.Dispatch
            Reason = $base.Reason
            Confidence = "high"
            AskFirst = $false
            CodexSignals = $base.CodexSignals
            ChatGPTSignals = @()
            DeepSeekSignals = @()
            NextAction = $base.NextAction
        }
    }

    if ($ForceCodex -or $forceCodexTag) {
        $base = Select-ChatGatewayRoute -Text $Text -ForceCodex
        return [pscustomobject]@{
            Route = "codex"
            Provider = "codex"
            Dispatch = $base.Dispatch
            Reason = $base.Reason
            Confidence = "high"
            AskFirst = $false
            CodexSignals = $base.CodexSignals
            ChatGPTSignals = @()
            DeepSeekSignals = @()
            NextAction = $base.NextAction
        }
    }

    if ($ForceChatGPT -or $forceChatGptTag) {
        $base = Select-ChatGatewayRoute -Text $Text -ForceChatGPT
        return [pscustomobject]@{
            Route = "chatgpt"
            Provider = "chatgpt"
            Dispatch = $base.Dispatch
            Reason = $base.Reason
            Confidence = "high"
            AskFirst = $false
            CodexSignals = @()
            ChatGPTSignals = $base.ChatGPTSignals
            DeepSeekSignals = @()
            NextAction = $base.NextAction
        }
    }

    if ($ForceDeepSeek -or $forceDeepSeekTag) {
        $deepSeekSignals.Add("explicit DeepSeek override")
        return [pscustomobject]@{
            Route = "deepseek"
            Provider = "deepseek"
            Dispatch = "deepseek-route"
            Reason = "Explicit DeepSeek override was provided."
            Confidence = "high"
            AskFirst = $false
            CodexSignals = @()
            ChatGPTSignals = @()
            DeepSeekSignals = $deepSeekSignals.ToArray()
            NextAction = "Prepare a DeepSeek bridge session with a compact return packet."
        }
    }

    $baseRoute = Select-ChatGatewayRoute -Text $Text

    $deepSeekSignalDefs = [ordered]@{
        "explicit DeepSeek mention" = "\bdeepseek\b"
        "low-cost or volume work" = "\b(low[- ]cost|cheap|cheaper|free|unlimited|bulk|volume|scale|many|batch|first[- ]pass|first pass|rough draft|quick draft)\b"
        "SEO or long-form draft" = "\b(seo article|seo content|blog post|article draft|content draft|content packet|writer packet|writer lane|long[- ]form|longform|draft article|draft content)\b"
        "comparison or alternate draft" = "\b(compare drafts?|comparison draft|alternate draft|alternative draft|second draft|second opinion draft|variant draft)\b"
        "Mr.SEO DeepSeek lane" = "\b(mr\.?seo|mr seo|article desk|writer room|deepseek writer|provider grades?)\b"
    }
    $chatGptStrengthDefs = [ordered]@{
        "premium writing or final polish" = "\b(polish|final draft|premium|best quality|executive|client-ready|sales email|cold email|email|copy|tone|rewrite)\b"
        "creative brand or image generation" = "\b(logos?|logo sheet|brand identity|visual identity|image generation|generate images?|ad creative|poster|moodboard|layout concept|design direction)\b"
        "strategy or positioning" = "\b(strategy|positioning|offer|angle|go-to-market|gtm|campaign|critique|pros and cons|options?)\b"
        "research synthesis or explanation" = "\b(research synthesis|explain|teach|learning|summary|summarize|meeting notes|outline|market scan)\b"
        "explicit ChatGPT mention" = "\b(chatgpt|gpt)\b"
    }

    foreach ($entry in $deepSeekSignalDefs.GetEnumerator()) {
        if (($normalized -match $entry.Value -or $projectText -match $entry.Value) -and -not $deepSeekSignals.Contains($entry.Key)) {
            $deepSeekSignals.Add($entry.Key)
        }
    }
    foreach ($entry in $chatGptStrengthDefs.GetEnumerator()) {
        if ($normalized -match $entry.Value -and -not $chatGptStrengthSignals.Contains($entry.Key)) {
            $chatGptStrengthSignals.Add($entry.Key)
        }
    }

    $codexSignals = @($baseRoute.CodexSignals)
    $chatGptSignals = @($baseRoute.ChatGPTSignals + $chatGptStrengthSignals.ToArray()) | Where-Object { $_ } | Select-Object -Unique
    $hasCodexSignals = $codexSignals.Count -gt 0
    $hasDeepSeekSignals = $deepSeekSignals.Count -gt 0
    $hasChatGptSignals = $chatGptSignals.Count -gt 0
    $hasSensitiveSignal = $codexSignals -contains "sensitive or production risk" -or
        $codexSignals -contains "connected apps or private account state"
    $onlyMrSeoContextDeepSeekSignal = $hasDeepSeekSignals -and
        $deepSeekSignals.Count -eq 1 -and
        $deepSeekSignals.Contains("Mr.SEO DeepSeek lane")

    if ($hasCodexSignals -and $onlyMrSeoContextDeepSeekSignal) {
        return [pscustomobject]@{
            Route = "codex"
            Provider = "codex"
            Dispatch = "codex-auto"
            Reason = "Mr.SEO project context alone is not enough to move local code, test, git, or verification work to DeepSeek."
            Confidence = "high"
            AskFirst = $false
            CodexSignals = $codexSignals
            ChatGPTSignals = $chatGptSignals
            DeepSeekSignals = $deepSeekSignals.ToArray()
            NextAction = "Keep local Mr.SEO execution in Codex; use DeepSeek only for clearly detachable low-cost drafts or explicit DeepSeek tasks."
        }
    }

    if ($hasSensitiveSignal) {
        return [pscustomobject]@{
            Route = "codex"
            Provider = "codex"
            Dispatch = "codex-auto"
            Reason = "Sensitive, account, connector, or production-risk work must stay in Codex unless explicitly forced."
            Confidence = "high"
            AskFirst = $true
            CodexSignals = $codexSignals
            ChatGPTSignals = $chatGptSignals
            DeepSeekSignals = $deepSeekSignals.ToArray()
            NextAction = "Keep in Codex; use external providers only for bounded second opinions after approval if needed."
        }
    }

    $deepSeekScore = 0
    foreach ($signal in $deepSeekSignals) {
        if ($signal -eq "explicit DeepSeek mention") { $deepSeekScore += 4 }
        elseif ($signal -eq "low-cost or volume work") { $deepSeekScore += 3 }
        elseif ($signal -eq "SEO or long-form draft") { $deepSeekScore += 3 }
        elseif ($signal -eq "Mr.SEO DeepSeek lane") { $deepSeekScore += 3 }
        else { $deepSeekScore += 2 }
    }

    $chatGptScore = 0
    foreach ($signal in $chatGptSignals) {
        if ($signal -eq "explicit ChatGPT mention") { $chatGptScore += 4 }
        elseif ($signal -eq "creative brand or image generation") { $chatGptScore += 4 }
        elseif ($signal -eq "premium writing or final polish") { $chatGptScore += 3 }
        else { $chatGptScore += 2 }
    }

    $selectedProvider = ""
    $selectedSignals = @()
    if ($hasDeepSeekSignals -and ($deepSeekScore -gt $chatGptScore)) {
        $selectedProvider = "deepseek"
        $selectedSignals = $deepSeekSignals.ToArray()
    } elseif ($hasChatGptSignals) {
        $selectedProvider = "chatgpt"
        $selectedSignals = $chatGptSignals
    } elseif ($hasDeepSeekSignals) {
        $selectedProvider = "deepseek"
        $selectedSignals = $deepSeekSignals.ToArray()
    }

    if ($hasCodexSignals -and $selectedProvider) {
        return [pscustomobject]@{
            Route = "hybrid"
            Provider = $selectedProvider
            Dispatch = "ask-first"
            Reason = "The task mixes $selectedProvider-safe work with local Codex execution."
            Confidence = "medium"
            AskFirst = $true
            CodexSignals = $codexSignals
            ChatGPTSignals = $chatGptSignals
            DeepSeekSignals = $deepSeekSignals.ToArray()
            NextAction = "Split the external-provider part from the local Codex execution; Codex should apply or verify after the return packet."
        }
    }

    if ($selectedProvider -eq "deepseek") {
        return [pscustomobject]@{
            Route = "deepseek"
            Provider = "deepseek"
            Dispatch = "deepseek-route"
            Reason = "The task matches DeepSeek's low-cost, first-pass, volume, SEO-content, or comparison lane."
            Confidence = "high"
            AskFirst = $false
            CodexSignals = @()
            ChatGPTSignals = $chatGptSignals
            DeepSeekSignals = $selectedSignals
            NextAction = "Prepare a DeepSeek bridge session with a compact return packet; Codex handles local QA and publishing."
        }
    }

    if ($selectedProvider -eq "chatgpt") {
        return [pscustomobject]@{
            Route = "chatgpt"
            Provider = "chatgpt"
            Dispatch = "chatgpt-auto-route"
            Reason = "The task matches ChatGPT's premium creative, image, strategy, explanation, or polished writing lane."
            Confidence = "high"
            AskFirst = $false
            CodexSignals = @()
            ChatGPTSignals = $selectedSignals
            DeepSeekSignals = $deepSeekSignals.ToArray()
            NextAction = "Prepare a ChatGPT bridge session with a compact return packet."
        }
    }

    return [pscustomobject]@{
        Route = $baseRoute.Route
        Provider = if ($baseRoute.Route -eq "chatgpt") { "chatgpt" } elseif ($baseRoute.Route -eq "hybrid") { "chatgpt" } else { "codex" }
        Dispatch = $baseRoute.Dispatch
        Reason = $baseRoute.Reason
        Confidence = $baseRoute.Confidence
        AskFirst = $baseRoute.AskFirst
        CodexSignals = $codexSignals
        ChatGPTSignals = $chatGptSignals
        DeepSeekSignals = $deepSeekSignals.ToArray()
        NextAction = $baseRoute.NextAction
    }
}

function Get-CodexExecutable {
    $candidates = New-Object System.Collections.Generic.List[string]

    if ($env:CODEX_CLI_PATH) {
        $candidates.Add($env:CODEX_CLI_PATH)
    }

    $binRoot = Join-Path $env:LOCALAPPDATA "OpenAI\Codex\bin"
    if (Test-Path -LiteralPath $binRoot) {
        Get-ChildItem -LiteralPath $binRoot -Recurse -Filter "codex.exe" -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            ForEach-Object { $candidates.Add($_.FullName) }
    }

    foreach ($name in @("codex.exe", "codex")) {
        $command = Get-Command $name -ErrorAction SilentlyContinue
        if ($command -and $command.Source) {
            $candidates.Add($command.Source)
        }
    }

    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate)) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    throw "Could not find codex.exe. Install or sign into Codex Desktop, then retry."
}

function New-CodexConfigArgs {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject] $Gear
    )

    $args = @(
        "-c", "model=`"$($Gear.Model)`"",
        "-c", "model_reasoning_effort=`"$($Gear.Effort)`""
    )
    if ($null -ne $Gear.ServiceTier) {
        $args += @("-c", "service_tier=`"$($Gear.ServiceTier)`"")
    }
    return $args
}

Export-ModuleMember -Function Resolve-CodexGearInput, Get-CodexGearMatrix, Get-CodexGear, Select-CodexGear, Select-AiWorkRoute, Select-ChatGatewayRoute, Select-AiProviderRoute, ConvertTo-ChatGatewayTaskText, Get-ChatGatewayTaskKey, Test-ChatGatewayFreshnessSensitive, Get-ChatGatewayCacheEntry, Get-ChatGatewaySavingsEstimate, New-ChatGatewayHybridSplit, Get-CodexLatestTokenSnapshot, Get-CodexExecutable, New-CodexConfigArgs




