# ZDH Gears

![ZDH Gears](assets/codex-gears-logo.svg)

ZDH Gears is an automatic task-sizing layer for Codex. It chooses a lighter profile for simple work and deeper reasoning for complex or high-risk work, helping control speed and token use without making every task run at maximum depth.

ZDH Gears is a routing aid. It does not guarantee correctness, security, legal compliance, cost savings, or a particular model or response time. Review generated changes and keep normal project, account, and production approvals in place.

The model policy is intentional: low gear uses GPT-5.6 with low reasoning, medium gear uses Astra with low reasoning, high gear uses Astra with high reasoning, and extra-high gear uses Astra with ultra reasoning. GPT-5.5 is not part of this package.

The package is local-first: it does not upload project files or secrets by itself. Its optional telemetry helper reads local Codex session metadata to estimate token usage; it does not send that data anywhere.

## What it ships

- `codex-gears` skill bundle in `skills/codex-gears`
- Local-only routing lock-down behavior
- Conflict-aware gear profile resolution
- Deterministic provider override precedence
- Versioned share manifest support (`codex-gears.share.json`)

## Customer install (recommended)

For a customer workspace, the normal handoff is an administrator import followed by one install click:

1. Open **Workspace settings → Plugins → Add → Import marketplace**.
2. Enter `https://github.com/zdhconsulting/zdh-gears` as the GitHub repository URL. Leave Path empty.
3. Import the marketplace, open **ZDH Gears**, and select **Install**.

After that, the customer selects ZDH Gears from Codex's plugin/source controls. GitHub is the source of updates; the workspace controls who can install and use it.

## Verify the install

The plugin list should show **ZDH Gears — Installed**. In a new Codex task, ask:

```text
Use ZDH Gears for this task. Before acting, tell me the selected gear, model, reasoning level, and why.
```

For a simple task, the expected result is low gear on GPT-5.6. For architecture or production-risk work, it should select Astra with high or ultra reasoning. If Codex does not report a gear decision, select ZDH Gears from the task's plugin/source controls and start a fresh task.

If the customer does not have marketplace administration available, use the local clone installer below.

## Install from a clone

From a machine with this repository:

```powershell
git clone https://github.com/zdhconsulting/zdh-gears.git
Set-Location .\zdh-gears
& ".\scripts\install-codex-gears-plugin.ps1"
```

## Install from GitHub

The repository is public, so teammates can install it with a normal clone and one command:

```powershell
git clone https://github.com/zdhconsulting/zdh-gears.git
Set-Location .\zdh-gears
& ".\scripts\install-codex-gears-plugin.ps1"
```

Then restart Codex Desktop or open a fresh session so the plugin is discovered.

In other repos, you can add the same install command in onboarding docs and keep `zdh-gears` pinned by tag:

```powershell
git clone --depth 1 --branch v1.0.0 https://github.com/zdhconsulting/zdh-gears.git
```

## Verification

Run the packaged routing smoke test:

```powershell
pwsh -NoProfile -File .\tests\routing-smoke.ps1
```

```powershell
Test-Path "$env:USERPROFILE\plugins\codex-gears\.codex-plugin\plugin.json"
```

If you only need routing validation in a project where a full test harness is not present:

```powershell
pwsh -NoProfile -Command "Import-Module \"scripts\\CodexGear.psm1\" -Force; Select-AiProviderRoute -Text \"local only: validate this bug report\""
```

## Versioning

To create a machine-readable selection receipt for a task:

```powershell
pwsh -NoProfile -File .\scripts\zdh-gears-route.ps1 "Design authentication and billing architecture"
```

The receipt records the selected profile and requested configuration. It intentionally remains `Applied = false` until a host launcher applies and observes the configuration.

Keep `plugin.json`, the SKILL instructions, and the contract reference in sync when behavior changes.

## Direct execution and diagnostics

To run a task through the selected gear and record whether Codex completed with that configuration:

```powershell
pwsh -NoProfile -File .\scripts\zdh-gears-exec.ps1 "Fix the failing test" -PassThru
```

The launcher passes the selected model, reasoning effort, and service tier directly to `codex exec`. The receipt uses `verified`, `mismatch`, or `unverified` so a selection is never presented as proof of execution. For a preflight check:

```powershell
pwsh -NoProfile -File .\scripts\zdh-gears-doctor.ps1
```

The launcher is the enforcement path. The installed skill remains the conversational guidance path; it cannot intercept every unrelated Codex task by itself.
