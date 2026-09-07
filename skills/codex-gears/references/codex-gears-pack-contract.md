# ZDH Gears Pack Contract

This reference defines the public behavior that the package source and documentation must preserve.

## Mode and profile contract

ZDH Gears exposes exactly three public modes:

1. **Auto Selection** is the default and maps `fast` to `gpt-5.6-sol` / low / fast; `balanced` and `standard` to `gpt-6-astra` / low / standard; `deep` and `review` to `gpt-6-astra` / high / standard; and `max` to `gpt-6-astra` / ultra / standard.
2. **Boost Mode** requests `gpt-6-astra` / ultra / fast. Fast means the service tier, while model and reasoning remain Astra ultra.
3. **Save Tokens Mode** selects one of these standard-service profiles:
   - `saver` and its `save-tokens` alias: `gpt-5.3-codex-spark` / low for mechanical tasks.
   - `saver-compact`: `gpt-5.6-luna` / low for positively identified bounded implementation, such as adding one contact form.
   - `saver-work`: `gpt-5.6-sol` / low for explicitly bounded debugging, such as one failing unit test, helper, or component.
   - `saver-risk`: `gpt-6-astra` / high for architecture, security, destructive, production, migration, or broad work.

Unknown or underspecified work remains `balanced` (`gpt-6-astra` / low / standard). Substantive code review remains `review` (`gpt-6-astra` / high / standard).

`-Mode auto|boost|save-tokens` is the unambiguous per-invocation control. Recognized leading imperative mode phrases in task text also apply once to the current invocation; descriptions and negations elsewhere do not activate a mode. The launcher does not intercept each conversation turn or persist mode state. Skill instructions guide selection but cannot reconfigure an active chat. Auto Selection routes deadlock work to `max`; Save Tokens maps that risk to `saver-risk`.

Gears Boost is a model route. `agent-work-modes` Push Mode is separate scheduling state for pace and concurrency. ZDH Gears does not change that scheduling state.

The package has no automatic capacity-aware model choice, fallback retry, account-cost knowledge, or quantified-savings implementation. The model IDs and low reasoning effort were validated against one local advertised `models_cache`; this does not prove availability for another account or that a backend applied the requested configuration. Standard service is a routing property, not a quantified savings claim.

## Installation contract

PowerShell 7 (`pwsh`) is required for scripts and validation. The primary native CLI flow is:

```powershell
codex plugin marketplace add https://github.com/zdhconsulting/zdh-gears.git
codex plugin add codex-gears@zdh-gears --json
```

Updates use:

```powershell
codex plugin marketplace upgrade zdh-gears
codex plugin add codex-gears@zdh-gears --json
```

Removal is not a mandatory update step. Installation must not overwrite `%USERPROFILE%\.codex\scripts\CodexGear.psm1`. Start a fresh task after install or update so discovery happens in a new task context.

## Receipt and evidence contract

- Every route or execution receipt has a unique ID.
- `RequestedConfiguration` records the model, reasoning effort, and service tier requested by the launcher.
- `ObservedConfiguration` contains only configuration reported by the host for that execution.
- The current launcher records `ConfigurationStatus = unverified`, `Applied = false`, and `ObservedConfiguration = null` regardless of process exit.
- Process status records launch or exit outcome separately; successful execution is not backend configuration proof.
- The usage helper accepts an exact run/session ID plus a supplied record with valid usage. The current launcher does not correlate its receipt to a Codex session, so that matching record remains an external dependency.
- Missing usage is `unavailable`, not zero and not evidence of token savings.

## Source anchors and validation

- `scripts/CodexGear.psm1` defines profile selection and risk escalation.
- `scripts/zdh-gears-route.ps1` emits routing receipts.
- `scripts/zdh-gears-exec.ps1` launches Codex and emits execution receipts; `-Mode auto|boost|save-tokens` selects one invocation and `-DryRun` returns the selected receipt without launching.
- `scripts/zdh-gears-usage.ps1` validates exact-ID session usage.
- `.codex-plugin/plugin.json` binds the bundled listing icon to `assets/zdh-gears-icon.svg`.
- `tests/routing-smoke.ps1`, `tests/execution.test.ps1`, and `tests/package.test.ps1` are run by `tests/run-tests.ps1`.

Run the complete suite with:

```powershell
pwsh -NoProfile -File .\tests\run-tests.ps1
```

Manifest binding verifies the logo path and bundled asset. Visual display in a marketplace client requires separate observation in that client.
