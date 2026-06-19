-- BehemothHaptics - bhaptics integration mod for Behemoth (UE4SS Lua mod)
-- Place bhaptics_library.dll and bhaptics_wrapper.dll in this same /scripts/ folder.

local APP_ID  = "693bd2bfa277918a71a9e306"
local API_KEY = "9i2CB6kNndpJNh64K1bI"

-- ─── Load the wrapper ────────────────────────────────────────────────────────
-- bhaptics_wrapper.dll is a thin Lua C extension that bridges to bhaptics_library.dll.
-- Both DLLs must live in the same /scripts/ folder as this file.
local ok, bhaptics = pcall(require, "bhaptics_wrapper")
if not ok then
    print("[BehemothHaptics] ERROR: Could not load bhaptics_wrapper.dll")
    print("[BehemothHaptics] Make sure bhaptics_wrapper.dll and bhaptics_library.dll")
    print("[BehemothHaptics] are both in the same folder as this script.")
    print("[BehemothHaptics] Details: " .. tostring(bhaptics))
    return
end

-- ─── Initialize the SDK ──────────────────────────────────────────────────────
local initialized = bhaptics.initialize(APP_ID, API_KEY)
if not initialized then
    print("[BehemothHaptics] ERROR: bhaptics SDK failed to initialize.")
    print("[BehemothHaptics] Make sure the bHaptics Player app is running.")
    return
end

print("[BehemothHaptics] SDK initialized successfully!")

-- ─── Demo: play the 'heartbeat' pattern once on startup ──────────────────────
-- In a real mod you would hook specific game functions here instead.
-- ExecuteWithDelay gives the SDK a moment to finish connecting before playing.
ExecuteWithDelay(1500, function()
    print("[BehemothHaptics] Playing 'heartbeat' pattern...")
    local result = bhaptics.play("heartbeat")
    if result >= 0 then
        print("[BehemothHaptics] Playback started, request ID: " .. tostring(result))
    else
        print("[BehemothHaptics] Playback failed (returned " .. tostring(result) .. ")")
    end
end)

-- ─── Cleanup on mod unload ───────────────────────────────────────────────────
-- UE4SS calls this when the mod is unloaded / game exits.
RegisterConsoleCommandHandler("bhaptics_destroy", function()
    bhaptics.destroy()
    print("[BehemothHaptics] SDK destroyed.")
    return false
end)

-- Register a simple console test command:  bhaptics_play heartbeat
RegisterConsoleCommandHandler("bhaptics_play", function(fullCommand, parameters, ar)
    local eventName = parameters[1] or "heartbeat"
    local result = bhaptics.play(eventName)
    print("[BehemothHaptics] Played '" .. eventName .. "', request ID: " .. tostring(result))
    return false
end)

print("[BehemothHaptics] Mod loaded. Type 'bhaptics_play heartbeat' in the console to test.")
