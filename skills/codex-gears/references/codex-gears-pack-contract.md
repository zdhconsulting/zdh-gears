# ZDH Gears Pack Contract

This reference describes the portable behaviors this skill must preserve.

## Required routes

- `local only` and variants (`local-only`, `run locally`, `execute locally`, `only local`) must force local execution:
  - `Select-AiWorkRoute` returns `Route = codex`
  - `Select-ChatGatewayRoute` returns `Route = codex`, `Dispatch = codex-auto`
  - `Select-AiProviderRoute` returns `Route = codex`, `Provider = codex`

- Provider force tags (`[codex]`, `[chatgpt]`, `[deepseek]`) remain explicit provider instructions. Gear words such as `low`, `medium`, `high`, or `xhigh` are context only; task complexity and risk determine the selected gear.

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
