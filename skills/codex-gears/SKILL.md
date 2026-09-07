---
name: codex-gears
description: Select one of three public Codex routing modes from the current task and report the requested configuration without claiming unobserved backend state.
---

# ZDH Gears

[![ZDH Gears](assets/codex-gears-logo.svg)](assets/codex-gears-logo.svg)

Use this skill to choose and explain the requested Codex model configuration for the current task. It is routing guidance plus an optional launcher; installing the skill does not change the model of an active chat.

## Public modes

- **Auto Selection** (default) selects from the task: `fast` = `gpt-5.6-sol`, low, fast; `balanced` / `standard` = `gpt-6-astra`, low, standard; `deep` / `review` = `gpt-6-astra`, high, standard; `max` = `gpt-6-astra`, ultra, standard.
- **Boost Mode** requests `gpt-6-astra`, ultra reasoning, fast service. Fast is the service tier; never downgrade Boost's model or reasoning because the user asks for fast mode.
- **Save Tokens Mode** uses standard service throughout. Select `saver` / `save-tokens` (`gpt-5.3-codex-spark`, low) for mechanical tasks; `saver-compact` (`gpt-5.6-luna`, low) for positively identified bounded implementation; `saver-work` (`gpt-5.6-sol`, low) for explicitly bounded debugging of one test, helper, or component; and `saver-risk` (`gpt-6-astra`, high) for architecture, security, destructive, production, migration, or broad work. Unknown or underspecified work stays on balanced Astra low. Substantive code review stays on Astra high review.

Use `-Mode auto|boost|save-tokens` as the unambiguous per-invocation option. A recognized leading imperative mode phrase in task text also applies to that invocation only; descriptions and negations elsewhere do not activate it. Do not claim per-turn interception or persistence. Choose from the full task, including risk, scope, tools, and verification needs. Auto Selection routes deadlock work to `max`; Save Tokens maps that risk to `saver-risk`.

Gears Boost controls the requested model configuration. The separate `agent-work-modes` Push Mode controls scheduling pace and concurrency. Do not change or describe scheduling state as a fourth Gears mode.

There is no capacity-aware model chooser or automatic fallback retry, and there are no measured or guaranteed token-savings figures or account-cost knowledge. The model IDs and low effort were validated in one local advertised `models_cache`; do not treat that as proof of another account's availability or as backend configuration verification.

## Saving workflow

Keep output concise, read only the relevant files or ranges, reuse existing evidence, and create parallel workers only when necessary. Always perform the verification required by the change; Save Tokens Mode never justifies skipping it.

## Reporting

Before acting when the user asks for a routing report, state the selected profile, requested model, reasoning effort, service tier, and decisive task signals.

Each receipt must have a unique ID. Keep `RequestedConfiguration`, `ObservedConfiguration`, `ConfigurationStatus`, and process status distinct. The current launcher records `ConfigurationStatus = unverified`, `Applied = false`, and `ObservedConfiguration = null` regardless of process exit; process success alone is not backend configuration proof. `-DryRun` returns a selected receipt without launching Codex.

Token usage is observable only when the usage helper receives an exact run/session ID and a matching supplied record with valid usage data. The current launcher does not correlate its receipt to a Codex session, so do not claim token measurement is working without that dependency.

## Install and validate

PowerShell 7 (`pwsh`) is required.

```powershell
codex plugin marketplace add https://github.com/zdhconsulting/zdh-gears.git
codex plugin add codex-gears@zdh-gears --json
```

For updates:

```powershell
codex plugin marketplace upgrade zdh-gears
codex plugin add codex-gears@zdh-gears --json
```

Do not require a remove step and do not copy over `%USERPROFILE%\.codex\scripts\CodexGear.psm1`. Start a fresh task after installing or updating.

```powershell
pwsh -NoProfile -File .\tests\run-tests.ps1
```

The bundled manifest binding for the logo proves package metadata and inclusion. A visually rendered marketplace logo is verified only by observing it in the client.

See [references/codex-gears-pack-contract.md](references/codex-gears-pack-contract.md) for the source-anchored contract.
