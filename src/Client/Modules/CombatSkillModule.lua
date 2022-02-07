local SkillModule = {}


function SkillModule:BindInputs(inputMode, inputManager)
end


function SkillModule:UnbindInputs(inputMode, inputManager)
end


-- Initializes the module
-- @param handlers <IndexedMap> located in CombatService's environment
function SkillModule:Setup(handlers)
    local CombatRequestType = self.Enums.CombatRequestType
end


return SkillModule