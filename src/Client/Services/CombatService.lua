-- Combatservice client
-- Handles sending combat requests as well as forwarding replicated combat events
--
-- Dynamese(Enduo)
-- 02.05.22



local CombatService = {}
local Network, EntityService, InputManager
local CombatArcaneModule, CombatArcheryModule, CombatMeleeModule, CombatSkillModule
local CombatRequestType

local InputsBound = false

local ReplicationHandlers, OwnEntity


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


function CombatService:EngineInit()
    Network = self.Services.Network
    EntityService = self.Services.EntityService
    InputManager = self.Services.InputManager

    CombatRequestType = self.Enums.CombatRequestType

    -- Load and setup sub modules
    -- CombatArcaneModule = self.Modules.CombatArcaneModule
    -- CombatArcheryModule = self.Modules.CombatArcheryModule
    CombatMeleeModule = self.Modules.CombatMeleeModule
    -- CombatSkillModule = self.Modules.CombatSkillModule

    -- CombatArcaneModule:Setup()
    -- CombatArcheryModule:Setup()
    CombatMeleeModule:Setup()
    -- CombatSkillModule:Setup()

    ReplicationHandlers = self.Classes.IndexedMap.new()
    -- ReplicationHandlers:Add(CombatRequestType.ReplicateArcane, CombatArcaneModule.ReplicateHandler)
    -- ReplicationHandlers:Add(CombatRequestType.ReplicateArchery, CombatArcheryModule.ReplicateHandler)
    ReplicationHandlers:Add(CombatRequestType.ReplicateMelee, CombatMeleeModule.ReplicateHandler)
    -- ReplicationHandlers:Add(CombatRequestType.ReplicatSkill, CombatSkillModule.ReplicateHandler)
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