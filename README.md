# ZDH Gears

![ZDH Gears](assets/codex-gears-logo.svg)

The plugin exposes the **ZDH Gears** skill pack as a portable package.

## What it ships

- `codex-gears` skill bundle in `skills/codex-gears`
- Local-only routing lock-down behavior
- Conflict-aware gear profile resolution
- Deterministic provider override precedence
- Versioned share manifest support (`codex-gears.share.json`)

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

```powershell
Test-Path "$env:USERPROFILE\plugins\codex-gears\.codex-plugin\plugin.json"
```

If you only need routing validation in a project where a full test harness is not present:

```powershell
pwsh -NoProfile -Command "Import-Module \"scripts\\CodexGear.psm1\" -Force; Select-AiProviderRoute -Text \"local only: validate this bug report\""
```

## Versioning

Keep `plugin.json`, the SKILL instructions, and the contract reference in sync when behavior changes.
