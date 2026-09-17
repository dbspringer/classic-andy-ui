# Classic Andy UI

A WoW: Forever addon that gives Forever's UI elements the Classic look. It exists because Forever ships the Modern look shared with Midnight.

## Language

**Classic look**:
The appearance of a UI element in the Burning Crusade Anniversary client. The reference for every restoration.
_Avoid_: Vanilla look, old UI, TBC UI

**Modern look**:
The appearance of a UI element as Forever ships it, shared with Midnight.
_Avoid_: Retail look, new UI, Dragonflight UI

**Element**:
One visually distinct piece of the UI that the addon restores as a unit, such as the player frame.
_Avoid_: Widget, component, module

**Restore**:
Give an element the Classic look. Pixel-faithful where the client permits, restyled where it does not.
_Avoid_: Skin, reskin, revert

**Mirror**:
A region the addon creates to carry Classic art that has no Modern counterpart. It shows and hides in step with a Modern region, and never reads game state itself.
_Avoid_: Overlay, replacement, clone

**Display text**:
Any text a player can read on screen, in the addon's own frames or in a popup.
_Avoid_: String, label, literal

**Classification**:
The client's rank for a unit: normal, minus, elite, rare, rare elite, or world boss. It chooses the target frame's border art.
_Avoid_: Mob type, rank, difficulty

**Reaction**:
How a unit stands toward the player: hostile, neutral, or friendly. It tints the name background.
_Avoid_: Faction color, hostility, attitude
