local ArcaneModule = {}


function ArcaneModule:BindInputs(inputMode, inputManager)
end


function ArcaneModule:UnbindInputs(inputMode, inputManager)
end


-- Initializes the module
-- @param handlers <IndexedMap> located in CombatService's environment
function ArcaneModule:Setup(handlers)
    local CombatRequestType = self.Enums.CombatRequestType
end


return ArcaneModule