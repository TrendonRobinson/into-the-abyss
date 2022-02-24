local MeleeModule = {}
local AssetService, Network, AnimationService, MetronomeService

local ThreadUtil
local CombatRequestType, WeaponClass, MoveWeapons, EquipSlot
local Signal, Mutex, ListenerList, RaycastHitboxV4, Maid

-- Exists purely for cleanly binding/unbinding actions from inputservice
local ACTIONS = {
    START_AUTO_ATTACK_MELEE = "Attack_Melee_Auto_Stop";
    STOP_AUTO_ATTACK_MELEE = "Attack_Melee_Auto_Start";
}

-- Represent what type of weapons are equipped
local CONFIGURATION = {
    TWO_HANDED_SWORD = "Sword2H";
}

-- Fallback defaults if none equipped for specific configuration
local DEFAULT_MOVESETS = {
    [CONFIGURATION.TWO_HANDED_SWORD] = "111";
}

local State, OwnEntity, InputMaid, InputsUnbound


-- TODO: Check if primary weapon asset has special moveset
-- Retrieves moveset BaseID to be later retrieved via AssetService
-- @param configuration <CONFIGURATION>
-- @returns <string>
function MeleeModule.GetMovesetBaseID(configuration)
    return DEFAULT_MOVESETS[configuration]
end


-- TODO: For now, we default with a nil return, but in the future
--  this should never return nil as we should never call this
--  function in the case we are not equipped for melee
-- @param primary <EquipSlot> main weapon
-- @param secondary <EquipSlot> offhand weapon
-- @returns <CONFIGURATION>
function MeleeModule.GetWeaponConfiguration(primary, secondary)
    local currentConfig = nil

    -- First check primary for configuration information
    -- If empty, disregard and check secondary
    if (primary.BaseID ~= -1) then
        if (primary.Info.Class == WeaponClass.Greatsword) then
            -- Primary is greatsword, immediate exit
            return CONFIGURATION.TWO_HANDED_SWORD
        end
    end

    -- Based on what we know so far (currentConfig) about our primary,
    --  make further decisions from our secondary
    if (secondary.BaseID ~= -1) then
        return nil
    end

    return nil
end


-- Creates a hitbox or hitboxes depending on which weapon(s) is/are
--  related to the move asset
-- @param moveset <Asset>
-- @return <arraylike<Hitbox>>
function MeleeModule.MakeHitboxes(moveset)
    local hitboxes = {}
    local params = RaycastParams.new()

    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = {OwnEntity.Base}

    if (moveset.Weapons == MoveWeapons.PRIMARY or moveset.Weapons == MoveWeapons.BOTH) then
        table.insert(
            hitboxes,
            RaycastHitboxV4.new(
                OwnEntity.EquipmentModels[EquipSlot.Primary]
            ):SetRayParams(params)
        )
    end

    if (moveset.Weapons == MoveWeapons.SECONDARY or moveset.Weapons == MoveWeapons.BOTH) then
        table.insert(
            hitboxes,
            RaycastHitboxV4.new(
                OwnEntity.EquipmentModels[EquipSlot.Secondary]
            ):SetRayParams(params)
        )
    end

    return hitboxes
end


-- Run through all the decisions and attempt to attack
-- Concurrent routines here:
--  Main
--  Interuptor
--  Asset requester
--  Key requester
--  Hit registrator
--  Attack ender, when the next chain attack can start
--  Attack expirer, when the chain expires
function MeleeModule.TryAttack()
    -- Owner thread still attacking
    if (not State.Accessor:TryLock()) then return end

    -- Primary/secondary weapon slots
    -- Could techincally make config and moveset global,
    --  but that would make things harder to read
    local weapons = {unpack(OwnEntity.Equipment, 4, 5)}
    local configuration = MeleeModule.GetWeaponConfiguration(weapons[1], weapons[2])

    -- Invalid weapons for a melee attack, assure we unlock and exit
    if (not configuration) then State.Accessor:Unlock() return end

    local finished = Signal.new() -- True: successful attack, False: interupted
    local interupted = false
    local interupter = ListenerList.new(
        OwnEntity.OnDestroyed,
        InputsUnbound
        -- OwnEntity.Died,
        -- etc
    ):Connect(function()
        interupted = true -- Checked after blocking calls
        finished:Fire(false) -- Abort the entire action
    end)

    -- Retrieve move data
    local movesetBaseID = MeleeModule.GetMovesetBaseID(configuration) -- Blocking call
    local moveset = AssetService:GetAsset(movesetBaseID) -- Blocking call
    local animator = AnimationService:GetAnimator(OwnEntity) -- Blocking call
    local now = tick()

    -- If interupted during the blocking calls, abort
    if (interupted) then 
        interupter:Disconnect()
        State.Accessor:Unlock()
        return
    end

    -- Entity state
    OwnEntity.StateMachine:Transition("MeleeStart1")

    -- Last window interupted/expired or last attach reached end of chain
    if (State.Machine.CurrentState ~= -1 and (State.LastAttack.Interupted or now > State.LastAttack.StopsAt)
        or State.Machine.CurrentState == moveset.Moves.Count - 1) then
        State.Machine:Transition("Any-1")
    end

    -- Stateswitch to attack-to-be
    State.Machine:Transition(State.Machine.CurrentState .. State.Machine.CurrentState + 1)

    -- Grab move and prep next attack
    local move = moveset.Moves[tostring(State.Machine.CurrentState)] -- Moves are indexed by string inside the asset

    -- Ask for permission as well as signal that we are attacking
    -- If granted, a key will be returned, and our attack replicated
    Network:RequestServer(
        Network.NetRequestType.CombatRequest,
        CombatRequestType.MeleeRequest,
        movesetBaseID,
        move.AnimationName
    ):Connect(function(inKey)
        if (not inKey) then
            -- Permission denied, abort
            interupted = true
            finished:Fire(false)
            -- TODO: Reset statemachine
        else
            -- Permission granted and key received, start requesting hits
            State.PermissionKey = inKey
        end
    end)

    -- Get the animation and hit scanner going
    local actionID = animator:PlayAction(move.AnimationName, 0.3) -- Blocking call
    local actionTrack = animator:GetActionTrack(actionID)
    local hitboxes = MeleeModule.MakeHitboxes(moveset)
    local markerMaid = Maid.new()

    for _, hitbox in ipairs(hitboxes) do
        markerMaid:GiveTask(hitbox.OnHit:Connect(function(part, humanoid, rayResults, group)
            print(part, humanoid, rayResults, group)
        end))
    end
    markerMaid:GiveTask(actionTrack:GetMarkerReachedSignal("BeginSwing"):Connect(function() 
        for _, hitbox in ipairs(hitboxes) do
            hitbox:HitStart()
        end
    end))
    markerMaid:GiveTask(actionTrack:GetMarkerReachedSignal("EndSwing"):Connect(function() 
        for _, hitbox in ipairs(hitboxes) do
            hitbox:HitStop()
        end
    end))
    
    -- Delay until the end of the swing section
    -- IFF we reach it uninterupted, prepare for next
    --  potential attack, cleanup and release lock
    ThreadUtil.IntDelay(
        move.SwingEnd,
        function()
            finished:Fire(true)
        end,
        finished)

    -- Update "Last attack" info since this attack is now the most recent
    State.LastAttack.StartedAt = now
    State.LastAttack.StopsAt = now + move.SwingStop

    -- Log state and cleanup
    State.LastAttack.Interupted = interupted or not finished:Wait() -- This *should* short circuit

    interupter:Disconnect()
    markerMaid:Destroy()

    for _, hitbox in ipairs(hitboxes) do
        hitbox:HitStop()
    end

    -- We can only call StopAction if the entity had not despawned
    -- e.g. the animator had not cleaned itself up yet
    if (interupted and animator.StopAction ~= nil) then 
        animator:StopAction(actionID, 0.0)
    end
    
    OwnEntity.StateMachine:Transition("MeleeStop")
    State.Accessor:Unlock()
end


-- When a hit is registered from TryAttack, request it to server
-- @param victimBase <Model>
-- @param key <string> the damage key given to us
function MeleeModule.RegisterHit(victimBase, key)
end


-- Receives melee replication event and plays it locally
-- @param dt1 <number> time it took to receive
-- @param dt2 <number> time it took for attacker's request to reach server
function MeleeModule.ReplicateHandler(dt1, dt2, ...)
    -- dt1 + dt2 = total time since attacker requested attack
end


-- Starts/stops auto attacking
function MeleeModule.StartAuto()
    if (State.Auto) then return end
    State.Auto = true
    State.AutoJobID = MetronomeService:BindToFrequency(2, MeleeModule.TryAttack)
    MeleeModule.TryAttack()
end
function MeleeModule.StopAuto()
    if (not State.Auto) then return end
    State.Auto = false
    MetronomeService:Unbind(State.AutoJobID)
    State.AutoJobID = nil
end


-- Create a statemachine allowing consecutive attacks up to
--  however many the user has unlocked for his/her weapon config
--  with an upper bound of however many the moveset has
--  as well as a path for resetting to 0
function MeleeModule.SetupStateMachine(entity)
    State.Accessor:Lock()

    local configuration = MeleeModule.GetWeaponConfiguration(entity.Equipment[4], entity.Equipment[5])

    -- No need to make one if we have no valid weapon config
    if (configuration ~= nil) then
        local movesetBaseID = MeleeModule.GetMovesetBaseID(configuration) -- Blocking call
        local moveset = AssetService:GetAsset(movesetBaseID) -- Blocking call
        local machine = MeleeModule.Classes.StateMachine.new(-1) -- -1: no prior attack, reset, or expired

        machine:AddTransition("Any-1", "Any", -1)

        for i = 0, moveset.Moves.Count do
            machine:AddState(i)
            machine:AddTransition(i - 1 .. i, i - 1, i, nil) -- TODO: Add qualifiers/handlers
        end

        State.Machine = machine
    end

    State.Accessor:Unlock()
end


-- Starts listening for combat inputs
-- @param inputMode <string>
-- @param ownEntity <EntityPC>
-- @param inputManager <Service>
function MeleeModule:BindInputs(inputMode, ownEntity, inputManager)
    OwnEntity = ownEntity

    -- Has blocking call
    MeleeModule.SetupStateMachine(ownEntity)

    -- Abort, unlock
    if (OwnEntity == nil) then return end

    -- Async bind, has blocking call
    InputMaid:GiveTask(ownEntity.EquipmentChanged:Connect(function(equipSlot, _, _)
        if (equipSlot == EquipSlot.Primary or equipSlot == EquipSlot.Secondary) then
            if (State.Machine) then State.Machine:Destroy() end
            MeleeModule.SetupStateMachine(ownEntity)
        end
    end))

    inputManager:BindAction(
        Enum.UserInputType.MouseButton1,
        ACTIONS.START_AUTO_ATTACK_MELEE,
        MeleeModule.StartAuto,
        Enum.UserInputState.Begin)
    inputManager:BindAction(
        Enum.UserInputType.MouseButton1,
        ACTIONS.STOP_AUTO_ATTACK_MELEE,
        MeleeModule.StopAuto,
        Enum.UserInputState.End)
end


-- Stops listening for combat inputs
-- @param inputManager <Service>
function MeleeModule:UnbindInputs(inputManager)
    for _, actionName in pairs(ACTIONS) do
        inputManager:UnbindAction(actionName)
    end

    if (State.Machine) then State.Machine:Destroy() end

    InputMaid:DoCleaning()
    MeleeModule.StopAuto()
    InputsUnbound:Fire()
    OwnEntity = nil
    State.Machine = nil
end


-- Initializes the module
-- @param handlers <IndexedMap> located in CombatService's environment
function MeleeModule:Setup()
    AssetService = self.Services.AssetService
    Network = self.Services.Network
    AnimationService = self.Services.AnimationService
    MetronomeService = self.Services.MetronomeService

    ThreadUtil = self.Modules.ThreadUtil

    CombatRequestType = self.Enums.CombatRequestType
    WeaponClass = self.Enums.WeaponClass
    MoveWeapons = self.Enums.MoveWeapons
    EquipSlot = self.Enums.EquipSlot

    Signal = self.Classes.Signal
    Mutex = self.Classes.Mutex
    ListenerList = self.Classes.ListenerList
    RaycastHitboxV4 = self.Classes.RaycastHitboxV4
    Maid = self.Classes.Maid

    -- Fires whenever we unbind inputs for whatever reason.
    -- Including a state change that invalidates combat
    InputsUnbound = Signal.new()
    InputMaid = Maid.new()

    -- Current attacking state and record of the
    --  previous attack used to choose next attack
    State = {
        Auto = false;
        PermissionKey = nil;
        Machine = nil;
        Accessor = Mutex.new();
        LastAttack = {
            Interupted = false;
            StartedAt = 0; -- When this attack started
            StopsAt = 0; -- When the chain expires
            ID = -1; -- Moveset BaseID
        };
    }
end


return MeleeModule

--[[

Attack chain defined by weapon configuration
Slams determined by above and current state our melee-specific FSM is in
    Slam function re-defined when our melee-specific FSM changes state
Inputs are unbound and rebound when weapon configuration changes
Inputs are unbound and rebound when state changes to/from those that we may not attack from

]]