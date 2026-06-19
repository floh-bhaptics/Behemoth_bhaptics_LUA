# BehemothHaptics — UE4SS Lua Mod for bHaptics

A haptic feedback mod for *Behemoth* (Unreal Engine, VR) using UE4SS and the
bHaptics SDK.

---

## File layout

```
<Game>\Behemoth\Binaries\Win64\ue4ss\Mods\
  BehemothHaptics\
    scripts\
      main.lua
      bhaptics_wrapper.dll   ← you compile this (source: bhaptics_wrapper.cpp)
      bhaptics_library.dll   ← from the bHaptics SDK package
  mods.txt                   ← add "BehemothHaptics : 1" here
```

---

## Step 1 — Find the Lua version UE4SS uses

UE4SS embeds Lua. The wrapper DLL must be compiled against the **same** Lua
version and ABI. To check:

1. Download the **zDEV** build of UE4SS from https://github.com/UE4SS-RE/RE-UE4SS/releases
2. In the zip, look for `lua54.dll`, `lua51.dll`, etc. — that tells you the version.
3. Grab matching Lua headers + import library from https://luabinaries.sourceforge.net

UE4SS currently ships with **Lua 5.4** (lua54.dll).

---

## Step 2 — Inspect bhaptics_library.dll exports

Before compiling, confirm the exact export names in `bhaptics_library.dll`:

```
dumpbin /EXPORTS bhaptics_library.dll
```

or with PowerShell:

```powershell
[System.Reflection.Assembly]::LoadWithPartialName("System") | Out-Null
$dll = [System.Runtime.InteropServices.Marshal]
# Use dumpbin from a Visual Studio Developer Command Prompt instead:
# dumpbin /EXPORTS bhaptics_library.dll | findstr /i "Initialize\|Play\|Destroy"
```

The wrapper assumes these exported names (plain C / `extern "C"`):
- `Initialize`
- `Destroy`
- `Play`
- `PlayParam`
- `IsConnected`
- `IsPlaying`
- `Stop`

If the DLL exports C++ mangled names instead, update the `LoadProc` calls in
`bhaptics_wrapper.cpp` with the exact mangled names from `dumpbin`.

---

## Step 3 — Compile bhaptics_wrapper.dll

### With MSVC (Visual Studio Developer Command Prompt, x64):

```bat
cl /LD /MD /O2 /std:c++17 ^
   bhaptics_wrapper.cpp ^
   /I"C:\path\to\lua54\include" ^
   /link "C:\path\to\lua54\lua54.lib" ^
   /OUT:bhaptics_wrapper.dll
```

### With MinGW-w64 (x64):

```bash
g++ -shared -O2 -std=c++17 \
    -I/path/to/lua54/include \
    bhaptics_wrapper.cpp \
    -L/path/to/lua54/lib -llua54 \
    -o bhaptics_wrapper.dll
```

Copy the resulting `bhaptics_wrapper.dll` into the `scripts/` folder.

---

## Step 4 — Enable the mod

Open (or create) `ue4ss\Mods\mods.txt` and add:

```
BehemothHaptics : 1
```

---

## Step 5 — Run

1. Start the **bHaptics Player** app on your PC.
2. Launch *Behemoth*.
3. After ~1.5 seconds the `heartbeat` pattern should play.
4. Open the UE4SS console and type `bhaptics_play heartbeat` to trigger it manually.

---

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| `Could not load bhaptics_wrapper.dll` | Wrapper not in `scripts/`, or compiled against wrong Lua version |
| `bhaptics_library.dll loaded but exports not found` | Run `dumpbin /EXPORTS` and update the symbol names in the .cpp |
| `SDK failed to initialize` | bHaptics Player not running, or wrong App ID / API Key |
| Pattern plays but no vibration | Event name `"heartbeat"` doesn't match what's in your bHaptics Developer Portal app |

---

## Adding real game hooks (next step)

Replace the `ExecuteWithDelay` demo in `main.lua` with actual UE4SS hooks.
Example — trigger haptics when the player takes damage:

```lua
RegisterHook("/Script/Behemoth.BehemothCharacter:ReceiveDamage",
    function(self, damage, ...)
        bhaptics.play("receive_damage")
    end
)
```

Use the UE4SS **Live Property Viewer** (UHT Dumper output) to find the right
Unreal function paths for Behemoth.
