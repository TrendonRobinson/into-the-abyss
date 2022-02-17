--- Main RaycastModuleV4 2021
-- @author Swordphin123

--[[
____________________________________________________________________________________________________________________________________________________________________________

	If you have any questions, feel free to message me on DevForum. Credits not neccessary but is appreciated.
	
	[ How To Use - Quick Start Guide ]
	
		1. Insert Attachments to places where you want your "hitbox" to be. For swords, I like to have attachments 1 stud apart and strung along the blade.
		2. Name those Attachments "DmgPoint" (so the script knows). You can configure what name the script will look for in the variables below.
		3. Open up a script. As an example, maybe we have a sword welded to the character or as a tool. Require this, and initialize:
				
				* Example Code
					
					local Damage = 10
					local Hitbox = RaycastHitbox.new(Character)
					
					Hitbox.OnHit:Connect(function(hit, humanoid)
						print(hit.Name)
						humanoid:TakeDamage(Damage)
					end)
					
					Hitbox:HitStart() --- Turns on the hitbox
					wait(10) --- Waits 10 seconds
					Hitbox:HitStop() --- Turns off the hitbox
		
		4. Profit. Refer to the API below for more information.
				

____________________________________________________________________________________________________________________________________________________________________________

	[ RaycastHitBox API ]

		* local RaycastHitbox = require(RaycastHitboxV4) ---Duh
				--- To use, insert this at the top of your scripts or wherever.


			[ FUNCTIONS ]

		* RaycastHitbox.new(Instance model | BasePart | nil)
				Description
					--- Preps the model and recursively finds attachments in it so it knows where to shoot rays out of later. If a hitbox exists for this
					--- object already, it simply returns the same hitbox.
				Arguments
					--- Instance:  (Like your character, a sword model, etc). Can be left nil in case you want an empty Hitbox or use SetPoints later
				Returns
					Instance HitboxObject
						
		* RaycastHitModule:GetHitbox(Instance model)
				Description
					--- Gets the HitboxObject if it exists.
				Returns
					--- HitboxObject if found, else nil
					
		
		
		* HitboxObject:SetPoints(Instance BasePart | Bone, table vectorPoints, string group)
				Description
					--- Merges existing Hitbox points with new Vector3 values relative to a part/bone position. This part can be a descendent of your original Hitbox model or
						can be an entirely different instance that is not related to the hitbox (example: Have a weapon with attachments and you can then add in more vector3
						points without instancing new attachments, great for dynamic hitboxes)
				Arguments
					--- Instance BasePart | Bone: Sets the part/bone that these vectorPoints will move in relation to the part's origin using Vector3ToWorldSpace
					--- table vectorPoints: Table of vector3 values.
					--- string group: optional group parameter
					
		* HitboxObject:RemovePoints(Instance BasePart | Bone, table vectorPoints)
				Description
					--- Remove given Vector3 values provided the part was the same as the ones you set in SetPoints
				Arguments
					--- Instance BasePart | Bone: Sets the part that these vectorPoints will be removed from in relation to the part's origin using Vector3ToWorldSpace
					--- table vectorPoints: Table of vector3 values.
		
		* HitboxObject:LinkAttachments(Instance attachment1, Instance attachment2)
				Description
					--- Set two attachments to be in a link. The Raycast module will raycast between these two points.
				Arguments
					--- Instance attachment1/attachment2: Attachment objects
					
		* HitboxObject:UnlinkAttachments(Instance attachment1)
				Description
					--- Removes the link of an attachment. Only needs the primary attachment (argument 1 of LinkAttachments) to work. Will automatically sever the connection
						to the second attachment.
				Arguments
					--- Instance attachment1: Attachment object
				
		* HitboxObject:HitStart(seconds)
				Description
					--- Starts drawing the rays. Will only damage the target once. Call HitStop to reset the target pool so you can damage the same targets again.
						If HitStart hits a target(s), OnHit event will be called.
				Arguments
					--- number seconds: Optional numerical value, the hitbox will automatically turn off after this amount of time has elapsed
					
		* HitboxObject:HitStop()
				Description
					--- Stops drawing the rays and resets the target pool. Will do nothing if no rays are being drawn from the initialized model.

		* HitboxObject.OnHit:Connect(returns: Instance part, returns: Instance humanoid, returns: RaycastResults, returns: String group)
				Description
					--- If HitStart hits a fresh new target, OnHit returns information about the hit target
				Arguments
					--- Instance part: Returns the part that the rays hit first
					--- Instance humanoid: Returns the Humanoid object 
					--- RaycastResults RaycastResults: Returns information about the last raycast results
					--- String group: Returns information on the hitbox's group
					
		* HitboxObject.OnUpdate:Connect(returns: Vector3 position)
				Description
					--- This fires every frame, for every point, returning a Vector3 value of its last position in space. Do not use expensive operations in this function.
		

			[ PROPERTIES ]

		* HitboxObject.RaycastParams: RaycastParams
				Description
					--- Takes in a RaycastParams object

		* HitboxObject.Visualizer: boolean
				Description
					--- Turns on or off the debug rays for this hitbox

		* HitboxObject.DebugLog: boolean
				Description
					--- Turns on or off output writing for this hitbox

		* HitboxObject.DetectionMode: number [1 - 3]
				Description
					--- Defaults to 1. Refer to DetectionMode subsection below for more information

			
			[ DETECTION MODES ]

		* RaycastHitbox.DetectionMode.Default
				Description
					--- Checks if a humanoid exists when this hitbox touches a part. The hitbox will not return humanoids it has already hit for the duration
					--- the hitbox has been active.

		* RaycastHitbox.DetectionMode.PartMode
				Description
					--- OnHit will return every hit part (in respect to the hitbox's RaycastParams), regardless if it's ascendant has a humanoid or not.
					--- OnHit will no longer return a humanoid so you will have to check it. The hitbox will not return parts it has already hit for the
					--- duration the hitbox has been active.

		* RaycastHitbox.DetectionMode.Bypass
				Description
					--- PERFORMANCE MAY SUFFER IF THERE ARE A LOT OF PARTS. Use only if necessary.
					--- Similar to PartMode, the hitbox will return every hit part. Except, it will keep returning parts even if it has already hit them.
					--- Warning: If you have multiple raycast or attachment points, each raycast will also call OnHit. Allows you to create your own
					--- filter system.
		
____________________________________________________________________________________________________________________________________________________________________________

--]]

-- Show where the red lines are going. You can change their colour and width in VisualizerCache
local SHOW_DEBUG_RAY_LINES: boolean = true

-- Allow RaycastModule to write to the output
local SHOW_OUTPUT_MESSAGES: boolean = true

-- The tag name. Used for cleanup.
local DEFAULT_COLLECTION_TAG_NAME: string = "_RaycastHitboxV4Managed"

--- Initialize required modules
local CollectionService: CollectionService = game:GetService("CollectionService")


--!nocheck
--- Creates and manages the hitbox class
-- @author Swordphin123

-- Instance options
local DEFAULT_ATTACHMENT_INSTANCE: string = "DmgPoint"
local DEFAULT_GROUP_NAME_INSTANCE: string = "Group"

-- Debug / Test ray visual options
local DEFAULT_DEBUGGER_RAY_DURATION: number = 0.25

-- Debug Message options
local DEFAULT_DEBUG_LOGGER_PREFIX: string = "[ Raycast Hitbox V4 ]\n"
local DEFAULT_MISSING_ATTACHMENTS: string = "No attachments found in object: %s. Can be safely ignored if using SetPoints."
local DEFAULT_ATTACH_COUNT_NOTICE: string = "%s attachments found in object: %s."

-- Hitbox values
local MINIMUM_SECONDS_SCHEDULER: number = 1 / 60
local DEFAULT_SIMULATION_TYPE: RBXScriptSignal = game:GetService("RunService").Heartbeat

--- Variable definitions
local CollectionService: CollectionService = game:GetService("CollectionService")

--!strict
--- Cache LineHandleAdornments or create new ones if not in the cache
-- @author Swordphin123

-- Debug / Test ray visual options
local DEFAULT_DEBUGGER_RAY_COLOUR: Color3 = Color3.fromRGB(255, 0, 0)
local DEFAULT_DEBUGGER_RAY_WIDTH: number = 4
local DEFAULT_DEBUGGER_RAY_NAME: string = "_RaycastHitboxDebugLine"
local DEFAULT_FAR_AWAY_CFRAME: CFrame = CFrame.new(0, math.huge, 0)

local cache = {}
local VisualizerCache = cache
cache.__index = cache
cache.__type = "RaycastHitboxVisualizerCache"
cache._AdornmentInUse = {}
cache._AdornmentInReserve = {}

--- AdornmentData type
export type AdornmentData = {
	Adornment: LineHandleAdornment,
	LastUse: number
}

--- Internal function to create an AdornmentData type
--- Creates a LineHandleAdornment and a timer value
function cache:_CreateAdornment(): AdornmentData
	local line: LineHandleAdornment = Instance.new("LineHandleAdornment")
	line.Name = DEFAULT_DEBUGGER_RAY_NAME
	line.Color3 = DEFAULT_DEBUGGER_RAY_COLOUR
	line.Thickness = DEFAULT_DEBUGGER_RAY_WIDTH

	line.Length = 0
	line.CFrame = DEFAULT_FAR_AWAY_CFRAME

	line.Adornee = workspace.Terrain
	line.Parent = workspace.Terrain

	return {
		Adornment = line,
		LastUse = 0
	}
end

--- Gets an AdornmentData type. Creates one if there isn't one currently available.
function cache:GetAdornment(): AdornmentData?
	if #cache._AdornmentInReserve <= 0 then
		--- Create a new LineAdornmentHandle if none are in reserve
		local adornment: AdornmentData = cache:_CreateAdornment()
		table.insert(cache._AdornmentInReserve, adornment)
	end

	local adornment: AdornmentData? = table.remove(cache._AdornmentInReserve, 1)

	if adornment then
		adornment.Adornment.Visible = true
		adornment.LastUse = os.clock()
		table.insert(cache._AdornmentInUse, adornment)
	end

	return adornment
end

--- Returns an AdornmentData back into the cache.
-- @param AdornmentData
function cache:ReturnAdornment(adornment: AdornmentData)
	adornment.Adornment.Length = 0
	adornment.Adornment.Visible = false
	adornment.Adornment.CFrame = DEFAULT_FAR_AWAY_CFRAME
	table.insert(cache._AdornmentInReserve, adornment)
end

--- Clears the cache in reserve. Should only be used if you want to free up some memory.
--- If you end up turning on the visualizer again for this session, the cache will fill up again.
--- Does not clear adornments that are currently in use.
function cache:Clear()
	for i = #cache._AdornmentInReserve, 1, -1 do
		if cache._AdornmentInReserve[i].Adornment then
			cache._AdornmentInReserve[i].Adornment:Destroy()
		end

		table.remove(cache._AdornmentInReserve, i)
	end
end


local ActiveHitboxes: {[number]: any} = {}
local Hitbox = {}
local HitboxData = Hitbox
Hitbox.__index = Hitbox
Hitbox.__type = "RaycastHitbox"

Hitbox.CastModes = {
	LinkAttachments = 1,
	Attachment = 2,
	Vector3 = 3,
	Bone = 4,
}

--- Point type
type Point = {
	Group: string?,
	CastMode: number,
	LastPosition: Vector3?,
	WorldSpace: Vector3?,
	Instances: {[number]: Instance | Vector3}
}

-- AdornmentData type
type AdornmentData = VisualizerCache.AdornmentData

--- Activates the raycasts for the hitbox object.
--- The hitbox will automatically stop and restart if the hitbox was already casting.
-- @param optional number parameter to automatically turn off the hitbox after 'n' seconds
function Hitbox:HitStart(seconds: number?)
	if self.HitboxActive then
		self:HitStop()
	end

	if seconds then
		self.HitboxStopTime = os.clock() + math.max(MINIMUM_SECONDS_SCHEDULER, seconds)
	end

	self.HitboxActive = true
end

--- Disables the raycasts for the hitbox object, and clears all current hit targets.
--- Also automatically cancels any current time scheduling for the current hitbox.
function Hitbox:HitStop()
	self.HitboxActive = false
	self.HitboxStopTime = 0
	table.clear(self.HitboxHitList)
end

--- Queues the hitbox to be destroyed in the next frame
function Hitbox:Destroy()
	self.HitboxPendingRemoval = true

	if self.HitboxObject then
		CollectionService:RemoveTag(self.HitboxObject, self.Tag)
	end

	self:HitStop()
	self.OnHit:Destroy()
	self.OnUpdate:Destroy()
	self.HitboxRaycastPoints = nil
	self.HitboxObject = nil
end

--- Searches for attachments for the given instance (if applicable)
function Hitbox:Recalibrate()
	local descendants: {[number]: Instance} = self.HitboxObject:GetDescendants()
	local attachmentCount: number = 0

	--- Remove all previous attachments
	for i = #self.HitboxRaycastPoints, 1, -1 do
		if self.HitboxRaycastPoints[i].CastMode == Hitbox.CastModes.Attachment then
			table.remove(self.HitboxRaycastPoints, i)
		end
	end

	for _, attachment: any in ipairs(descendants) do
		if not attachment:IsA("Attachment") or attachment.Name ~= DEFAULT_ATTACHMENT_INSTANCE then
			continue
		end

		local group: string? = attachment:GetAttribute(DEFAULT_GROUP_NAME_INSTANCE)
		local point: Point = self:_CreatePoint(group, Hitbox.CastModes.Attachment, attachment.WorldPosition)

		table.insert(point.Instances, attachment)
		table.insert(self.HitboxRaycastPoints, point)

		attachmentCount += 1
	end

	if self.DebugLog then
		print(string.format("%s%s", DEFAULT_DEBUG_LOGGER_PREFIX,
			attachmentCount > 0 and string.format(DEFAULT_ATTACH_COUNT_NOTICE, attachmentCount, self.HitboxObject.Name) or
				string.format(DEFAULT_MISSING_ATTACHMENTS, self.HitboxObject.Name))
		)
	end
end

--- Creates a link between two attachments. The module will constantly raycast between these two attachments.
-- @param attachment1 Attachment object (can have a group attribute)
-- @param attachment2 Attachment object
function Hitbox:LinkAttachments(attachment1: Attachment, attachment2: Attachment)
	local group: string? = attachment1:GetAttribute(DEFAULT_GROUP_NAME_INSTANCE)
	local point: Point = self:_CreatePoint(group, Hitbox.CastModes.LinkAttachments)

	point.Instances[1] = attachment1
	point.Instances[2] = attachment2
	table.insert(self.HitboxRaycastPoints, point)
end

--- Removes the link of an attachment. Putting one of any of the two original attachments you used in LinkAttachment will automatically sever the other
-- @param attachment
function Hitbox:UnlinkAttachments(attachment: Attachment)
	for i = #self.HitboxRaycastPoints, 1, -1 do
		if #self.HitboxRaycastPoints[i].Instances >= 2 then
			if self.HitboxRaycastPoints[i].Instances[1] == attachment or self.HitboxRaycastPoints[i].Instances[2] == attachment then
				table.remove(self.HitboxRaycastPoints, i)
			end
		end
	end
end

--- Creates raycast points using only vector3 values.
-- @param object BasePart or Bone, the part you want the points to be locally offset from
-- @param table of vector3 values that are in local space relative to the basePart or bone
-- @param optional group string parameter that names the group these points belong to
function Hitbox:SetPoints(object: BasePart | Bone, vectorPoints: {[number]: Vector3}, group: string?)
	for _: number, vector: Vector3 in ipairs(vectorPoints) do
		local point: Point = self:_CreatePoint(group, Hitbox.CastModes[object:IsA("Bone") and "Bone" or "Vector3"])

		point.Instances[1] = object
		point.Instances[2] = vector
		table.insert(self.HitboxRaycastPoints, point)
	end
end

--- Removes raycast points using only vector3 values. Use the same vector3 table from SetPoints
-- @param object BasePart or Bone, the original instance you used for SetPoints
-- @param table of vector values that are in local space relative to the basePart
function Hitbox:RemovePoints(object: BasePart | Bone, vectorPoints: {[number]: Vector3})
	for i = #self.HitboxRaycastPoints, 1, -1 do
		local part = (self.HitboxRaycastPoints[i] :: Point).Instances[1]

		if part == object then
			local originalVector = (self.HitboxRaycastPoints[i] :: Point).Instances[2]

			for _: number, vector: Vector3 in ipairs(vectorPoints) do
				if vector == originalVector :: Vector3 then
					table.remove(self.HitboxRaycastPoints, i)
					break
				end
			end
		end
	end
end

--- Internal function that returns a point type
-- @param group string name
-- @param castMode numeric enum value
-- @param lastPosition Vector3 value
function Hitbox:_CreatePoint(group: string?, castMode: number, lastPosition: Vector3?): Point
	return {
		Group = group,
		CastMode = castMode,
		LastPosition = lastPosition,
		WorldSpace = nil,
		Instances = {},
	}
end

--- Internal function that finds an existing hitbox from a given instance
-- @param instance object
function Hitbox:_FindHitbox(object: any)
	for _: number, hitbox: any in ipairs(ActiveHitboxes) do
		if not hitbox.HitboxPendingRemoval and hitbox.HitboxObject == object then
			return hitbox
		end
	end
end

--- Runs for the very first time whenever a hitbox is created
--- Do not run this more than once, you may introduce memory leaks if you do so
function Hitbox:_Init()
	if not self.HitboxObject then return end

	local tagConnection: RBXScriptConnection

	local function onTagRemoved(instance: Instance)
		if instance == self.HitboxObject then
			tagConnection:Disconnect()
			self:Destroy()
		end
	end

	self:Recalibrate()
	table.insert(ActiveHitboxes, self)
	CollectionService:AddTag(self.HitboxObject, self.Tag)

	tagConnection = CollectionService:GetInstanceRemovedSignal(self.Tag):Connect(onTagRemoved)
end

local function Init()
	--- Reserve table sizing for solver tables
	local solversCache = {}
	
	--!strict
	--- Calculates ray origin and directions for vector-based raycast points
	-- @author Swordphin123

	local Vec3Solver = {}

	local EMPTY_VECTOR: Vector3 = Vector3.new()

	--- Solve direction and length of the ray by comparing current and last frame's positions
	-- @param point type
	function Vec3Solver:Solve(point: {[string]: any}): (Vector3, Vector3)
		--- Translate localized Vector3 positions to world space values
		local originPart: BasePart = point.Instances[1]
		local vector: Vector3 = point.Instances[2]
		local pointToWorldSpace: Vector3 = originPart.Position + originPart.CFrame:VectorToWorldSpace(vector)

		--- If LastPosition is nil (caused by if the hitbox was stopped previously), rewrite its value to the current point position
		if not point.LastPosition then
			point.LastPosition = pointToWorldSpace
		end

		local origin: Vector3 = point.LastPosition
		local direction: Vector3 = pointToWorldSpace - (point.LastPosition or EMPTY_VECTOR)

		point.WorldSpace = pointToWorldSpace

		return origin, direction
	end

	function Vec3Solver:UpdateToNextPosition(point: {[string]: any}): Vector3
		return point.WorldSpace
	end

	function Vec3Solver:Visualize(point: {[string]: any}): CFrame
		return CFrame.lookAt(point.WorldSpace, point.LastPosition)
	end
	
	--!strict
	--- Calculates ray origin and directions for attachment-based raycast points
	-- @author Swordphin123

	local LinkAtt = {}

	--- Solve direction and length of the ray by comparing both attachment1 and attachment2's positions
	-- @param point type
	function LinkAtt:Solve(point: {[string]: any}): (Vector3, Vector3)
		local origin: Vector3 = point.Instances[1].WorldPosition
		local direction: Vector3 = point.Instances[2].WorldPosition - point.Instances[1].WorldPosition

		return origin, direction
	end

	function LinkAtt:UpdateToNextPosition(point: {[string]: any}): Vector3
		return point.Instances[1].WorldPosition
	end

	function LinkAtt:Visualize(point: {[string]: any}): CFrame
		return CFrame.lookAt(point.Instances[1].WorldPosition, point.Instances[2].WorldPosition)
	end
	
	
	--!strict
	--- Calculates ray origin and directions for vector-based raycast points
	-- @author Swordphin123

	local BoneSolver = {}

	local EMPTY_VECTOR: Vector3 = Vector3.new()

	--- Solve direction and length of the ray by comparing current and last frame's positions
	-- @param point type
	function BoneSolver:Solve(point: {[string]: any}): (Vector3, Vector3)
		--- Translate localized bone positions to world space values
		local originBone: Bone = point.Instances[1]
		local vector: Vector3 = point.Instances[2]
		local worldCFrame: CFrame = originBone.TransformedWorldCFrame
		local pointToWorldSpace: Vector3 = worldCFrame.Position + worldCFrame:VectorToWorldSpace(vector)

		--- If LastPosition is nil (caused by if the hitbox was stopped previously), rewrite its value to the current point position
		if not point.LastPosition then
			point.LastPosition = pointToWorldSpace
		end

		local origin: Vector3 = point.LastPosition
		local direction: Vector3 = pointToWorldSpace - (point.LastPosition or EMPTY_VECTOR)

		point.WorldSpace = pointToWorldSpace

		return origin, direction
	end

	function BoneSolver:UpdateToNextPosition(point: {[string]: any}): Vector3
		return point.WorldSpace
	end

	function BoneSolver:Visualize(point: {[string]: any}): CFrame
		return CFrame.lookAt(point.WorldSpace, point.LastPosition)
	end

	
	--!strict
	--- Calculates ray origin and directions for attachment-based raycast points
	-- @author Swordphin123

	local Att = {}

	--- Solve direction and length of the ray by comparing current and last frame's positions
	-- @param point type
	function Att:Solve(point: {[string]: any}): (Vector3, Vector3)
		--- If LastPosition is nil (caused by if the hitbox was stopped previously), rewrite its value to the current point position
		if not point.LastPosition then
			point.LastPosition = point.Instances[1].WorldPosition
		end

		local origin: Vector3 = point.Instances[1].WorldPosition
		local direction: Vector3 = point.Instances[1].WorldPosition - point.LastPosition

		return origin, direction
	end

	function Att:UpdateToNextPosition(point: {[string]: any}): Vector3
		return point.Instances[1].WorldPosition
	end

	function Att:Visualize(point: {[string]: any}): CFrame
		return CFrame.lookAt(point.Instances[1].WorldPosition, point.LastPosition)
	end

	
	solversCache[Hitbox.CastModes.LinkAttachments] = LinkAtt
	solversCache[Hitbox.CastModes.Bone] = BoneSolver
	solversCache[Hitbox.CastModes.Attachment] = Att
	solversCache[Hitbox.CastModes.Vector3] = Vec3Solver
	
	
	DEFAULT_SIMULATION_TYPE:Connect(function(step: number)
		--- Iterate through all the hitboxes
		for i = #ActiveHitboxes, 1, -1 do
			--- Skip this hitbox if the hitbox will be garbage collected this frame
			if ActiveHitboxes[i].HitboxPendingRemoval then
				local hitbox: any = table.remove(ActiveHitboxes, i)
				table.clear(hitbox)
				setmetatable(hitbox, nil)
				continue
			end

			for _: number, point: Point in ipairs(ActiveHitboxes[i].HitboxRaycastPoints) do
				--- Reset this point if the hitbox is inactive
				if not ActiveHitboxes[i].HitboxActive then
					point.LastPosition = nil
					continue
				end

				--- Calculate rays
				local castMode: any = solversCache[point.CastMode]
				local origin: Vector3, direction: Vector3 = castMode:Solve(point)
				local raycastResult: RaycastResult = workspace:Raycast(origin, direction, ActiveHitboxes[i].RaycastParams)

				--- Draw debug rays
				if ActiveHitboxes[i].Visualizer then
					local adornmentData: AdornmentData? = VisualizerCache:GetAdornment()

					if adornmentData then
						local debugStartPosition: CFrame = castMode:Visualize(point)
						adornmentData.Adornment.Length = direction.Magnitude
						adornmentData.Adornment.CFrame = debugStartPosition
					end
				end

				--- Update the current point's position
				point.LastPosition = castMode:UpdateToNextPosition(point)

				--- If a ray detected a hit
				if raycastResult then
					local part: BasePart = raycastResult.Instance
					local model: Instance?
					local humanoid: Instance?
					local target: Instance?

					if ActiveHitboxes[i].DetectionMode == 1 then
						model = part:FindFirstAncestorOfClass("Model")
						if model then
							humanoid = model:FindFirstChildOfClass("Humanoid")
						end
						target = humanoid
					else
						target = part
					end

					--- Found a target. Fire the OnHit event
					if target then
						if ActiveHitboxes[i].DetectionMode <= 2 then
							if ActiveHitboxes[i].HitboxHitList[target] then
								continue
							else
								ActiveHitboxes[i].HitboxHitList[target] = true
							end
						end

						ActiveHitboxes[i].OnHit:Fire(part, humanoid, raycastResult, point.Group)
					end
				end

				--- Hitbox Time scheduler
				if ActiveHitboxes[i].HitboxStopTime > 0 then
					if ActiveHitboxes[i].HitboxStopTime <= os.clock() then
						ActiveHitboxes[i]:HitStop()
					end
				end

				--- OnUpdate event that fires every frame for every point
				ActiveHitboxes[i].OnUpdate:Fire(point.LastPosition)

				--- Update SignalType
				if ActiveHitboxes[i].OnUpdate._signalType ~= ActiveHitboxes[i].SignalType then
					ActiveHitboxes[i].OnUpdate._signalType = ActiveHitboxes[i].SignalType
					ActiveHitboxes[i].OnHit._signalType = ActiveHitboxes[i].SignalType
				end
			end
		end

		local adornmentsInUse: number = #VisualizerCache._AdornmentInUse

		--- Iterates through all the debug rays to see if they need to be cached or cleaned up
		if adornmentsInUse > 0 then
			for i = adornmentsInUse, 1, -1 do
				if (os.clock() - VisualizerCache._AdornmentInUse[i].LastUse) >= DEFAULT_DEBUGGER_RAY_DURATION then
					local adornment: AdornmentData? = table.remove(VisualizerCache._AdornmentInUse, i)

					if adornment then
						VisualizerCache:ReturnAdornment(adornment)
					end
				end
			end
		end
	end)
end

Init()


--------------------------------------------------------------------------------
--               Batched Yield-Safe Signal Implementation                     --
-- This is a Signal class which has effectively identical behavior to a       --
-- normal RBXScriptSignal, with the only difference being a couple extra      --
-- stack frames at the bottom of the stack trace when an error is thrown.     --
-- This implementation caches runner coroutines, so the ability to yield in   --
-- the signal handlers comes at minimal extra cost over a naive signal        --
-- implementation that either always or never spawns a thread.                --
--                                                                            --
-- API:                                                                       --
--   local Signal = require(THIS MODULE)                                      --
--   local sig = Signal.new()                                                 --
--   local connection = sig:Connect(function(arg1, arg2, ...) ... end)        --
--   sig:Fire(arg1, arg2, ...)                                                --
--   connection:Disconnect()                                                  --
--   sig:DisconnectAll()                                                      --
--   local arg1, arg2, ... = sig:Wait()                                       --
--                                                                            --
-- Licence:                                                                   --
--   Licenced under the MIT licence.                                          --
--                                                                            --
-- Authors:                                                                   --
--   stravant - July 31st, 2021 - Created the file.                           --
--   Swordphin123 - August 15th, 2021 - Minor edits for RaycastHitbox	      --
--------------------------------------------------------------------------------

-- The currently idle thread to run the next handler on
local freeRunnerThread = nil

-- Function which acquires the currently idle handler runner thread, runs the
-- function fn on it, and then releases the thread, returning it to being the
-- currently idle one.
-- If there was a currently idle runner thread already, that's okay, that old
-- one will just get thrown and eventually GCed.
local function acquireRunnerThreadAndCallEventHandler(fn, ...)
	local acquiredRunnerThread = freeRunnerThread
	freeRunnerThread = nil
	fn(...)
	-- The handler finished running, this runner thread is free again.
	freeRunnerThread = acquiredRunnerThread
end

-- Coroutine runner that we create coroutines of. The coroutine can be 
-- repeatedly resumed with functions to run followed by the argument to run
-- them with.
local function runEventHandlerInFreeThread(...)
	acquireRunnerThreadAndCallEventHandler(...)
	while true do
		acquireRunnerThreadAndCallEventHandler(coroutine.yield())
	end
end

-- Connection class
local Connection = {}
Connection.__index = Connection

function Connection.new(signal, fn)
	return setmetatable({
		_connected = true,
		_signal = signal,
		_fn = fn,
		_next = false,
	}, Connection)
end

function Connection:Disconnect()
	assert(self._connected, "Can't disconnect a connection twice.")
	self._connected = false

	-- Unhook the node, but DON'T clear it. That way any fire calls that are
	-- currently sitting on this node will be able to iterate forwards off of
	-- it, but any subsequent fire calls will not hit it, and it will be GCed
	-- when no more fire calls are sitting on it.
	if self._signal._handlerListHead == self then
		self._signal._handlerListHead = self._next
	else
		local prev = self._signal._handlerListHead
		while prev and prev._next ~= self do
			prev = prev._next
		end
		if prev then
			prev._next = self._next
		end
	end
end
Connection.Destroy = Connection.Disconnect

-- Make Connection strict
setmetatable(Connection, {
	__index = function(tb, key)
		error(("Attempt to get Connection::%s (not a valid member)"):format(tostring(key)), 2)
	end,
	__newindex = function(tb, key, value)
		error(("Attempt to set Connection::%s (not a valid member)"):format(tostring(key)), 2)
	end
})

-- Signal class
local Signal = {}
Signal.__index = Signal

function Signal.new(signal)
	return setmetatable({
		_handlerListHead = false,
		_signalType = signal
	}, Signal)
end

function Signal:Connect(fn)
	local connection = Connection.new(self, fn)

	if self._signalType == 1 and self._handlerListHead then
		connection._next = self._handlerListHead
		self._handlerListHead = connection
	else
		self._handlerListHead = connection
	end

	return connection
end

-- Disconnect all handlers. Since we use a linked list it suffices to clear the
-- reference to the head handler.
function Signal:Destroy()
	self._handlerListHead = false
end

-- Signal:Fire(...) implemented by running the handler functions on the
-- coRunnerThread, and any time the resulting thread yielded without returning
-- to us, that means that it yielded to the Roblox scheduler and has been taken
-- over by Roblox scheduling, meaning we have to make a new coroutine runner.
function Signal:Fire(...)
	local item = self._handlerListHead
	while item do
		if item._connected then
			if not freeRunnerThread then
				freeRunnerThread = coroutine.create(runEventHandlerInFreeThread)
			end
			task.spawn(freeRunnerThread, item._fn, ...)
		end
		item = item._next
	end
end

-- Implement Signal:Wait() in terms of a temporary connection using
-- a Signal:Connect() which disconnects itself.
function Signal:Wait()
	local waitingCoroutine = coroutine.running()
	local cn;
	cn = self:Connect(function(...)
		cn:Disconnect()
		task.spawn(waitingCoroutine, ...)
	end)
	return coroutine.yield()
end

-- Make signal strict
setmetatable(Signal, {
	__index = function(tb, key)
		error(("Attempt to get Signal::%s (not a valid member)"):format(tostring(key)), 2)
	end,
	__newindex = function(tb, key, value)
		error(("Attempt to set Signal::%s (not a valid member)"):format(tostring(key)), 2)
	end
})

local RaycastHitbox = {}
RaycastHitbox.__index = RaycastHitbox
RaycastHitbox.__type = "RaycastHitboxModule"

-- Detection mode enums
RaycastHitbox.DetectionMode = {
	Default = 1,
	PartMode = 2,
	Bypass = 3,
}

-- Signal Type enums
RaycastHitbox.SignalType = {
	Default = 1,
	Single = 2, --- Defaults to Single connections only for legacy purposes
}

-- Signal mode enums


--- Creates or finds a hitbox object. Returns an hitbox object
-- @param required object parameter that takes in either a part or a model
function RaycastHitbox.new(object: any?)
	local hitbox: any

	if object and CollectionService:HasTag(object, DEFAULT_COLLECTION_TAG_NAME) then
		hitbox = HitboxData:_FindHitbox(object)
	else
		hitbox = setmetatable({
			RaycastParams = nil,
			DetectionMode = RaycastHitbox.DetectionMode.Default,
			HitboxRaycastPoints = {},
			HitboxPendingRemoval = false,
			HitboxStopTime = 0,
			HitboxObject = object,
			HitboxHitList = {},
			HitboxActive = false,
			Visualizer = SHOW_DEBUG_RAY_LINES,
			DebugLog = SHOW_OUTPUT_MESSAGES,
			SignalType = RaycastHitbox.SignalType.Single,
			OnUpdate = Signal.new(RaycastHitbox.SignalType.Single),
			OnHit = Signal.new(RaycastHitbox.SignalType.Single),
			Tag = DEFAULT_COLLECTION_TAG_NAME,
		}, HitboxData)

		hitbox:_Init()
	end

	return hitbox
end

--- Finds a hitbox object if valid, else return nil
-- @param Object instance
function RaycastHitbox:GetHitbox(object: any?)
	if object then
		return HitboxData:_FindHitbox(object)
	end
end


-- Convenience method to add the raycast params inline
-- ENDUO
function Hitbox:SetRayParams(params: RaycastParams)
    self.RaycastParams = params
    return self
end


return RaycastHitbox