-- BehemothHaptics
-- UE4SS Lua mod for Behemoth (Unreal Engine VR)
-- Triggers haptic feedback on the bHaptics TactSuit via bhaptics_wrapper.dll

local APP_ID  = "693bd2bfa277918a71a9e306"
local API_KEY = "9i2CB6kNndpJNh64K1bI"

-- ─── Load wrapper ─────────────────────────────────────────────────────────────
local ok, bhaptics = pcall(require, "bhaptics_wrapper")
if not ok then
    print("[BehemothHaptics] ERROR: Could not load bhaptics_wrapper.dll")
    print("[BehemothHaptics] " .. tostring(bhaptics))
    return
end

-- ─── Connect to bHaptics Player ───────────────────────────────────────────────
-- Auto-launch the Player if it is installed but not currently running.
if bhaptics.is_player_installed() and not bhaptics.is_player_running() then
    print("[BehemothHaptics] bHaptics Player not running — launching...")
    bhaptics.launch_player(true)
    ExecuteWithDelay(3000, function()
        local initOk, initErr = bhaptics.registry_and_init(API_KEY, APP_ID, "{}")
        if not initOk then
            print("[BehemothHaptics] Init failed: " .. tostring(initErr))
            return
        end
        print("[BehemothHaptics] Connected after auto-launch.")
        bhaptics.play("heartbeat")
    end)
else
    local initOk, initErr = bhaptics.registry_and_init(API_KEY, APP_ID, "{}")
    if not initOk then
        print("[BehemothHaptics] ERROR: " .. tostring(initErr))
        return
    end
    print("[BehemothHaptics] Connected.")

    -- Small delay to let the websocket fully establish before first playback.
    ExecuteWithDelay(1500, function()
        print("[BehemothHaptics] Playing 'heartbeat'...")
        local reqId = bhaptics.play("heartbeat")
        print("[BehemothHaptics] play() -> requestId " .. tostring(reqId))
    end)
end
