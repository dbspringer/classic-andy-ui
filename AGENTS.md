# classic-andy-ui

A WoW: Forever addon that returns classic UI elements to the client.
Forever runs the Midnight addon API (secret values, AuraContainer), so the
Classic-era API is not a target.

## Agent skills

### Issue tracker

Issues are GitHub Issues on dbspringer/classic-andy-ui, driven with the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Default vocabulary: needs-triage, needs-info, ready-for-agent, ready-for-human, wontfix. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `CONTEXT.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.

## Conventions

- Display text goes through `ns.L[...]` or a Blizzard global string, never a literal. enUS is the key, so a missing translation shows English.
