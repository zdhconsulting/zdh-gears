# ZDH Gears

![ZDH Gears](assets/codex-gears-logo.svg)

ZDH Gears is a three-mode routing skill and launcher for Codex. It selects a requested model, reasoning effort, and service tier from the task text, while leaving normal project, account, security, and production controls in place.

## Routing policy

**Auto Selection** is the default:

| Task profile | Requested configuration |
| --- | --- |
| `fast` | `gpt-5.6-sol`, low reasoning, fast service |
| `balanced` / `standard` | `gpt-6-astra`, low reasoning, standard service |
| `deep` / `review` | `gpt-6-astra`, high reasoning, standard service |
| `max` | `gpt-6-astra`, ultra reasoning, standard service |

The other two public modes are:

- **Boost Mode**: requests `gpt-6-astra`, ultra reasoning, fast service. Fast is the service tier; Boost retains ultra reasoning.
- **Save Tokens Mode** selects a standard-service saver profile from the task:
  - `saver` / `save-tokens`: `gpt-5.3-codex-spark`, low reasoning, for mechanical tasks.
  - `saver-compact`: `gpt-5.6-luna`, low reasoning, for positively identified bounded implementation such as adding one contact form.
  - `saver-work`: `gpt-5.6-sol`, low reasoning, for explicitly bounded debugging such as one failing unit test, helper, or component.
  - `saver-risk`: `gpt-6-astra`, high reasoning, for architecture, security, destructive, production, migration, or broad work.

Unknown or underspecified work remains on the balanced `gpt-6-astra` low profile, and substantive code review remains on the `gpt-6-astra` high review profile. All Save Tokens profiles use standard service.

Use `-Mode auto|boost|save-tokens` for an unambiguous selection that applies to one launcher invocation. A recognized leading imperative mode phrase in task text also selects once for that invocation; descriptions and negations elsewhere in the task do not activate a mode. ZDH Gears does not intercept later turns or persist a mode across tasks. An installed skill supplies guidance; it cannot change the model of an already active chat.

Gears model **Boost** is separate from the `agent-work-modes` scheduling state sometimes called Push Mode. Scheduling controls pace and concurrency; ZDH Gears controls the requested model configuration. Installing or invoking ZDH Gears does not change scheduling, and the only public Gears modes are Auto Selection, Boost Mode, and Save Tokens Mode.

ZDH Gears does not include an automatic capacity-aware model chooser or fallback retry system. It has no knowledge of account cost or token percentages and does not measure or promise quantified savings. The listed model IDs and low reasoning effort were validated against one local advertised `models_cache`; that does not prove availability for another account.

## Install

PowerShell 7 (`pwsh`) is required for the included scripts and tests. Install from the native Codex plugin marketplace CLI:

```powershell
codex plugin marketplace add https://github.com/zdhconsulting/zdh-gears.git
codex plugin add codex-gears@zdh-gears --json
```

Start a fresh Codex task after installation so the new skill is discovered. The plugin does not copy over `%USERPROFILE%\.codex\scripts\CodexGear.psm1`.

## Update

```powershell
codex plugin marketplace upgrade zdh-gears
codex plugin add codex-gears@zdh-gears --json
```

There is no mandatory remove step. Start a fresh task after updating. If a release must be rolled back, select the previous `v1.5.2` release (which retains the issues fixed here) through the marketplace workflow.

## Run and verify

From a clone or the installed package root, preview a route without launching Codex:

```powershell
pwsh -NoProfile -File .\scripts\zdh-gears-exec.ps1 -Mode auto -DryRun "Fix the failing test"
```

Run the repository validation suite:

```powershell
pwsh -NoProfile -File .\tests\run-tests.ps1
```

To execute the task through the launcher, omit `-DryRun`. When calling `pwsh -File` with task text that starts with a dash, pass it as `-Task:"--your task text"` so PowerShell treats it as a value. The launcher then sends the prompt through stdin to Codex.

The suite covers routing, launcher execution with a test double, receipts, installation, usage parsing and package validation. It does not spend model usage.

Every routing or execution receipt has a unique ID. Execution receipts keep process outcome separate from configuration evidence: `RequestedConfiguration` records what the launcher asked for, `ObservedConfiguration` records only what the host actually exposed, and the current launcher records `ConfigurationStatus = unverified`, `Applied = false`, and `ObservedConfiguration = null` regardless of process exit. A successful process exit does not prove the backend applied a requested model, reasoning effort, or service tier. `-DryRun` returns the selected receipt without launching Codex.

The usage helper accepts only an exact run/session ID and a supplied record containing valid usage data:

```powershell
pwsh -NoProfile -File .\scripts\zdh-gears-usage.ps1 -SessionPath .\session.json -RunId <matching-record-id>
```

The current launcher does not correlate its receipt with a Codex session, so token measurement remains dependent on a separately available matching record. Do not treat `unavailable` as zero usage or as evidence of savings.

## Package identity

The bundled manifest binds the listing icon to `assets/zdh-gears-icon.svg`. That verifies package metadata and asset inclusion. Whether a particular Codex client visibly renders that logo in its marketplace listing requires observation in that client and should be reported separately.

The source contract is documented in [skills/codex-gears/references/codex-gears-pack-contract.md](skills/codex-gears/references/codex-gears-pack-contract.md).
