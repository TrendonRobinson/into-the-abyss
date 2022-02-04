-- Combatservice server
-- Handles combat-related requests and replicates attacks
-- Will handle the four types of combat via submodules (Melee, Archery, Magic autos, Skills)
-- Each submodule will have their own specifically implemented request validation methods
--  as well as executions
--
-- Dynamese(Enduo)
-- 01.30.22



local CombatService = {}
local Network, AssetService, EntityService
local MeleeModule, ArcheryModule, ArcaneModule, SkillModule

local CombatRequestType
local RequestHandlers


local function CombatRequestHandler(user, dt, requestType, ...)
    local handler = RequestHandlers:Get(requestType)

    if (handler) then
        return handler(CombatService, user, dt, ...)
    end

    CombatService:Warn("Invalid combat request type: ", requestType, ...)

    return nil
end


function CombatService:MeleeAttack(user, dt, meleeID)
    local meleeAsset = AssetService:GetAsset(meleeID)
    return MeleeModule:TryAttack(EntityService:GetEntity(user), dt, meleeAsset)
end


function CombatService:MeleeProcess(user, dt, victims)
    return MeleeModule:TryProcess(
        EntityService:GetEntity(user), dt,
        EntityService:GetEntities(victims))
end


function CombatService:EngineInit()
    Network = self.Services.Network
    AssetService = self.Services.AssetService
    EntityService = self.Services.EntityService

    CombatRequestType = self.Enums.CombatRequestType

    RequestHandlers = self.Classes.IndexedMap.new()

    -- Map requests to handlers
    RequestHandlers:Add(CombatRequestType.MeleeRequest, self.MeleeAttack)
    RequestHandlers:Add(CombatRequestType.MeleeHitRequest, self.MeleeProcess)
end


function CombatService:EngineStart()
    Network:HandleRequestType(Network.NetRequestType.CombatRequest, CombatRequestHandler)
end


return CombatService
