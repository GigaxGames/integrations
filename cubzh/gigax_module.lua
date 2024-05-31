local gigax = {}

local CUBZH_API_TOKEN =
	"H4gjL-e9kvLF??2pz6oh=kJL497cBnsyCrQFdVkFadUkLnIaEamroYHb91GywMXrbGeDdmTiHxi8EqmJduCKPrDnfqWsjGuF0JJCUTrasGcBfGx=tlJCjq5q8jhVHWL?krIE74GT9AJ7qqX8nZQgsDa!Unk8GWaqWcVYT-19C!tCo11DcLvrnJPEOPlSbH7dDcXmAMfMEf1ZwZ1v1C9?2/BjPDeiAVTRlLFilwRFmKz7k4H-kCQnDH-RrBk!ZHl7"
local API_URL = "https://gig.ax"

local TRIGGER_AREA_SIZE = Number3(60, 30, 60)

local headers = {
	["Content-Type"] = "application/json",
	["Authorization"] = CUBZH_API_TOKEN,
}

-- HELPERS
local _helpers = {}

_helpers.lookAt = function(obj, target)
	if not target then
		require("ease"):linear(obj, 0.1).Forward = obj.initialForward
		obj.Tick = nil
		return
	end
	obj.Tick = function(self, _)
		_helpers.lookAtHorizontal(self, target)
	end
end

_helpers.lookAtHorizontal = function(o1, o2)
	local n3_1 = Number3.Zero
	local n3_2 = Number3.Zero
	n3_1:Set(o1.Position.X, 0, o1.Position.Z)
	n3_2:Set(o2.Position.X, 0, o2.Position.Z)
	require("ease"):linear(o1, 0.1).Forward = n3_2 - n3_1
end

-- Function to calculate distance between two positions
_helpers.calculateDistance = function(_, pos1, pos2)
	local dx = pos1.X - pos2.X
	local dy = pos1.Y - pos2.Y
	local dz = pos1.Z - pos2.Z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

_helpers.findClosestLocation = function(_, position, locationData)
	if not locationData then
		return
	end
	local closestLocation = nil
	local smallestDistance = math.huge -- Large initial value

	for _, location in pairs(locationData) do
		local distance = _helpers:calculateDistance(
			position,
			Map:WorldToBlock(Number3(location.position.x, location.position.y, location.position.z))
		)
		if distance < smallestDistance then
			smallestDistance = distance
			closestLocation = location
		end
	end
	-- Closest location found, now send its ID to update the character's location
	return closestLocation
end

if IsClient then
	local simulation = {}

	local npcDataClientById = {}
	local waitingLinkNPCs = {}
	local skillCallbacks = {}

	local gigaxHttpClient = {}
	gigaxHttpClient.registerMainCharacter = function(_, engineId, locationId, callback)
		local body = JSON:Encode({
			name = Player.Username,
			physical_description = "A human playing the game",
			current_location_id = locationId,
			position = { x = 0, y = 0, z = 0 },
		})
		local apiUrl = API_URL .. "/api/character/company/main?engine_id=" .. engineId
		HTTP:Post(apiUrl, headers, body, function(response)
			if response.StatusCode ~= 200 then
				print("Error creating or fetching main character: " .. response.StatusCode)
				return
			end
			callback(response.Body)
		end)
	end

	gigaxHttpClient.stepMainCharacter = function(_, engineId, characterId, skill, content, npcName, npcId, callback)
		if not engineId then
			return
		end
		local stepUrl = API_URL .. "/api/character/"..characterId.."/step-no-ws?engine_id="..engineId
		local body = JSON:Encode({
			character_id = characterId,
			skill = skill,
			target_name = npcName,
			target = npcId,
			content = content,
		})
		HTTP:Post(stepUrl, headers, body, function(response)
			if response.StatusCode ~= 200 then
				print("Error stepping character: " .. response.StatusCode)
				return
			end
			callback(response.Body)
		end)
	end

	gigaxHttpClient.updateCharacterPosition = function(_, engineId, characterId, locationId, position, callback)
		local body = JSON:Encode({
			current_location_id = locationId,
			position = { x = position.X, y = position.Y, z = position.Z },
		})
		local apiUrl = API_URL.."/api/character/"..characterId.."?engine_id="..engineId
		HTTP:Post(apiUrl, headers, body, function(response)
			if response.StatusCode ~= 200 then
				print("Error updating character location: " .. response.StatusCode)
				return
			end
			if callback then
				callback(response.Body)
			end
		end)
	end

	local onEndData
	local prevAction
	local function npcResponse(actionData)
		local currentAction = string.lower(actionData.skill.name)
		if onEndData and skillCallbacks[prevAction].onEndCallback then
			skillCallbacks[prevAction].onEndCallback(gigax, onEndData, currentAction)
		end
		local callback = skillCallbacks[currentAction].callback
		prevAction = string.lower(actionData.skill.name)
		if not callback then return end
		onEndData = callback(gigax, actionData, simulation.config)
	end

	local function registerEngine(config)
		local apiUrl = API_URL .. "/api/engine/company/"

		simulation.locations = {}
		simulation.NPCs = {}
		simulation.config = config
		simulation.player = Player

		-- Prepare the data structure expected by the backend
		local engineData = {
			name = Player.UserID..":"..config.simulationName,
			description = config.simulationDescription,
			NPCs = {},
			locations = {},
			radius,
		}

		for _, npc in pairs(config.NPCs) do
			simulation.NPCs[npc.name] = {
				name = npc.name,
				physical_description = npc.physicalDescription,
				psychological_profile = npc.psychologicalProfile,
				initial_reflections = npc.initialReflections,
				current_location_name = npc.currentLocationName,
				skills = config.skills,
			}
			table.insert(engineData.NPCs, simulation.NPCs[npc.name])
		end

		for _, loc in ipairs(config.locations) do
			simulation.locations[loc.name] = {
				name = loc.name,
				position = { x = loc.position.X, y = loc.position.Y, z = loc.position.Z },
				description = loc.description,
			}
			table.insert(engineData.locations, simulation.locations[loc.name])
		end

		local body = JSON:Encode(engineData)
		HTTP:Post(apiUrl, headers, body, function(res)
			if res.StatusCode ~= 201 then
				print("Error updating engine: " .. res.StatusCode)
				return
			end
			-- Decode the response body to extract engine and location IDs
			local responseData = JSON:Decode(res.Body)

			-- Save the engine_id for future use
			simulation.engineId = responseData.engine.id

			-- Saving all the _ids inside locationData table:
			for _, loc in ipairs(responseData.locations) do
				simulation.locations[loc.name]._id = loc._id
			end

			-- same for characters:
			for _, npc in pairs(responseData.NPCs) do
				simulation.NPCs[npc.name]._id = npc._id
				simulation.NPCs[npc.name].position = Number3(npc.position.x, npc.position.y, npc.position.z)
			end

			gigaxHttpClient:registerMainCharacter(simulation.engineId, simulation.locations[config.startingLocationName]._id, function(body)
				simulation.character = JSON:Decode(body)
				for name, npc in pairs(waitingLinkNPCs) do
					npc._id = simulation.NPCs[name]._id
					npc.name = name
					npc.object.Position = simulation.NPCs[name].position
					npcDataClientById[npc._id] = npc
				end
				Timer(1, true, function()
					local position = Map:WorldToBlock(Player.Position)
					gigax:updateCharacterPosition(simulation, simulation.character._id, position)
				end)
			end)
		end)
	end

	findTargetNpc = function(player)
		if not simulation then return end

		local closerDist = 1000
		local closerNpc
		for _,npc in pairs(simulation.NPCs) do
			local dist = (npc.position - player.Position).Length
			if closerDist > dist then
				closerDist = dist
				closerNpc = npc
			end
		end
		if closerDist > 50 then return end -- max distance is 50
		return closerNpc
	end

	gigax.action = function(_, data)
		local npc = findTargetNpc(Player)
		if not npc then return end

		local content = data.content
		data.content = nil
		gigaxHttpClient:stepMainCharacter(simulation.engineId, simulation.character._id, data, content, npc.name, npc._id, function(body)
			local actions = JSON:Decode(body)
			for _, action in ipairs(actions) do
				npcResponse(action)
			end
		end)
	end

	gigax.getNpc = function(_, id)
		return npcDataClientById[id]
	end

	local skillOnAction = function(actionType, callback, onEndCallback)
		skillCallbacks[actionType] = {
			callback = callback,
			onEndCallback = onEndCallback
		}
	end

	local prevSyncPosition
	gigax.updateCharacterPosition = function(_, simulation, characterId, position)
		if not simulation then return end
		if position == prevSyncPosition then return end
		prevSyncPosition = position
		local closest = _helpers:findClosestLocation(position, simulation.locations)
		if not closest then
			print("can't update character position: no closest location found, id:", characterId, position)
			return
		end
		if not characterId then return end
		gigaxHttpClient:updateCharacterPosition(simulation.engineId, characterId, closest._id, position)
	end

	local function createNPC(name, currentPosition, rotation)
		-- Create the NPC's Object and Avatar
		local NPC = {}
		NPC.object = Object()
		World:AddChild(NPC.object)
		NPC.object.Position = currentPosition or Number3(0, 0, 0)
		NPC.object.Rotation = rotation or Rotation(0, 0, 0)
		NPC.object.Scale = 0.5
		NPC.object.Physics = PhysicsMode.Trigger
		NPC.object.CollisionBox = Box({
			-TRIGGER_AREA_SIZE.Width * 0.5,
			math.min(-TRIGGER_AREA_SIZE.Height, NPC.object.CollisionBox.Min.Y),
			-TRIGGER_AREA_SIZE.Depth * 0.5,
		}, {
			TRIGGER_AREA_SIZE.Width * 0.5,
			math.max(TRIGGER_AREA_SIZE.Height, NPC.object.CollisionBox.Max.Y),
			TRIGGER_AREA_SIZE.Depth * 0.5,
		})
		NPC.object.OnCollisionBegin = function(self, other)
			if other ~= Player then
				return
			end
			_helpers.lookAt(self.avatarContainer, other)
		end
		NPC.object.OnCollisionEnd = function(self, other)
			if other ~= Player then
				return
			end
			_helpers.lookAt(self.avatarContainer, nil)
		end

		local container = Object()
		container.Rotation = NPC.object.Rotation
		container.initialRotation = NPC.object.Rotation:Copy()
		container.initialForward = NPC.object.Forward:Copy()
		container:SetParent(NPC.object)
		container.Physics = PhysicsMode.Trigger
		NPC.object.avatarContainer = container

		NPC.avatar = require("avatar"):get(name)
		NPC.avatar:SetParent(NPC.object.avatarContainer)
		NPC.avatar.Rotation.Y = math.pi * 2

		NPC.name = name

		NPC.object.onIdle = function()
			local animations = NPC.avatar.Animations
			NPC.object.avatarContainer.LocalRotation = { 0, 0, 0 }
			if not animations or animations.Idle.IsPlaying then
				return
			end
			if animations.Walk.IsPlaying then
				animations.Walk:Stop()
			end
			animations.Idle:Play()
		end

		NPC.object.onMove = function()
			local animations = NPC.avatar.Animations
			NPC.object.avatarContainer.LocalRotation = { 0, 0, 0 }
			if not animations or animations.Walk.IsPlaying then
				return
			end
			if animations.Idle.IsPlaying then
				animations.Idle:Stop()
			end
			animations.Walk:Play()
		end

		waitingLinkNPCs[name] = NPC

		-- review this to update location and position
		Timer(1, true, function()
			if not simulation then
				return
			end
			local position = Map:WorldToBlock(NPC.object.Position)
			local prevPosition = NPC.object.prevSyncPosition
			if prevPosition == position then return end
			gigax:updateCharacterPosition(simulation, NPC._id, position)
			NPC.object.prevSyncPosition = position
		end)
		return NPC
	end

	gigax.setConfig = function(_, config)
		for _, elem in ipairs(config.skills) do
			skillOnAction(string.lower(elem.name), elem.callback, elem.onEndCallback)
			elem.callback = nil
			elem.onEndCallback = nil
		end
		for _, elem in ipairs(config.NPCs) do
			createNPC(elem.name, elem.position, elem.rotation)
		end
		registerEngine(config)
	end
end

return gigax
