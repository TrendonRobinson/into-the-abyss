-- Combatservice server
-- Handles combat-related requests and replicates attacks
-- Will handle the four types of combat via submodules (Melee, Archery, Magic autos, Skills)
-- Each submodule will have their own specifically implemented request validation methods
--  as well as executions
--
-- Dynamese(Enduo)
-- 01.30.22



local CombatService = {}
local Network

local RequestHandlers


local function CombatRequestHandler(user, dt, requestType, ...)
    local handler = RequestHandlers:Get(requestType)

    if (handler) then
        return handler(user, dt, ...)
    end

    CombatService:Warn("Invalid combat request type: ", requestType, ...)

    return nil
end


function CombatService:EngineInit()
    Network = self.Services.Network

    RequestHandlers = self.Classes.IndexedMap.new()

    -- Map requests to handlers
    self.Modules.CombatArcaneModule:Setup(RequestHandlers)
    self.Modules.CombatArcheryModule:Setup(RequestHandlers)
    self.Modules.CombatMeleeModule:Setup(RequestHandlers)
    self.Modules.CombatSkillModule:Setup(RequestHandlers)
end


function CombatService:EngineStart()
    Network:HandleRequestType(Network.NetRequestType.CombatRequest, CombatRequestHandler)
end


return CombatService
