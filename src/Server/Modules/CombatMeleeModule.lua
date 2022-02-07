-- Combat Melee Module, server
-- Handles processing of melee-type basic attacks
-- 
-- Dynamese(Enduo)
-- 02.05.22



local MeleeModule = {}
local Network, AssetService, EntityService, DamageService
local HttpService


local OutstandingKeys


-- User attempting to attack
-- @param user <Player>
-- @param dt <number>
-- @param meleeID <string>
-- @param subID <number>
-- @returns <string> damage request key
function MeleeModule.TryAttack(user, dt, meleeID, subID)
    local meleeAsset = AssetService:GetAsset(meleeID)
    local attacker = EntityService:GetEntity(user.Character)

    if (MeleeModule.CanAttack(attacker, meleeAsset, subID)) then
        local key = MeleeModule.GenerateKey(user)

        Network:FireAllClients(Network:Pack(
            Network.NetProtocol.Forget,
            Network.NetRequestType.CombatReplicate,
            user, meleeID, dt
        ))

        return key
    end

    return nil
end


-- User attempting to deal damage to victims
-- @param user <Player>
-- @param dt <number>
-- @param key <string>
-- @param victimBases <arraylike<Model>>
function MeleeModule.TryProcess(user, dt, key, victimBases)
    local attacker = EntityService:GetEntity(user.Character)
    local victims = EntityService:GetEntities(victimBases)
    local package = DamageService:Package(attacker, 1, 0, 0, 1)

    for _, victim in ipairs(victims) do
        if (MeleeModule.CanHit(attacker, dt, key, victim)) then
            DamageService:Hurt(victim, attacker, package, false)
        end
    end
end


-- Validates if the attacker is allowed to execute this attack
-- @param attacker <EntityPC>
-- @param meleeAsset <Asset> attack info for weapon configuration
-- @param subID <number> specific attack
-- @returns <boolean>
function MeleeModule.CanAttack(attacker, meleeAsset, subID)
    -- TODO: confirm if this melee and specific melee are executable
    return attacker.Attributes.Health > 0
end


-- Creates a key that the user may request hits with
-- @param user <Player>
-- @returns <string>
function MeleeModule.GenerateKey(user)
    local guid = HttpService:GenerateGUID()
    
    -- TODO: Discern expiration stamp
    OutstandingKeys:Add(guid, {
        Generated = tick();
        Expires = tick() + 1000;
        AcceptWindow = {3, 10}; -- from .Generated
        User = user;
    })

    return guid
end


-- Validates if the attacker is allowed to hurt this victim
-- @param attacker <EntityPC>
-- @param dt <number>
-- @param key <string>
-- @param victim <EntityNoid>
-- @returns <boolean>
function MeleeModule.CanHit(attacker, dt, key, victim)
    local keyData = OutstandingKeys:Get(key)

    -- TODO: Netcode to allow laggier users
    --  e.g. shift accept window by user latency

    return keyData 
        and keyData.User == attacker.Player
        and attacker.Attributes.Health > 0
        and victim.Attributes.Health > 0
end


-- Initializes the module
-- @param handlers <IndexedMap> located in CombatService's environment
function MeleeModule:Setup(handlers)
    local CombatRequestType = self.Enums.CombatRequestType

    Network = self.Services.Network
    AssetService = self.Services.AssetService
    EntityService = self.Services.EntityService
    DamageService = self.Services.DamageService

    HttpService = self.RBXServices.HttpService

    OutstandingKeys = self.Classes.IndexedMap.new()

    -- Binds handlers to certain combat requests
    handlers:Add(CombatRequestType.MeleeRequest, MeleeModule.TryAttack)
    handlers:Add(CombatRequestType.MeleeHitRequest, MeleeModule.TryProcess)
end


return MeleeModule

--[[

Client clicks
IFF combat inputs bound to entity state, check weapons equipped

IFF some configuration of melee weapons equipped
    <determine what meleeID to use based on configuration; will assume default greatsword for now>
    download melee data
    play animation
        begin hitreg at certain animation marker
        queue hits until submission key receives later
    send combat request for melee
    request contains melee ID, based on weapon class and asset-specific overides
    request contains melee sub ID, based on recent attacks

server validates, replicates, and returns a key for the attacker to use when doing hitreg
    key is valid for duration based on meleeID/subID and ping

attacker client receives key, submits all hits up until now, and continues sending

clients receive replication request, downloads assets necessary
    meleeID, which yields animation pack
    meleSubID, which yields specific animation
    seek animation track(s) forward by latency

server processes hitregs and deals damage; replicates
    submitted hitregs will be validated based on the window that the key was allotted
    accounting for latency to allow laggier players to still play the game

]]