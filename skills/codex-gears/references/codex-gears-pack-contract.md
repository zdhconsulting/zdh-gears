# ZDH Gears Pack Contract

This reference describes the portable behaviors this skill must preserve.

## Required routes

- `local only` and variants (`local-only`, `run locally`, `execute locally`, `only local`) must force local execution:
  - `Select-AiWorkRoute` returns `Route = codex`
  - `Select-ChatGatewayRoute` returns `Route = codex`, `Dispatch = codex-auto`
  - `Select-AiProviderRoute` returns `Route = codex`, `Provider = codex`

- Explicit tags must retain precedence:
  - `[codex]`, `[chatgpt]`, `[deepseek]` continue to override heuristic routing unless `-ForceCodex` already exists in the provider call path.
  - Conflicting gear tags in prompt text (for example `[low] [xhigh]`) resolve to `max` (highest).
  - `[review]` is authoritative if present.

## Distribution behavior

- The pack is consumed as a folder:
  - Copy `skills/codex-gears` to your repo/workspace or share directly via git.
  - Run `install-codex-gears.ps1` once per machine.

- The installer requires either:
  - a local canonical module path via `-SourceModulePath`, or
  - a discoverable module path in the nearby repo (`scripts\CodexGear.psm1`).

## Optional plugin install

- `plugins/codex-gears` can be installed with `scripts\install-codex-gears-plugin.ps1` for teams that want a plugin-style drop-in package.

## Validation checks to keep in sync

When changing routing logic, update both:

- Canonical routing module under `scripts/CodexGear.psm1`
- Pack validation tests (`scripts/codex-gear-test.ps1`)

and rerun:

- `pwsh -NoProfile -ExecutionPolicy Bypass -File scripts\codex-gear-test.ps1`
