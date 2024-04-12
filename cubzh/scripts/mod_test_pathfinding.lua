
-- This is Cubzh's default world script. 
-- We'll provide more templates later on to cover specific use cases like FPS games, data storage, synchornized shapes, etc.
-- Cubzh dev team and devs from the community will be happy to help you on Discord if you have questions: discord.gg/cubzh 

Config = {
    -- using item as map
    Map = "buche.playground_heights",
    -- items that are going to be loaded before startup
    Items = {
        "jacksbertox.crate"
    }
}

local CRATE_START_POSITION = Number3(382, 290, 153)
local GUY_START_POSITION = Number3(37, 3, 36)
local OFFSET_Y = Number3(0, 1, 0)
local OFFSET_XZ = Number3(0.5, 0, 0.5)
local YOUR_API_TOKEN = "H4gjL-e9kvLF??2pz6oh=kJL497cBnsyCrQFdVkFadUkLnIaEamroYHb91GywMXrbGeDdmTiHxi8EqmJduCKPrDnfqWsjGuF0JJCUTrasGcBfGx=tlJCjq5q8jhVHWL?krIE74GT9AJ7qqX8nZQgsDa!Unk8GWaqWcVYT-19C!tCo11DcLvrnJPEOPlSbH7dDcXmAMfMEf1ZwZ1v1C9?2/BjPDeiAVTRlLFilwRFmKz7k4H-kCQnDH-RrBk!ZHl7"
local API_URL = "https://0074-195-154-25-43.ngrok-free.app"
local multi = require("multi")
local ease = require("ease")

-- Client.OnStart is the first function to be called when the world is launched, on each user's device.
Client.OnStart = function()
   
    -- Setting up the ambience (lights)
    -- other possible presets:
    -- - ambience.dawn
    -- - ambience.dusk
    -- - ambience.midnight
    -- The "ambience" module also accepts
    -- custom settings (light colors, angles, etc.)
    local ambience = require("ambience") 
    ambience:set(ambience.noon)

    -- The sfx module can be used to play spatialized sounds in one line calls.
    -- A list of available sounds can be found here: 
    -- https://docs.cu.bzh/guides/quick/adding-sounds#list-of-available-sounds
    sfx = require("sfx")
    -- There's only one AudioListener, but it can be placed wherever you want:
    Player.Head:AddChild(AudioListener)

    -- Requiring "multi" module is all you need to see other players in your game!
    -- (remove this line if you want to be solo)
    require("multi")

    -- This function drops the local player above the center of the map:
    dropPlayer = function()
        Player.Position = Number3(Map.Width * 0.5, Map.Height + 10, Map.Depth * 0.5) * Map.Scale
        Player.Rotation = { 0, 0, 0 }
        Player.Velocity = { 0, 0, 0 }
    end

    -- Add player to the World (root scene Object) and call dropPlayer().
    World:AddChild(Player)
    dropPlayer()

    -- A Shape is an object made out of cubes.
    -- Let's instantiate one with one of our imported items:
    crate = Shape(Items.jacksbertox.crate)
    World:AddChild(crate)
    crate.Physics = PhysicsMode.StaticPerBlock
    -- By default, the pivot is at the center of the bounding box, 
    -- but since want to place this one with ground positions, let's
    -- move the pivot to the bottom:
    crate.Pivot.Y = 0
    crate.Position = CRATE_START_POSITION
    crateOwner = nil

    dialog = require("dialog")
    dialog:setMaxWidth(400)

    avatar = require("avatar")
    -- Create an avatarId to avatar mapping
    avatarIdToAvatar = {
    }
end

LocalEvent:Listen(LocalEvent.Name.OnPlayerJoin, function(p)
    print("Player joined")
    -- _initPathfinding(p)
end)

LocalEvent:Listen(LocalEvent.Name.Tick, function(dt)
	if _config == nil then
		return
	end
	-- _cameraFollow(_config.camera, Player)
	-- _cameraHideBlockingObjects(_config.camera)
	-- _moveNoPhysics(dt)
end)

-- INIT FUNCTIONS
_initPathfinding = function(_, p)
	Client.DirectionalPad = nil
	Client.AnalogPad = nil
	Pointer.Drag = nil

	if not _config then
		_setConfig()
	end
    print("Initializing player")
	_initializePlayer(p, _config.camera)
	if not p == Player then
		return
	end
    print("Initializing map")
	_initializeMap(_config.map)
end

-- jump function, triggered with Action1
-- (space bar on PC, button 1 on mobile)
Client.Action1 = function()
    if Player.IsOnGround then
        Player.Velocity.Y = 100
        sfx("hurtscream_1", {Position = Player.Position, Volume = 0.4})
    end

    o = Object()
    o:SetParent(World)
    o.Position = GUY_START_POSITION + {0, 0, 3}
    o.Scale = 0.5
    o.Physics = PhysicsMode.Dynamic
    a = avatar:get("aduermael")
    a:SetParent(o)
    avatarIdToAvatar["aduermael"] = a

    local e = Event()
    e.action = "registerNPC"
    e.avatarId = "aduermael"
    e.physicalDescription = "Tall, with green eyes"
    e.psychologicalProfile = "Friendly and helpful"
    e.currentLocationName = "Medieval Inn"
    e:SendTo(Server)

    NPC1 = createNPC("aduermael", "Tall, with green eyes", "Friendly and helpful", "Medieval Inn")
    NPC2 = createNPC("soliton", "Short, with a big nose", "Grumpy and suspicious", "Abandoned temple")
    NPC3 = createNPC("caillef", "Tall, with a big beard", "Wise and mysterious", "Lone grave in the woods")

    local e = Event()
    e.action = "testRegisterEngine"
    e:SendTo(Server)
end


function createNPC(avatarId, physicalDescription, psychologicalProfile, currentLocationName)
    -- Create the NPC's Object and Avatar
    NPC = {}
    NPC.object = Object()
    NPC.object.SetParent(World)
    NPC.object.Position = GUY_START_POSITION + {0, 0, 3}
    NPC.object.Scale = 0.5
    NPC.object.Physics = PhysicsMode.Dynamic
    
    NPC.avatar = avatar:get("aduermael")
    NPC.avatar:SetParent(NPC.object)
    avatarIdToAvatar["aduermael"] = NPC.avatar

    -- Register it
    local e = Event()
    e.action = "registerNPC"
    e.avatarId = avatarId
    e.physicalDescription = physicalDescription
    e.psychologicalProfile = psychologicalProfile
    e.currentLocationName = currentLocationName
    e:SendTo(Server)
    return NPC
end


-- Client.Tick is executed up to 60 times per second on player's device.
Client.Tick = function(dt)
    -- Detect if player is falling and use dropPlayer() when it happens!
    if Player.Position.Y < -500 then
        dropPlayer()
        -- It's funnier with a message.
        Player:TextBubble("💀 Oops!", true)
    end
end

-- Triggered when posting message with chat input
Client.OnChat = function(payload)
    -- <0.0.52 : "payload" was a string value.
    -- 0.0.52+ : "payload" is a table, with a "message" key
    local msg = type(payload) == "string" and payload or payload.message

    Player:TextBubble(msg, 3, true)
    sfx("waterdrop_2", {Position = Player.Position, Pitch = 1.1 + math.random() * 0.5})

    local e = Event()
    e.action = "stepMainCharacter"
    e.content = msg
    e:SendTo(Server)

end

-- Pointer.Click is called following click/touch down & up events, 
-- without draging the pointer in between. 
-- Let's use this function to add a few interactions with the scene!
Pointer.Click = function(pointerEvent)

    -- Cast a ray from pointer event,
    -- do different things depending on what it hits.
    local impact = pointerEvent:CastRay()
    if impact ~= nil then
        if impact.Object == Player then
            -- clicked on local player -> display message + little jump
            Player:TextBubble("Easy, I'm ticklish! 😬", 1.0, true)
            sfx("waterdrop_2", {Position = Player.Position, Pitch = 1.1 + math.random() * 0.5})
            Player.Velocity.Y = 50

        elseif impact.Object == Map and impact.Block ~= nil then
            -- clicked on Map block -> display block info
            
            -- making an exception if player is holding the crate to place it
            if crateEquiped and crateOwner == Player.ID and impact.FaceTouched == Face.Top then
                -- The position of the impact can be computed from the origin of the ray
                -- (pointerEvent.Position here), its direction (pointerEvent.Direction),
                -- and the distance:
                local impactPosition = pointerEvent.Position + pointerEvent.Direction * impact.Distance
                
                Player:EquipRightHand(nil)
                World:AddChild(crate)
                crate.Physics = PhysicsMode.StaticPerBlock
                crate.Scale = 1
                crate.Pivot.Y = 0
                crate.Position = impactPosition
                crateEquiped = false

                -- send event to inform server and other players that
                -- crate as been placed. Of course this code is not
                -- needed if you turn off multiplayer.
                local e = Event()
                e.action = "place_crate"
                e.owner = Player.ID
                e.pos = crate.Position
                e:SendTo(Server, OtherPlayers)

                sfx("wood_impact_1", {Position = crate.Position})

                crateOwner = nil
                    
                return
            end
                
            local b = impact.Block
            local t = Text()
            t.Text = string.format("coords: %d,%d,%d\ncolor: %d,%d,%d",
                                b.Coords.X, b.Coords.Y, b.Coords.Z,
                                b.Color.R, b.Color.G, b.Color.B)
            t.FontSize = 44
            t.Type = TextType.Screen -- display text in screen space
            t.BackgroundColor = Color(0,0,0,0) -- transparent
            t.Color = Color(255,255,255)
            World:AddChild(t)

            local blockCenter = b.Coords + {0.5,0.5,0.5}
            -- convert block coordinates to world position:
            t.Position = impact.Object:BlockToWorld(blockCenter)

            -- Timer to request text removal in 1 second
            Timer(1.0, function()
                t:RemoveFromParent()
            end)

            _pathTo(pointerEvent, o)
            
        elseif not crateEquiped and impact.Object == crate then
            if impact.Distance < 80 then
         
                crate.Physics = PhysicsMode.Disabled
                Player:EquipRightHand(crate)
                crate.Scale = 0.5
                crateEquiped = true
                crateOwner = Player.ID
                
                -- inform server and other players
                -- that crate has been picked
                local e = Event()
                e.action = "picked_crate"
                e:SendTo(Server, OtherPlayers)

                sfx("wood_impact_5", {Position = crate.Position, Pitch = 1.2})

            else
                Player:TextBubble("I'm too far to grab it!", 1, true)
                sfx("waterdrop_2", {Position = Player.Position, Pitch = 1.1 + math.random() * 0.5})
            end
        end
    end
end


Client.DidReceiveEvent = function(e)
    if e.action == "displayDialog" then
        dialog:create(e.content, avatarIdToAvatar[e.avatarId])
    end
end


------------------------------------------------------------------------------------------------
-- Server Stuff ---------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------

-- Server --------------------------------------------------------------------------------------
Server.OnStart = function()
    -- Initialize tables to hold NPC and location data
    engineId = nil
    locationId = nil
    character = nil
    npcData = {}
    locationData = {}
end

Server.DidReceiveEvent = function(e)
    if e.action == "registerNPC" then
        registerNPC(e.avatarId, e.physicalDescription, e.psychologicalProfile, e.currentLocationName)
    elseif e.action == "testRegisterEngine" then
        -- Example location registration
        registerLocation(
            "Medieval Inn",
            Vector3(23,3,13),
            "An inn lost in the middle of the forest, where travelers can rest and eat."
        )
        registerLocation(
            "Abandoned temple",
            Vector3(60,3,57),
            "Lost deep inside the woods, this temple features a mysterious altar statue. Fresh fruits and offrands are scattered on the ground."
        )
        registerLocation(
            "Lone grave in the woods",
            Vector3(28,3,53),
            "Inside a small clearing in the forest lies a stone cross, marking the grave of a lost soul."
        )
        registerLocation(
            "Rope bridge",
            Vector3(4,3,63),
            "Near the edge of a cliff, a rope bridge connects the forest to the island. The bridge is old and fragile, but still usable."
        )
        registerLocation(
            "Forest entrance",
            Vector3(32,3,30),
            "The entrance to the forest is marked by a large stone arch. The path is wide and well maintained."
        )
        registerEngine()
    elseif e.action == "stepMainCharacter" then
        stepMainCharacter(character, engineId, npcData["aduermael"]._id, npcData["aduermael"].name, e.content)
    end
    -- if e.action == "interactWithNPC" then
    --     -- Assume e contains NPC identifier and the player's action
    --     local apiUrl = "https://yourbackend.com/api/simulation/step" -- Adjust to your actual endpoint
    --     local headers = {
    --         ["Content-Type"] = "application/json",
    --         ["Authorization"] = "Bearer YOUR_API_TOKEN"
    --     }

    --     local actionData = {
    --         npcId = e.npcId,
    --         action = e.actionType,
    --         playerId = e.Sender.ID
    --     }

    --     local body = JSON:Encode(actionData)

    --     HTTP:Post(apiUrl, headers, body, function(res)
    --         if res.StatusCode ~= 200 then
    --             print("Error stepping simulation: " .. res.StatusCode)
    --             return
    --         end
    --         local updates = JSON:Decode(res.Body)
    --         -- Handle the updates, such as moving NPCs, changing dialogue, etc.
    --         -- You might need to send events back to the client to reflect these updates
    --     end)
    -- end
end

Server.OnPlayerJoin = function(player)
end

------------------------------------------------------------------------------------------------
-- Gigax Stuff ---------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------

-- Function to create and register an NPC
function registerNPC(avatarId, physicalDescription, psychologicalProfile, currentLocationName)
    -- Add NPC to npcData table
    npcData[avatarId] = {
        name = avatarId,
        physical_description = physicalDescription,
        psychological_profile = psychologicalProfile,
        current_location_name = currentLocationName,
        skills = {
            {
                name = "say",
                description = "Say smthg out loud",
                parameter_types = {"character", "content"}
            },
            {
                name = "move",
                description = "Move to a new location",
                parameter_types = {"location"}
            }
        }
    }
end

-- Function to register a location
function registerLocation(name, position, description)
    locationData[name] = {
        position = {x = position._x, y = position._y, z = position._z},
        name = name,
        description = description
    }
end

function registerEngine()
    local apiUrl = API_URL .. "/api/engine/company/"
    print("Updating engine with NPC data...")
    local headers = {
        ["Content-Type"] = "application/json",
        ["Authorization"] = YOUR_API_TOKEN
    }

    -- Prepare the data structure expected by the backend
    local engineData = {
        name = "mod_test",
        NPCs = {},
        locations = {} -- Populate if you have dynamic location data similar to NPCs
    }

    for _, npc in pairs(npcData) do
        table.insert(engineData.NPCs, {
            name = npc.name,
            physical_description = npc.physical_description,
            psychological_profile = npc.psychological_profile,
            current_location_name = npc.current_location_name,
            skills = npc.skills
        })
    end

    -- Populate locations
    for _, loc in pairs(locationData) do
        table.insert(engineData.locations, {
            name = loc.name,
            position = loc.position,
            description = loc.description
        })
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
        engineId = responseData.engine.id
        
        -- Saving all the _ids inside locationData table:
        for _, loc in pairs(responseData.locations) do
            locationData[loc.name]._id = loc._id
        end

        -- same for characters:
        for _, npc in pairs(responseData.NPCs) do
            npcData[npc.name]._id = npc._id
        end

        
        character = registerMainCharacter(engineId, locationData["Village Entrance"]._id)
        -- print the location data as JSON
    end)
end

function registerMainCharacter(engineId, locationId)
    -- Example character data, replace with actual data as needed
    local newCharacterData = {
        name = "oncheman",
        physical_description = "Tall, with green eyes",
        current_location_id = locationId,
        position = {x = 0, y = 0, z = 0}
    }

    -- Serialize the character data to JSON
    local jsonData = JSON:Encode(newCharacterData)

    local headers = {
        ["Content-Type"] = "application/json",
        ["Authorization"] = YOUR_API_TOKEN
    }

    local apiUrl = API_URL .. "/api/character/company/main?engine_id=" .. engineId

    -- Make the HTTP POST request
    HTTP:Post(apiUrl, headers, jsonData, function(response)
        if response.StatusCode ~= 200 then
            print("Error creating or fetching main character: " .. response.StatusCode)
        end
        print("Main character created/fetched successfully.")
        character = JSON:Decode(response.Body)
    end)
end

function stepMainCharacter(character, engineId, targetId, targetName, content)
    
    -- Now, step the character
    local stepUrl = API_URL .. "/api/character/" .. character._id .. "/step-no-ws?engine_id=" .. engineId 
    local stepActionData = {
        character_id = character._id,  -- Use the character ID from the creation/fetch response
        action_type = "SAY",
        target = targetId,
        target_name = targetName,
        content = content
    }
    local stepJsonData = JSON:Encode(stepActionData)
    print("Stepping character with data: " .. stepJsonData)

    local headers = {
        ["Content-Type"] = "application/json",
        ["Authorization"] = YOUR_API_TOKEN
    }
    -- You might need to adjust headers or use the same if they include the needed Authorization
    HTTP:Post(stepUrl, headers, stepJsonData, function(stepResponse)
        if stepResponse.StatusCode ~= 200 then
            -- print("Error stepping character: " .. stepResponse.StatusCode)
            return
        end
        
        local actions = JSON:Decode(stepResponse.Body)
        print("Character stepped successfully.")
        -- Find the target character by id using the "target" field in the response:
        for _, action in ipairs(actions) do
            for _, npc in pairs(npcData) do
                if action.character_id == npc._id then
                    -- Perform the action on the target character
                    -- Process actions as needed
                    print("Target character: " .. npc.name)
                    local e = Event()
                    e.action = "displayDialog"
                    e.avatarId = npc.name
                    e.content = action.content
                    e:SendTo(Players)
                end
            end
        end
    end)
end


----------------------
--module "pathfinding"
----------------------
pathfinding = {}
local instance = {}
instance.camera = nil
instance.pfMap = nil
instance.pfPath = nil
instance.pfStep = nil
instance.cursorPath = {}
instance.cursors = {}
local defaultConfig = {
	zoomMin = 50,
	zoomMax = 150,
	zoomSpeed = 1,
	zoomDefault = 150,
	cameraOffset = Number3(0, 0, 80),
	cameraFocusY = 25,
	moveSpeed = 50,
	mapGroups = { 1 },
	playerGroups = { 2 },
	map = nil,
	camera = nil,
}

multi:onAction("showCursor", function(_, data)
	_showCursor(Players[data.id], data.pos)
end)


_setConfig = function(conf)
	config = require("config"):merge(defaultConfig, conf)
	if not config.map then
		config.map = Map
	end
	if not config.camera then
		config.camera = Camera
	end
end

_initializePlayer = function(p, c)
	if p == Player then
		p.walkFX = particles:newEmitter({
			life = function()
				return 0.3
			end,
			velocity = function()
				local v = Number3(5 + math.random() * 5, 5, 0)
				v:Rotate(0, math.random() * math.pi * 2, 0)
				return v
			end,
			color = function()
				return Color(255, 255, 255, 128)
			end,
			acceleration = function()
				return -Config.ConstantAcceleration
			end,
			collidesWithGroups = function()
				return { 1 }
			end,
		})
		p.walkFX:SetParent(p)
		p.walkFX.LocalPosition = { 0, 0, 0 }
	end
	-- _cursorCreate(p)
end


_initializeMap = function()
	instance.pfMap = pathfinding.createPathfindingMap()
end

-- Add defaultConfig, setConfig...
pathfinding.createPathfindingMap = function(config) -- Takes the map as argument
	local defaultPathfindingConfig = {
		map = Map,
		pathHeight = 3,
		pathLevel = 1,
		obstacleGroups = { 3 },
	}

	_config = require("config"):merge(defaultPathfindingConfig, config)

	local map2d = {} --create a 2D map to store which blocks can be walked on with a height map
	local box = Box({ 0, 0, 0 }, _config.map.Scale) --create a box the size of a block
	local dist = _config.map.Scale.Y * _config.pathHeight -- check for ~3 blocks up
	local dir = Number3.Up -- checking up
	for x = 0, _config.map.Width do
		map2d[x] = {}
		for z = 0, _config.map.Depth do
			local h = _config.pathLevel -- default height is the path level
			for y = 0, _config.map.Height do
				if _config.map:GetBlock(x, y, z) then
					h = y + 1
				end -- adjust height by checking all blocks on the column to
			end
			box.Min = { x, h, z } * _config.map.Scale
			box.Max = box.Min + _config.map.Scale
			local data = h -- by default, store the height for the pathfinder
			local impact = box:Cast(dir, dist, _config.obstacleGroups) -- check object above the retained height
			if impact.Object ~= nil then
				data = impact.Object
			end -- if any, store the object for further use
			map2d[x][z] = data
		end
	end
	return map2d
end

pathfinding.findPath = function(origin, destination, map)
	local kCount = 500
	local diagonalsAllowed = true
	local kClimb = 1

	local directNeighbors = {
		{ x = -1, z = 0 },
		{ x = 0, z = 1 },
		{ x = 1, z = 0 },
		{ x = 0, z = -1 },
	}
	local diagonalNeighbours = {
		{ x = -1, z = 0 },
		{ x = 0, z = 1 },
		{ x = 1, z = 0 },
		{ x = 0, z = -1 },
		{ x = -1, z = -1 },
		{ x = 1, z = -1 },
		{ x = 1, z = 1 },
		{ x = -1, z = 1 },
	}

	local createNode = function(x, y, z, parent)
		local node = {}
		node.x, node.y, node.z, node.parent = x, y, z, parent
		return node
	end

	local heuristic = function(x1, x2, z1, z2, y1, y2)
		local dx = x1 - x2
		local dz = z1 - z2
		local dy = y1 - y2
		local h = dx * dx + dz * dz + dy * dy
		return h
	end

	local elapsed = function(parentNode)
		return parentNode.g + 1
	end

	local calculateScores = function(node, endNode)
		node.g = node.parent and elapsed(node.parent) or 0
		node.h = heuristic(node.x, endNode.x, node.z, endNode.z, node.y, endNode.y)
		node.f = node.g + node.h
	end

	local listContains = function(list, node)
		for _, v in ipairs(list) do
			if v.x == node.x and v.y == node.y and v.z == node.z then
				return v
			end
		end
		return false
	end

	local getChildren = function(node, map)
		local children = {}
		local neighbors = diagonalsAllowed and diagonalNeighbours or directNeighbors
		local parentHeight = map[node.x][node.z]

		for _, neighbor in ipairs(neighbors) do
			local x = node.x + neighbor.x
			local z = node.z + neighbor.z
			local y = map[x][z]
			if type(y) == "integer" and math.abs(y - parentHeight) <= kClimb then
				table.insert(children, { x = x, y = y, z = z })
			end
		end
		return children
	end

	-- Init lists to run the nodes & a count as protection for while
	local openList = {}
	local closedList = {}
	local count = 0
	-- Setup startNode and endNode
	local endNode = createNode(destination.X, destination.Y, destination.Z, nil)
	local startNode = createNode(origin.X, origin.Y, origin.Z, nil)
	-- Calculate starting node score
	calculateScores(startNode, endNode)
	-- Insert the startNode as first node to examine
	table.insert(openList, startNode)
	-- While there are nodes to examine and the count is under kCount (and the function did not return)
	while #openList > 0 and count < kCount do
		count = count + 1
		-- Sort openList with ascending f
		table.sort(openList, function(a, b)
			return a.f > b.f
		end)
		-- Examine the last node
		local currentNode = table.remove(openList)
		table.insert(closedList, currentNode)
		if listContains(closedList, endNode) then
			local path = {}
			local current = currentNode
			while current ~= nil do
				table.insert(path, current)
				current = current.parent
			end
			return path
		end
		-- Generate children based on map and test function
		local children = getChildren(currentNode, map)
		for _, child in ipairs(children) do
			-- Create child node
			local childNode = createNode(child.x, child.y, child.z, currentNode)
			-- Check if it's already been examined
			if not listContains(closedList, childNode) then
				-- Check if it's already planned to be examined with a bigger f (meaning further away)
				if not listContains(openList, childNode) then -- or self.listContains(openList, childNode).f > childNode.f then
					calculateScores(childNode, endNode)
					table.insert(openList, childNode)
				end
			end
		end
	end
    print("No path found in " .. count .. " iterations")
	return false
end



_pathTo = function(pointerEvent, protagonist)
	local impact = pointerEvent:CastRay(config.mapGroups)
	if impact.Block == nil then
		return
	end

	local origin = Map:WorldToBlock(protagonist.Position)
	origin = Number3(math.floor(origin.X), math.floor(origin.Y), math.floor(origin.Z))
	local destination = impact.Block.Position / Map.Scale + OFFSET_Y
	local path = pathfinding.findPath(origin, destination, instance.pfMap)
	if not path then
        print("No path found")
		return
	end
    print("Path found")

	instance.pfPath = path
	instance.pfStep = #path - 1 --skipping the first block, which we're standing on

	destination = impact.Block.Position + (OFFSET_XZ + OFFSET_Y) * Map.Scale
	-- _showCursor(Player, destination)
	_showPath(instance.pfPath)
	_followPath(protagonist, instance.pfPath, instance.pfStep)
end

_showCursor = function(p, pos)
	if p == Player then
		multi:action("showCursor", { id = Player.ID, pos = pos })
	end
	_cursorSet(instance.cursors[p.ID], pos)
end

_followPath = function(p, path, idx)
	if not path[idx] then
        print("No path index found")
		return
	end
	if instance.cursorPath[idx + 1] then
		instance.cursorPath[idx + 1]:RemoveFromParent()
	end
	p.destination = (Number3(path[idx].x, path[idx].y, path[idx].z) + OFFSET_XZ) * Map.Scale
	p.Forward = { p.destination.X - p.Position.X, 0, p.destination.Z - p.Position.Z } -- just to know where to face
end

_cursorCreate = function(p)
	ease = require("ease")
	Object:Load("aduermael.selector", function(o)
		o:SetParent(World)
		o.Physics = PhysicsMode.Trigger
		o.CollisionGroups = nil
		o.CollidesWithGroups = config.playerGroups
		o.Scale = 0

		o.Tick = function(self, dt)
			self:RotateLocal(0, dt, 0)
		end

		o.OnCollisionBegin = function(self, _)
			ease:cancel(self)
			ease:outQuad(self, 0.5).Scale = { 0, 0, 0 }
		end

		if p ~= Player then
			o.PrivateDrawMode = 1
		end

        print("Player ID: " .. p.ID)
		instance.cursors[p.ID] = o
	end)
end

_cursorSet = function(cursor, pos)
	ease:cancel(cursor)
	-- cursor.Position = pos
	ease:outQuad(cursor, 0.5).Scale = CURSOR_SCALE
end

_showPath = function(path)
	local createPath = function(v)
		local s = MutableShape()
		s:AddBlock(Color.White, 0, 0, 0)
		s.Pivot = { 0.5, 0.5, 0.5 }
		s.Physics = PhysicsMode.Trigger
		s.CollidesWithGroups = { 2 }
		s.CollisionGroups = {}
		s.OnCollisionBegin = function(self, _)
			self:RemoveFromParent()
		end
		s:SetParent(World)
		s.Position = (Number3(v.x, v.y, v.z) + OFFSET_XZ) * Map.Scale

		return s
	end

	for _, v in pairs(instance.cursorPath) do
		v:RemoveFromParent()
	end
	instance.cursorPath = {}

	for _, v in pairs(path) do
		local c = createPath(v)
		table.insert(instance.cursorPath, c)
	end
end

_moveNoPhysics = function(dt)
	if Player.Physics then
		Player.Physics = PhysicsMode.Trigger
	end
	if not instance.pfPath then
		return
	end

	local dest = Number3(Player.destination.X, 0, Player.destination.Z)
	local pos = Number3(Player.Position.X, 0, Player.Position.Z)
	local test = math.sqrt(2)
	if (dest - pos).Length < test then --checking on a 2D plane only
		Player.Position = Player.destination
		instance.pfStep = instance.pfStep - 1
		if instance.pfPath[instance.pfStep] ~= nil then
			_followPath(Player, instance.pfPath, instance.pfStep)
		else
			if Player.Animations.Idle.IsPlaying then
				return
			end
			if Player.Animations.Walk.IsPlaying then
				Player.Animations.Walk:Stop()
			end
			Player.Animations.Idle:Play()
		end
	else
		_followPath(Player, instance.pfPath, instance.pfStep)
		Player.moveDir = (Player.destination - Player.Position):Normalize()
		Player.Position = Player.Position + Player.moveDir * config.moveSpeed * dt
		local r = math.random()
		if Player.walkFX and r > 0.8 then
			Player.walkFX:spawn(1)
		end
		if Player.Animations.Walk.IsPlaying then
			return
		end
		if Player.Animations.Idle.IsPlaying then
			Player.Animations.Idle:Stop()
		end
		Player.Animations.Walk:Play()
	end
end
