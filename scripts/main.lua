-- BehemothHaptics
-- UE4SS Lua mod for Behemoth (Unreal Engine VR)
-- Triggers haptic feedback on the bHaptics TactSuit via bhaptics_wrapper.dll

local APP_ID  = "693bd2bfa277918a71a9e306"
local API_KEY = "9i2CB6kNndpJNh64K1bI"

-- ─── State ────────────────────────────────────────────────────────────────────

local hookIds    = {}
local hookIds2   = {}   -- LoreCollectible hooks (registered on demand)
local hookIds3   = {}   -- MaxHealthUp hooks (registered on demand)
local resetHook  = true

local handItem = { LeftHandItem = nil, RightHandItem = nil }

local isPause                  = false
local playerHealth             = 100
local isRopeGrappleHookZip     = false
local isLeftHandCrush          = false
local isRightHandCrush         = false
local isLoreCollectibleRegister = false
local isMaxHealthUpRegister    = false

local lastRopePullTime  = 0
local lastSavePointTime = 0
local lastReleaseHand   = 0
local forgeTime         = 0
local heartbeatTime     = 0
local healingTime       = 0

-- ─── Load wrapper ─────────────────────────────────────────────────────────────

local ok, bhaptics = pcall(require, "bhaptics_wrapper")
if not ok then
    print("[BehemothHaptics] ERROR: Could not load bhaptics_wrapper.dll")
    print("[BehemothHaptics] " .. tostring(bhaptics))
    return
end

-- ─── bhaptics play helpers ───────────────────────────────────────────────────
-- Wraps bhaptics.play / play_param and logs if the SDK returns an error.
-- A request ID of -1 indicates the pattern name was not found or playback failed.

local function Play(eventName)
    local reqId = bhaptics.play(eventName)
    if reqId < 0 then
        print("[BehemothHaptics] play() failed for pattern: " .. tostring(eventName))
    end
    return reqId
end

local function PlayParam(eventName, requestId, intensity, duration, angleX, offsetY)
    local reqId = bhaptics.play_param(eventName, requestId, intensity, duration, angleX, offsetY)
    if reqId < 0 then
        print("[BehemothHaptics] play_param() failed for pattern: " .. tostring(eventName))
    end
    return reqId
end

-- ─── Connect to bHaptics Player ───────────────────────────────────────────────

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
        ExecuteWithDelay(500, function() Play("HeartBeat") end)
    end)
else
    local initOk, initErr = bhaptics.registry_and_init(API_KEY, APP_ID, "{}")
    if not initOk then
        print("[BehemothHaptics] ERROR: " .. tostring(initErr))
        return
    end
    print("[BehemothHaptics] Connected.")
    ExecuteWithDelay(500, function() Play("HeartBeat") end)
end

-- ─── Helpers ──────────────────────────────────────────────────────────────────

-- Map an inventory component name to the bhaptics slot event prefix.
local function CheckSlot(slotName)
    if     string.find(slotName, "ChestInventoryComponent")     then return "ChestSlot"
    elseif string.find(slotName, "RightHipInventoryComponent")  then return "RightHipSlot"
    elseif string.find(slotName, "LeftHipInventoryComponent")   then return "LeftHipSlot"
    elseif string.find(slotName, "RightBackInventoryComponent") then return "RightBackSlot"
    elseif string.find(slotName, "LeftBackInventoryComponent")  then return "LeftBackSlot"
    elseif string.find(slotName, "GrappleHookGunSlot")          then return "GrappleHookGunSlot"
    else                                                              return "ChestSlot"
    end
end

-- ─── Looping effects (driven by LoopAsync) ────────────────────────────────────

local function HeartBeat()
    if isPause then return end
    -- Only pulse while health is low and the health-update hook has fired recently.
    if os.clock() - heartbeatTime > 30 then return end
    if playerHealth > 0 and playerHealth < 30 then
        Play("HeartBeat")
    end
end

local function RopeGrappleHookZip()
    if isPause then return end
    if isRopeGrappleHookZip then
        Play("RopeGrappleHookZip")
    end
end

local function LeftHandCrush()
    if isPause then return end
    if isLeftHandCrush then
        Play("LeftHandCrush")
    end
end

local function RightHandCrush()
    if isPause then return end
    if isRightHandCrush then
        Play("RightHandCrush")
    end
end

-- ─── Hook callbacks ───────────────────────────────────────────────────────────

-- Pause / resume / exit
local function HideElements()    isPause = true  end
local function EnableElements()  isPause = true  end   -- mirrors original intent

local function BndEvt__BTNResume(self)
    isPause = false
end

local function BndEvt__BTNExit(self)
    isPause              = false
    playerHealth         = 100
    isRopeGrappleHookZip = false
    isLeftHandCrush      = false
    isRightHandCrush     = false
end

local function LoadGame(self)
    isPause              = false
    playerHealth         = 100
    isRopeGrappleHookZip = false
    isLeftHandCrush      = false
    isRightHandCrush     = false
end

-- Inventory
local function AttachInventory(self)
    local slot = CheckSlot(self:get():GetFullName())
    Play(slot .. "InputItem")
end

local function GrabFromInventory(self)
    local slotProp = self:get():GetPropertyValue("Slot")
    if slotProp ~= nil and slotProp:GetFullName() ~= nil then
        local slot = CheckSlot(slotProp:GetFullName())
        Play(slot .. "OutputItem")
    end
end

local function ReturnToInventory(self)
    Play("ChestSlotInputItem")
end

-- Hand item tracking
local function HeldActorGrab(self, Grabber, Hand)
    if self:get():WasHeldByPlayer()
    or (self:get():GetPropertyValue("Owner"):GetFullName() ~= nil
        and string.find(self:get():GetPropertyValue("Owner"):GetFullName(), "Player")) then
        if Hand:get() == 1 then
            handItem["RightHandItem"] = self:get():GetFullName()
            Play("RightHandPickupItem")
        else
            handItem["LeftHandItem"] = self:get():GetFullName()
            Play("LeftHandPickupItem")
        end
    end
end

local function OnGripPress(self, Hand, Component, Entry)
    -- Ignore inventory slot interactions (handled by AttachInventory / GrabFromInventory)
    if string.find(Component:get():GetFullName(), "InventorySlot")
    or string.find(Component:get():GetFullName(), "MedicineSlot") then
        return
    end
    if Hand:get():GetPropertyValue("ControllerHand") == 1 then
        Play("RightHandPickupItem")
    else
        Play("LeftHandPickupItem")
    end
end

local function OnGripRelease(self, Hand)
    -- Bow and scroll release is handled by their own hooks
    if handItem["LeftHandItem"] ~= nil then
        if string.find(handItem["LeftHandItem"], "Player_Scroll")
        or string.find(handItem["LeftHandItem"], "BHM_Bow") then
            return
        end
        if handItem["RightHandItem"] == nil then
            handItem["LeftHandItem"] = nil
            return
        end
    end
    if handItem["RightHandItem"] ~= nil then
        if string.find(handItem["RightHandItem"], "Player_Scroll")
        or string.find(handItem["RightHandItem"], "BHM_Bow") then
            return
        end
        if handItem["LeftHandItem"] == nil then
            handItem["RightHandItem"] = nil
            return
        end
    end
    if handItem["LeftHandItem"] == nil and handItem["RightHandItem"] == nil then
        return
    end
    if Hand:get():GetPropertyValue("ControllerHand") == 1 then
        handItem["RightHandItem"] = nil
    else
        handItem["LeftHandItem"] = nil
    end
end

local function BowOnGripRelease(self, Hand)
    if Hand:get():GetPropertyValue("ControllerHand") == 1 then
        handItem["RightHandItem"] = nil
    else
        handItem["LeftHandItem"] = nil
    end
end

local function ScrollOnGripRelease(self, Hand)
    if Hand:get():GetPropertyValue("ControllerHand") == 1 then
        handItem["RightHandItem"] = nil
    else
        handItem["LeftHandItem"] = nil
    end
end

-- Bow
local function LaunchArrow(self)
    if handItem["LeftHandItem"] ~= nil and string.find(handItem["LeftHandItem"], "BHM_Bow") then
        Play("LeftHandLaunchArrow")
    else
        Play("RightHandLaunchArrow")
    end
end

local function OnInteractPress(self) end   -- reserved, no effect yet

-- Melee
local function OnHit(self)
    local hasAttack = false
    if self:get():GetFullName() == handItem["LeftHandItem"] then
        Play("LeftHandMeleeAttackHit")
        hasAttack = true
    end
    if self:get():GetFullName() == handItem["RightHandItem"] then
        Play("RightHandMeleeAttackHit")
        hasAttack = true
    end
    if not hasAttack then
        Play("LeftHandMeleeAttackHit")
        Play("RightHandMeleeAttackHit")
    end
end

local function OnAttackBlocked(self)
    local hasAttack = false
    if self:get():GetFullName() == handItem["LeftHandItem"] then
        Play("LeftHandMeleeAttackBlocked")
        hasAttack = true
    end
    if self:get():GetFullName() == handItem["RightHandItem"] then
        Play("RightHandMeleeAttackBlocked")
        hasAttack = true
    end
    if not hasAttack then
        Play("LeftHandMeleeAttackBlocked")
        Play("RightHandMeleeAttackBlocked")
    end
end

local function OnBlockedAttack(self)
    local hasAttack = false
    if self:get():GetFullName() == handItem["LeftHandItem"] then
        Play("LeftHandMeleeBlockedAttack")
        hasAttack = true
    end
    if self:get():GetFullName() == handItem["RightHandItem"] then
        Play("RightHandMeleeBlockedAttack")
        hasAttack = true
    end
    if not hasAttack then
        Play("LeftHandMeleeBlockedAttack")
        Play("RightHandMeleeBlockedAttack")
    end
end

local function OnParriedAttack(self)
    local hasAttack = false
    if self:get():GetFullName() == handItem["LeftHandItem"] then
        Play("LeftHandMeleeParriedAttack")
        hasAttack = true
    end
    if self:get():GetFullName() == handItem["RightHandItem"] then
        Play("RightHandMeleeParriedAttack")
        hasAttack = true
    end
    if not hasAttack then
        Play("LeftHandMeleeParriedAttack")
        Play("RightHandMeleeParriedAttack")
    end
end

-- Item physics hit (e.g. throwing)
local function OnActorHitLevelCheck(self, SelfActor, OtherActor, NormalImpulse, Hit)
    if math.abs(NormalImpulse:get().X) > 200 then
        if self:get():GetFullName() == handItem["LeftHandItem"] then
            Play("LeftHandItemHit")
            if string.find(OtherActor:get():GetFullName(), "_PlayerHand_") then
                Play("RightHandItemHit")
            end
        end
        if self:get():GetFullName() == handItem["RightHandItem"] then
            Play("RightHandItemHit")
            if string.find(OtherActor:get():GetFullName(), "_PlayerHand_") then
                Play("LeftHandItemHit")
            end
        end
    end
end

-- Forging (hammer area)
local function OnHammerAreaBeginOverlap(self, OverlappedComponent, OtherActor, OtherComp, bFromSweep, SweepResult)
    if os.clock() - forgeTime < 0.2 then return end
    forgeTime = os.clock()
    local hasAttack = false
    if self:get():GetFullName() == handItem["LeftHandItem"] then
        Play("LeftHandMeleeBlockedAttack")
        hasAttack = true
    end
    if self:get():GetFullName() == handItem["RightHandItem"] then
        Play("RightHandMeleeBlockedAttack")
        hasAttack = true
    end
    if not hasAttack then
        Play("LeftHandMeleeBlockedAttack")
        Play("RightHandMeleeBlockedAttack")
    end
end

-- Crush (strength / grip)
local function OnStrengthSourceBeginCrush(self, SourceActor, Char, Hand)
    if Hand:get():GetPropertyValue("ControllerHand") == 1 then
        isRightHandCrush = true
    else
        isLeftHandCrush = true
    end
end

local function OnStrengthSourceEndCrush(self, SourceActor, Char, Hand)
    if Hand:get():GetPropertyValue("ControllerHand") == 1 then
        isRightHandCrush = false
    else
        isLeftHandCrush = false
    end
end

local function OnStrengthSourceCrushed(self, SourceActor, Char, Hand)
    if Hand:get():GetPropertyValue("ControllerHand") == 1 then
        Play("RightHandCrushed")
    else
        Play("LeftHandCrushed")
    end
end

-- LoreCollectible crush
local function LoreCollectibleCrushBegin(self, CrushComponent, Actor, PC, Character, Hand)
    if Hand:get():GetPropertyValue("ControllerHand") == 1 then
        isRightHandCrush = true
    else
        isLeftHandCrush = true
    end
end

local function LoreCollectibleCrushEnd(self, CrushComponent, Actor, PC, Character, Hand)
    if Hand:get():GetPropertyValue("ControllerHand") == 1 then
        isRightHandCrush = false
    else
        isLeftHandCrush = false
    end
end

local function LoreCollectibleCrushed(self, CrushComponent, Actor, PC, Character, Hand)
    if Hand:get():GetPropertyValue("ControllerHand") == 1 then
        Play("RightHandCrushed")
    else
        Play("LeftHandCrushed")
    end
end

-- MaxHealthUp crush
local function OnBeginCrushDelegate_Event(self, CrushComponent, Actor, PC, Character, Hand)
    if Hand:get():GetPropertyValue("ControllerHand") == 1 then
        isRightHandCrush = true
    else
        isLeftHandCrush = true
    end
end

local function OnEndCrushDelegate_Event(self, CrushComponent, Actor, PC, Character, Hand)
    if Hand:get():GetPropertyValue("ControllerHand") == 1 then
        isRightHandCrush = false
    else
        isLeftHandCrush = false
    end
end

local function OnCrushedDelegate_Event(self, CrushComponent, Actor, PC, Character, Hand)
    if Hand:get():GetPropertyValue("ControllerHand") == 1 then
        Play("RightHandCrushed")
    else
        Play("LeftHandCrushed")
    end
end

-- Grapple / rope
local function FireRope(self)
    Play("FireRope")
end

local function OnRopeGrappleHookZipEngaged(self)
    isRopeGrappleHookZip = true
end

local function OnRopeGrappleHookZipDisengaged(self)
    isRopeGrappleHookZip = false
end

local function RopePullTick(self)
    if os.clock() - lastRopePullTime > 0.15 then
        lastRopePullTime = os.clock()
        Play("RopePull")
    end
end

-- Save point
local function SavePointOnGripRelease(self, Hand)
    local handVal = Hand:get():GetPropertyValue("ControllerHand")
    if os.clock() - lastSavePointTime < 0.5 and lastReleaseHand ~= handVal then
        Play("SaveGame")
    end
    lastSavePointTime = os.clock()
    lastReleaseHand   = handVal
end

-- Player state
local function OnCrouch(self)
    Play("Crouch")
end

local function OnDodge(self)
    Play("Dodge")
end

local function BP_StrengthStateChanged(self) end   -- reserved, no effect yet

local function OnDamageTaken(self)
    local camera = self:get():GetPropertyValue("Controller"):GetPropertyValue("PlayerCameraManager")
    if not camera:IsValid() then return end
    local view = camera:GetPropertyValue("ViewTarget")
    if not view:IsValid() then return end
    local playerYaw = view.POV.Rotation.Yaw

    local enemy = self:get():GetPropertyValue("LastHitBy")
    if not enemy:IsValid() then
        Play("NoEnemyDamage")
        return
    end
    local enemyPawn = enemy:GetPropertyValue("Pawn")
    if not enemyPawn:IsValid() then return end
    local enemyController = enemyPawn:GetPropertyValue("Controller")
    if not enemyController:IsValid() then return end
    local targetRotation = enemyController:GetPropertyValue("ControlRotation")
    if not targetRotation:IsValid() then return end

    local angleYaw = (playerYaw - targetRotation.Yaw + 180) % 360
    if angleYaw < 0 then angleYaw = angleYaw + 360 end

    PlayParam("DefaultDamage", 0, 1.0, 1.0, angleYaw, 0.0)
end

local function OnActivateStrength(self)
    Play("StrengthActivated")
end

local function OnBeginStrengthAbsorb(self)
    Play("StrengthAbsorb")
end

local function OnCameraShake(self)
    Play("CameraShake")
end

local function OnCharacterDeath(self)
    Play("PlayerDeath")
    playerHealth = 0
end

local function OnHealthUpdated(self, PrevHealth, NewHealth)
    if PrevHealth:get() < NewHealth:get() then
        if os.clock() - healingTime > 1.2 then
            healingTime = os.clock()
            Play("Healing")
        end
    end
    playerHealth  = NewHealth:get()
    heartbeatTime = os.clock()
end

-- ─── On-demand hook registration ─────────────────────────────────────────────
-- These blueprint actors aren't loaded at startup, so we hook them the first
-- time we see them referenced by the main AttachInventory / HeldActorGrab hooks.

local function RegisterLoreCollectible()
    for k, v in pairs(hookIds2) do
        UnregisterHook(k, v.id1, v.id2)
    end
    hookIds2 = {}

    local hooks = {
        { "/Game/BHM/Interactables/LoreCollectible/BP_LoreCollectible.BP_LoreCollectible_C:BndEvt__BP_LoreCollectible_PLCInteractionCrush_K2Node_ComponentBoundEvent_2_PLCGenericCrushSignature__DelegateSignature", LoreCollectibleCrushEnd },
        { "/Game/BHM/Interactables/LoreCollectible/BP_LoreCollectible.BP_LoreCollectible_C:BndEvt__BP_LoreCollectible_PLCInteractionCrush_K2Node_ComponentBoundEvent_1_PLCGenericCrushSignature__DelegateSignature", LoreCollectibleCrushBegin },
        { "/Game/BHM/Interactables/LoreCollectible/BP_LoreCollectible.BP_LoreCollectible_C:BndEvt__BP_LoreCollectible_PLCInteractionCrush_K2Node_ComponentBoundEvent_0_PLCGenericCrushSignature__DelegateSignature", LoreCollectibleCrushed },
    }
    for _, entry in ipairs(hooks) do
        local ok, result1, result2 = pcall(RegisterHook, entry[1], entry[2])
        if ok then
            hookIds2[entry[1]] = { id1 = result1, id2 = result2 }
        else
            print("[BehemothHaptics] LoreCollectible hook failed: " .. entry[1])
        end
    end
end

local function RegisterMaxHealthUp()
    for k, v in pairs(hookIds3) do
        UnregisterHook(k, v.id1, v.id2)
    end
    hookIds3 = {}

    local hooks = {
        { "/Game/BHM/Blueprints/Interactables/Craftables/BP_MaxHealthUp.BP_MaxHealthUp_C:OnBeginCrushDelegate_Event",  OnBeginCrushDelegate_Event },
        { "/Game/BHM/Blueprints/Interactables/Craftables/BP_MaxHealthUp.BP_MaxHealthUp_C:OnEndCrushDelegate_Event",    OnEndCrushDelegate_Event },
        { "/Game/BHM/Blueprints/Interactables/Craftables/BP_MaxHealthUp.BP_MaxHealthUp_C:OnCrushedDelegate_Event",     OnCrushedDelegate_Event },
    }
    for _, entry in ipairs(hooks) do
        local ok, result1, result2 = pcall(RegisterHook, entry[1], entry[2])
        if ok then
            hookIds3[entry[1]] = { id1 = result1, id2 = result2 }
        else
            print("[BehemothHaptics] MaxHealthUp hook failed: " .. entry[1])
        end
    end
end

-- ─── Main hook registration ───────────────────────────────────────────────────

local function RegisterHooks()
    for k, v in pairs(hookIds) do
        UnregisterHook(k, v.id1, v.id2)
    end
    hookIds = {}

    local hooks = {
        -- Inventory
        { "/Script/SDIGamePlugin.SDIInventorySlot:AttachInventory",                                                                         AttachInventory },
        { "/Script/SDIGamePlugin.SDIInventoryActor:GrabFromInventory",                                                                      GrabFromInventory },
        -- Player
        { "/Game/BHM/Blueprints/Player/BP_BHM_PlayerCharacter.BP_BHM_PlayerCharacter_C:OnCharacterDeath",                                  OnCharacterDeath },
        { "/Game/BHM/Blueprints/Player/BP_BHM_PlayerCharacter.BP_BHM_PlayerCharacter_C:OnDamageTaken",                                     OnDamageTaken },
        { "/Game/BHM/Blueprints/Player/BP_BHM_PlayerCharacter.BP_BHM_PlayerCharacter_C:OnDodge",                                           OnDodge },
        { "/Game/BHM/Blueprints/Player/BP_BHM_PlayerCharacter.BP_BHM_PlayerCharacter_C:K2_OnStartCrouch",                                  OnCrouch },
        { "/Game/BHM/Blueprints/Player/BP_BHM_PlayerCharacter.BP_BHM_PlayerCharacter_C:BP_StrengthStateChanged",                           BP_StrengthStateChanged },
        { "/Game/BHM/Blueprints/Player/BP_BHM_PlayerCharacter.BP_BHM_PlayerCharacter_C:OnHealthUpdated",                                   OnHealthUpdated },
        -- Grip
        { "/Script/SDIGamePlugin.SDIHeldActor:Grab",                                                                                        HeldActorGrab },
        { "/Script/SDIGamePlugin.SDIInteractiveActorInterface:OnGripPress",                                                                 OnGripPress },
        { "/Script/SDIGamePlugin.SDIInteractiveActorInterface:OnGripRelease",                                                               OnGripRelease },
        -- Melee weapon
        { "/Game/BHM/Blueprints/Interactables/Weapons/BP_BHM_Melee_Weapon_Base.BP_BHM_Melee_Weapon_Base_C:OnAttackBlocked",                OnAttackBlocked },
        { "/Game/BHM/Blueprints/Interactables/Weapons/BP_BHM_Melee_Weapon_Base.BP_BHM_Melee_Weapon_Base_C:OnBlockedAttack",                OnBlockedAttack },
        { "/Game/BHM/Blueprints/Interactables/Weapons/BP_BHM_Melee_Weapon_Base.BP_BHM_Melee_Weapon_Base_C:OnParriedAttack",                OnParriedAttack },
        { "/Game/BHM/Blueprints/Interactables/Weapons/BP_BHM_Melee_Weapon_Base.BP_BHM_Melee_Weapon_Base_C:AddBloodToHands",                OnHit },
        -- Bow
        { "/Game/BHM/Blueprints/Interactables/Weapons/Bow/BP_BHM_Bow.BP_BHM_Bow_C:LaunchArrow",                                           LaunchArrow },
        { "/Game/BHM/Blueprints/Interactables/Weapons/Bow/BP_BHM_Bow.BP_BHM_Bow_C:OnInteractPress",                                       OnInteractPress },
        { "/Game/BHM/Blueprints/Interactables/Weapons/Bow/BP_BHM_Bow.BP_BHM_Bow_C:OnGripRelease",                                         BowOnGripRelease },
        { "/Game/BHM/Blueprints/Interactables/Weapons/Bow/BP_BHM_Arrow.BP_BHM_Arrow_C:ReturnToInventory",                                 ReturnToInventory },
        -- Scroll
        { "/Game/BHM/Blueprints/Player/Scroll/BP_BHM_Player_Scroll.BP_BHM_Player_Scroll_C:OnGripRelease",                                 ScrollOnGripRelease },
        -- Physics hits
        { "/Script/SDIGamePlugin.SDIHeldActor:OnActorHitLevelCheck",                                                                        OnActorHitLevelCheck },
        -- Grapple hook
        { "/Game/BHM/Blueprints/Interactables/Props/GrappleHook/BP_GrappleHookGun_V2.BP_GrappleHookGun_V2_C:FireRope",                    FireRope },
        { "/Script/BHM.BHMRopeReactionInterface:OnRopeGrappleHookZipEngaged",                                                              OnRopeGrappleHookZipEngaged },
        { "/Script/BHM.BHMRopeReactionInterface:OnRopeGrappleHookZipDisengaged",                                                           OnRopeGrappleHookZipDisengaged },

        -- Strength activation
        { "/Game/BHM/Blueprints/Player/BP_BHM_BasePlayerHand.BP_BHM_BasePlayerHand_C:OnActivateStrength",                                  OnActivateStrength },
        { "/Game/BHM/Blueprints/Interactables/Props/HollowStrengthAbsorb/BP_HollowStrengthAbsorb.BP_HollowStrengthAbsorb_C:OnBeginStrengthAbsorb", OnBeginStrengthAbsorb },
        -- Camera shake
        { "/Script/Engine.PlayerController:ClientStartCameraShake",                                                                         OnCameraShake },
        -- Strength / crush
        { "/Script/BHM.BHMPlayerController:OnStrengthSourceBeginCrush",                                                                    OnStrengthSourceBeginCrush },
        { "/Script/BHM.BHMPlayerController:OnStrengthSourceEndCrush",                                                                      OnStrengthSourceEndCrush },
        { "/Script/BHM.BHMPlayerController:OnStrengthSourceCrushed",                                                                       OnStrengthSourceCrushed },

        -- Pause menu
        { "/Game/BHM/Blueprints/Player/BP_BHM_GamePausedUI.BP_BHM_GamePausedUI_C:HideElements",                                           HideElements },
        { "/Game/BHM/Blueprints/Player/BP_BHM_GamePausedUI.BP_BHM_GamePausedUI_C:EnableElements",                                         EnableElements },
        { "/Game/BHM/UI/WBP/WBP_BHM_PauseMenu.WBP_BHM_PauseMenu_C:BndEvt__BTNExit_K2Node_ComponentBoundEvent_13_OnPressedEventDispatcher__DelegateSignature",   BndEvt__BTNExit },
        { "/Game/BHM/UI/WBP/WBP_BHM_PauseMenu.WBP_BHM_PauseMenu_C:BndEvt__BTNResume_K2Node_ComponentBoundEvent_8_OnPressedEventDispatcher__DelegateSignature",  BndEvt__BTNResume },
        -- Save / load
        { "/Game/BHM/UI/WBP/WBP_BHM_SaveGame.WBP_BHM_SaveGame_C:LoadGame",                                                               LoadGame },
        -- Zone / boss triggers (reuse existing callbacks)
        { "/Game/BHM/Maps/World/ZoneBat/ZoneBat_Boss/ZoneBat_Boss_Des.ZoneBat_Boss_Des_C:BndEvt__ZoneBat_Boss_Des_TriggerBox_2_K2Node_ActorBoundEvent_2_ActorBeginOverlapSignature__DelegateSignature",               GrabFromInventory },
        { "/Game/BHM/Maps/World/ZoneBat/ZoneBat_Boss/ZoneBat_Boss_Des.ZoneBat_Boss_Des_C:BndEvt__ZoneBat_Boss_Des_BP_SetPieceManager_C_0_K2Node_ActorBoundEvent_0_SequenceSetupElements__DelegateSignature",          ReturnToInventory },
    }

    local succeeded, failed = 0, 0
    for _, entry in ipairs(hooks) do
        local ok, result1, result2 = pcall(RegisterHook, entry[1], entry[2])
        if ok then
            hookIds[entry[1]] = { id1 = result1, id2 = result2 }
            succeeded = succeeded + 1
        else
            print("[BehemothHaptics] Hook failed: " .. entry[1])
            failed = failed + 1
        end
    end
    print("[BehemothHaptics] RegisterHooks complete: " .. succeeded .. " ok, " .. failed .. " failed.")
end

-- ─── Player spawn — register hooks once the controller is ready ───────────────

RegisterHook("/Script/Engine.PlayerController:ClientRestart", function()
    if not resetHook then return end
    RegisterHooks()
    resetHook = false
end)

-- On-demand hook registration triggered by HeldActorGrab seeing relevant actors
RegisterHook("/Script/SDIGamePlugin.SDIHeldActor:Grab", function(self)
    if not isLoreCollectibleRegister then
        if string.find(self:get():GetFullName(), "LoreCollectible") then
            local ran, err = pcall(RegisterLoreCollectible)
            if ran then isLoreCollectibleRegister = true end
        end
    end
    if not isMaxHealthUpRegister then
        if string.find(self:get():GetFullName(), "MaxHealthUp") then
            local ran, err = pcall(RegisterMaxHealthUp)
            if ran then isMaxHealthUpRegister = true end
        end
    end
end)

-- ─── Looping async effects ────────────────────────────────────────────────────

LoopAsync(1000, HeartBeat)
LoopAsync(150,  RopeGrappleHookZip)
LoopAsync(150,  LeftHandCrush)
LoopAsync(150,  RightHandCrush)

print("[BehemothHaptics] Mod loaded.")
