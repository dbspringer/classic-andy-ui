# No Lua field writes on Blizzard frame tables

Addon code may call widget methods on Blizzard's frames (textures, sizes, anchors, masks) but must never assign a Lua field on them. A field written by addon code is tainted, and any Blizzard function that reads it runs tainted from that point on. On Midnight that is fatal for unit frames: `UnitFrame_Update` reads `disablePortraitMask` and then updates the health bar in the same call, so a tainted field there made the health bar store a secret value and throw on every OnUpdate. Found 2026-09-16 on the first in-game test.

## The one exception

`hooksecurefunc(object, "Method", fn)` does put a function on a Blizzard object, but the client installs it from secure code and the wrapper stays secure. That is the sanctioned way to follow a Blizzard region's Show, Hide, or SetShown, and the Mirror pattern depends on it.

## Consequences

- Any Classic behavior Blizzard gates behind a frame field must be reproduced with widget calls instead, as with the portrait mask.
- A bisect of widget calls alone cannot find this class of bug. Check for field writes first.
