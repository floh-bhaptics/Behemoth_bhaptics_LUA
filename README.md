# BehemothHaptics — bHaptics Mod for Skydance's BEHEMOTH

Adds full haptic feedback support for the [bHaptics](https://www.bhaptics.com) TactSuit to the VR game **Skydance's BEHEMOTH**. Built as a UE4SS Lua mod.

## Supported effects

- Directional damage feedback (attack direction is mapped to the vest)
- Player death
- Healing
- Low health heartbeat (pulses while health is below 30%)
- Dodge
- Crouch
- Melee hits, blocks, parries, and counters
- Picking up and sheathing items (per holster slot)
- Bow draw and arrow release
- Grapple hook fire and zip-line traversal
- Strength crush (grip interactions)
- Lore collectible and upgrade interactions

---

## Requirements

- [bHaptics Player](https://www.bhaptics.com/setup) installed and running
- A bHaptics TactSuit (X16, X40, or Pro)
- **UE4SS v3.0.1** (see installation below)

---

## Installation

### Step 1 — Install UE4SS

Download **[UE4SS v3.0.1](https://github.com/UE4SS-RE/RE-UE4SS/releases/download/v3.0.1/UE4SS_v3.0.1.zip)** and extract the contents of the zip directly into your game's `Win64` folder:

```
<Steam>\steamapps\common\Skydance's BEHEMOTH\BHM\Binaries\Win64\
```

You should end up with `dwmapi.dll` and a `ue4ss` folder sitting next to `BHM-Win64-Shipping.exe`.

### Step 2 — Install the mod

Download **[Behemoth_bhaptics_LUA.zip](https://github.com/floh-bhaptics/Behemoth_bhaptics_LUA/releases/latest/download/Behemoth_bhaptics_LUA.zip)** and extract it anywhere. Then run **`Install.bat`**.

The installer will:
- Locate the game automatically by scanning your drives for the default Steam path, or prompt you for the path if it can't find it
- Verify that UE4SS is installed
- Copy the mod files into the correct `Mods\BehemothHaptics\scripts\` folder
- Add `BehemothHaptics : 1` to `mods.txt` automatically

### Step 3 — Verify

Launch the game. If your suit plays a short heartbeat pulse shortly after loading in, the mod is connected and working.

---

## Troubleshooting

**No haptic feedback at all**
- Make sure the bHaptics Player is running before launching the game.
- Check that your suit is connected and showing up in the bHaptics Player.

**Heartbeat on startup does not play**
- The mod may not have loaded. Check the UE4SS log at `Win64\UE4SS.log` for any errors mentioning `BehemothHaptics`.
- Make sure `BehemothHaptics : 1` is present in `Win64\Mods\mods.txt`. Re-running `Install.bat` will add or re-enable it.

**Some effects don't work**
- Certain effects (save point, rope pull) are not implemented in this version due to changes in the game's blueprint structure.

---

## Credits

Built with [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS) and the [bHaptics SDK](https://www.bhaptics.com/develop).
