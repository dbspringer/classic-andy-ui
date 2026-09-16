# Classic Andy UI

A WoW: Forever addon that gives UI elements the Classic look, for the Classic
Andys who grumble at Forever's Modern UI.

Forever runs the Midnight addon API, so the addon reskins Blizzard's frames in
place instead of drawing its own. See `docs/adr/0001-reskin-blizzard-frames-in-place.md`.

## Status

Personal experiment. First slice: the player frame and the target frame.

## Use

`/cau` or `/classicandy` toggles the Classic look and prompts a UI reload.

## Develop

Symlink the repo into an AddOns folder, then see `docs/verification.md`.
Lint with `luacheck .` and package with the BigWigs packager.
