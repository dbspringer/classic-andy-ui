# Reskin Blizzard frames in place

Midnight's addon disarmament makes unit data (enemy health, auras, casts, identity) secret in combat contexts, and Forever inherits that API. An addon that draws its own unit frames must read that data and breaks the moment a value is secret. We restore the Classic look by hooking Blizzard's own PlayerFrame and TargetFrame, hiding the Modern atlas textures, and applying the Classic file textures that still ship in the client. Blizzard's code keeps driving values and portraits, secrets never reach addon code, and Edit Mode keeps working.

## Considered Options

- **Replace the frames** with the addon's own. Full layout control, but requires reading unit data, which secrets forbid. Rejected.
- **Reskin in place** (chosen). Same approach ClassicFrames uses on 12.1.
