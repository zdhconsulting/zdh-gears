---
name: codex-gears
description: Automatically match Codex speed, model, and reasoning depth to task complexity while reserving deeper runs for work that needs them.
---

# ZDH Gears Share Pack

[![ZDH Gears](assets/codex-gears-logo.svg)](assets/codex-gears-logo.svg)

Use this skill when a team or repo needs the same routing behavior as the canonical Codex gear system without re-implementing the logic manually.

This skill provides routing guidance only. It is not a security, legal, financial, or production approval system, and it does not guarantee model behavior or outcomes.

When the user asks whether routing is active, report the selected gear, model, reasoning level, service tier, and the task signals that led to the choice before beginning work.

The pack contains a portable install script and reference docs for:

- `Select-CodexGear` profile selection
- `Select-CodexGear` mixed-tag conflict handling
- `Select-AiWorkRoute` local-only guardrails
- `Select-ChatGatewayRoute` provider suppression rules
- `Select-AiProviderRoute` provider override precedence

## What this gives you

After installation, your host has the same route matrix and tests behavior currently used by this repo.

## Install in a new machine/worktree

From this repository checkout, run:

```powershell
& "skills\codex-gears\scripts\install-codex-gears.ps1"
```

Optional:

```powershell
& "skills\codex-gears\scripts\install-codex-gears.ps1" -CodexHome "C:\Users\YOU\.codex" -SourceModulePath "C:\path\to\CodexGear.psm1"
```

The installer performs:

1. Copies `CodexGear.psm1` into `%USERPROFILE%\.codex\scripts`.
2. Writes a small share manifest (`codex-gears.share.json`) so you can track what version was installed.
3. Emits the exact command to run the core routing test.

The bundle is also available as a plugin-style package in `plugins/codex-gears`.

## Verification

After install, run:

```powershell
& "$env:USERPROFILE\.codex\scripts\codex-gear-test.ps1"  # if you also installed the full script set
```

Or at minimum:

```powershell
pwsh -NoProfile -Command "Import-Module \"$env:USERPROFILE\.codex\scripts\CodexGear.psm1\" -Force; Select-CodexGear -Text 'local only draft a short email'"
```

## Shareability notes

- Treat this as an installable skill bundle, not a one-time local tweak.
- Keep the bundle versioned and copy the whole `codex-gears` folder to another person’s repo or workspace.
- Review and update both `skills/codex-gears/references` and this file when routing behavior changes.
