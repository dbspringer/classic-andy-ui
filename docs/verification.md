# Verification

WoW UI code has no unit test harness. Each element is checked by hand against
its reference screenshot in `docs/reference/`. Run the checklist on Midnight
live and on the Forever beta.

## Setup

1. Symlink the repo into the client: `ln -s <repo> "<client>/Interface/AddOns/ClassicAndyUI"`.
2. Log in. `/cau` toggles the switch and prompts a reload.

## Player frame

- [ ] Frame border, portrait ring, and status bars match `player-frame.png`.
- [ ] Health and power values update in and out of combat.
- [ ] Portrait shows the character model.
- [ ] Edit Mode still selects, moves, and scales the frame.
- [ ] No Lua errors on login, target change, or reload.

## Target frame

- [ ] Frame border, level ring, and classification art match `target-frame.png`.
- [ ] Hostile, neutral, and friendly name backgrounds color correctly.
- [ ] Health and power update while targeting a hostile in combat.
- [ ] Debuffs and buffs still render.
- [ ] Edit Mode still selects, moves, and scales the frame.
- [ ] No Lua errors on target change, target loss, or reload.
