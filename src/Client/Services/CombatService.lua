-- Combatservice client
-- Handles sending combat requests as well as forwarding replicated combat events
--
-- Dynamese(Enduo)
-- 02.05.22



local CombatService = {} -- TODO: Need to start AFTER SkillService when that gets implemented
local Network, EntityService, InputManager
local CombatSkillModule, CombatArcaneModule, CombatArcheryModule, CombatMeleeModule

local CombatRequestType, WeaponClass, WeaponConfiguration
local ReplicationHandlers, OwnEntity

local InputsBound = false


-- Receives server replication events and plays them locally
-- @param dt <number>
-- @param combatType <Enums.CombatRequestType>
-- @param ... <any>
local function CombatReplicator(dt, combatType, ...)
    --ReplicationHandlers:Get(combatType)(dt, ...)
end


-- Tells modules to listen for inputs
-- TODO: Only bind one module based on equip configuration
--  and change which module is bound as equipment changes
-- @param inputMode <string>
local function BindInputs(inputMode)
    if (InputsBound) then return end
    InputsBound = true

    -- CombatArcaneModule:BindInputs(inputMode, InputManager)
    -- CombatArcheryModule:BindInputs(inputMode, InputManager)
    CombatMeleeModule:BindInputs(inputMode, OwnEntity, InputManager)
    -- CombatSkillModule:BindInputs(inputMode, InputManager)
end


-- Tells modules to stop listening/abort
local function UnbindInputs()
    if (not InputsBound) then return end
    InputsBound = false

    -- CombatArcaneModule:UnbindInputs(InputManager)
    -- CombatArcheryModule:UnbindInputs(InputManager)
    CombatMeleeModule:UnbindInputs(InputManager)
    -- CombatSkillModule:UnbindInputs(InputManager)
end


local function RegisterOwnEntity(base)
    if (base ~= CombatService.LocalPlayer.Character) then return end

    OwnEntity = EntityService:GetEntity(base)

    OwnEntity.StateMachine:AddTransitionHandler("StaggerStart", UnbindInputs)
    OwnEntity.StateMachine:AddTransitionHandler("StaggerStop", BindInputs)

    BindInputs("KEYBOARD_MOUSE")
    OwnEntity.OnDestroyed:Connect(UnbindInputs)
end


-- TODO: As this service HAS to load AFTER AnimationService 
--  (submodules need to be able to play animations)
--  we eventually need something in AnimationService exposed to us
--  from which would allow setting core animator according to weapon
--  configuration and/or potential cash shop core animators
-- TODO: For now, we default with a nil return, but in the future
--  this should never return nil as we should never call this
--  function in the case we are not equipped for melee
-- @param primary <EquipSlot> main weapon
-- @param secondary <EquipSlot> offhand weapon
-- @returns <CONFIGURATION>
function CombatService.GetWeaponConfiguration(primary, secondary)
    local currentConfig = nil

    -- First check primary for configuration information
    -- If empty, disregard and check secondary
    if (primary.BaseID ~= -1) then
        if (primary.Info.Class == WeaponClass.Greatsword) then
            -- Primary is greatsword, immediate exit
            return WeaponConfiguration.TWO_HANDED_SWORD
        end
    end

    -- Based on what we know so far (currentConfig) about our primary,
    --  make further decisions from our secondary
    if (secondary.BaseID ~= -1) then
        return nil
    end

    return nil
end


function CombatService:EngineInit()
    Network = self.Services.Network
    EntityService = self.Services.EntityService
    InputManager = self.Services.InputManager

    CombatRequestType = self.Enums.CombatRequestType
    WeaponClass = self.Enums.WeaponClass
    WeaponConfiguration = self.Enums.WeaponConfiguration

    -- Load and setup sub modules
    -- CombatSkillModule = self.Modules.CombatSkillModule
    -- CombatArcaneModule = self.Modules.CombatArcaneModule
    -- CombatArcheryModule = self.Modules.CombatArcheryModule
    CombatMeleeModule = self.Modules.CombatMeleeModule
    

    -- CombatSkillModule:Setup()
    -- CombatArcaneModule:Setup()
    -- CombatArcheryModule:Setup()
    CombatMeleeModule:Setup()

    ReplicationHandlers = self.Classes.IndexedMap.new()
    -- ReplicationHandlers:Add(CombatRequestType.ReplicatSkill, CombatSkillModule.ReplicateHandler)
    -- ReplicationHandlers:Add(CombatRequestType.ReplicateArcane, CombatArcaneModule.ReplicateHandler)
    -- ReplicationHandlers:Add(CombatRequestType.ReplicateArchery, CombatArcheryModule.ReplicateHandler)
    ReplicationHandlers:Add(CombatRequestType.ReplicateMelee, CombatMeleeModule.ReplicateHandler)
end


function CombatService:EngineStart()
	Network:HandleRequestType(Network.NetRequestType.CombatReplicate, CombatReplicator)
    EntityService.EntityCreated:Connect(RegisterOwnEntity)

    if (not OwnEntity and EntityService:GetEntity(self.LocalPlayer.Character)) then
        BindInputs(self.LocalPlayer.Character)
    end
end


return CombatService

--[[

Automatically bind/unbind each of the modules' input listeners
    as own entity changes state

While bound, combat modules will be listening for inputs and handle things on their own

]]