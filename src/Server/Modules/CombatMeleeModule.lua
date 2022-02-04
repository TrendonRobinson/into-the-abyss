local MeleeModule = {}



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