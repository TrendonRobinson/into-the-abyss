local ArcheryModule = {}


function ArcheryModule:BindInputs(inputMode, inputManager)
end


function ArcheryModule:UnbindInputs(inputMode, inputManager)
end


-- Initializes the module
-- @param handlers <IndexedMap> located in CombatService's environment
function ArcheryModule:Setup(handlers)
    local CombatRequestType = self.Enums.CombatRequestType
end


return ArcheryModule