
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
local YOUR_API_TOKEN = "H4gjL-e9kvLF??2pz6oh=kJL497cBnsyCrQFdVkFadUkLnIaEamroYHb91GywMXrbGeDdmTiHxi8EqmJduCKPrDnfqWsjGuF0JJCUTrasGcBfGx=tlJCjq5q8jhVHWL?krIE74GT9AJ7qqX8nZQgsDa!Unk8GWaqWcVYT-19C!tCo11DcLvrnJPEOPlSbH7dDcXmAMfMEf1ZwZ1v1C9?2/BjPDeiAVTRlLFilwRFmKz7k4H-kCQnDH-RrBk!ZHl7"
local API_URL = "https://0074-195-154-25-43.ngrok-free.app"

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

    dialog = require("dialog")
    dialog:setMaxWidth(400)

    avatar = require("avatar")
    -- Create an avatarId to avatar mapping
    avatarIdToAvatar = {
    }

    updateLocationTimer = nil
    character = nil
end

LocalEvent:Listen(LocalEvent.Name.OnPlayerJoin, function(p)
    print("Player joined")
end)

LocalEvent:Listen(LocalEvent.Name.Tick, function(dt)
	if _config == nil then
		return
	end
end)

-- jump function, triggered with Action1
-- (space bar on PC, button 1 on mobile)
Client.Action1 = function()
    if Player.IsOnGround then
        Player.Velocity.Y = 100
        sfx("hurtscream_1", {Position = Player.Position, Volume = 0.4})
    end

    -- Example location registration
    local loc1 = createLocation(
        "Medieval Inn",
        Number3(130, 23, 75),
        "An inn lost in the middle of the forest, where travelers can rest and eat."
    )
    local loc2 = createLocation(
        "Abandoned temple",
        Number3(303, 20, 263),
        "Lost deep inside the woods, this temple features a mysterious altar statue. Fresh fruits and offrands are scattered on the ground."
    )
    local loc3 = createLocation(
        "Lone grave in the woods",
        Number3(142, 20, 258),
        "Inside a small clearing in the forest lies a stone cross, marking the grave of a lost soul."
    )
    local loc4 = createLocation(
        "Rope bridge",
        Number3(26, 20, 301),
        "Near the edge of a cliff, a rope bridge connects the forest to the island. The bridge is old and fragile, but still usable."
    )
    local loc5 = createLocation(
        "Forest entrance",
        Number3(156, 20, 168),
        "The entrance to the forest is marked by a large stone arch. The path is wide and well maintained."
    )

    local NPC1 = createNPC("aduermael", "Tall, with green eyes", "Friendly and helpful", "Medieval Inn", Number3(130, 23, 75))
    local NPC2 = createNPC("soliton", "Short, with a big nose", "Grumpy and suspicious", "Abandoned temple", Number3(303, 20, 263))
    local NPC3 = createNPC("caillef", "Tall, with a big beard", "Wise and mysterious", "Lone grave in the woods", Number3(142, 20, 258))

    local e = Event()
    e.action = "testRegisterEngine"
    e:SendTo(Server)
end


function createNPC(avatarId, physicalDescription, psychologicalProfile, currentLocationName, currentPosition)
    -- Create the NPC's Object and Avatar
    local NPC = {}
    NPC.object = Object()
    World:AddChild(NPC.object)
    NPC.object.Position = currentPosition or Number3(0, 0, 0)
    print("Placing NPC at position: " .. currentPosition._x .. ", " .. currentPosition._y .. ", " .. currentPosition._z)
    NPC.object.Scale = 0.5
    NPC.object.Physics = PhysicsMode.Dynamic
    
    avatar = require("avatar")
    NPC.avatar = avatar:get(avatarId)
    print("Getting avatar for NPC: " .. avatarId)
    NPC.avatar:SetParent(NPC.object)
    avatarIdToAvatar[avatarId] = NPC.avatar

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

function createLocation(name, position, description)
    local e = Event()
    e.action = "registerLocation"
    e.name = name
    e.position = position
    e.description = description
    e:SendTo(Server)
end


-- Function to calculate distance between two positions
local function calculateDistance(pos1, pos2)
    local dx = pos1.X - pos2.x
    local dy = pos1.Y - pos2.y
    local dz = pos1.Z - pos2.z
    return math.sqrt(dx*dx + dy*dy + dz*dz)
end

function findClosestLocation(playerPosition, locationData)
    -- Assume `playerPosition` holds the current position of the player
    local closestLocation = nil
    local smallestDistance = math.huge -- Large initial value
    
    for _, location in pairs(locationData) do
        local distance = calculateDistance(playerPosition, location.position)
        if distance < smallestDistance then
            smallestDistance = distance
            closestLocation = location
        end
    end
    
    if closestLocation then
        -- Closest location found, now send its ID to update the character's location
        return closestLocation
    end
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
        end
    end
end


Client.DidReceiveEvent = function(e)
    if e.action == "displayDialog" then
        dialog:create(e.content, avatarIdToAvatar[e.avatarId])
    elseif e.action == "characterResponse" then
        -- Setup a new timer to delay the next update call
        characterId = e.character._id
        updateLocationTimer = Timer(0.5, true, function()
            local e = Event()
            e.action = "updateCharacterLocation"
            e.position = Player.Position
            e.characterId = characterId
            e:SendTo(Server)
        end)
        -- print("Character ID: " .. character._id)
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
    elseif e.action == "registerLocation" then
        registerLocation(e.name, e.position, e.description)
    elseif e.action == "testRegisterEngine" then
        print("Registering engine...")
        registerEngine(e.Sender)
    elseif e.action == "stepMainCharacter" then
        stepMainCharacter(character, engineId, npcData["aduermael"]._id, npcData["aduermael"].name, e.content)
    elseif e.action == "updateCharacterLocation" then
        closest = findClosestLocation(e.position, locationData)
        -- if closest._id is different from the current location, update the character's location
        if closest._id ~= character.current_location._id then
            updateCharacterLocation(engineId, e.characterId, closest._id)
        end
    else
        print("Unknown action received.")
    end
end

Server.Tick = function(dt)
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

function registerEngine(sender)
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

        
        registerMainCharacter(engineId, locationData["Medieval Inn"]._id, sender)
        -- print the location data as JSON
    end)
end

function registerMainCharacter(engineId, locationId, sender)
    -- Example character data, replace with actual data as needed
    local newCharacterData = {
        name = "oncheman",
        physical_description = "A human playing the game",
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
        local e = Event()
        e.action = "characterResponse"
        e.character = character
        e:SendTo(sender)
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
        -- Find the target character by id using the "target" field in the response:
        for _, action in ipairs(actions) do
            for _, npc in pairs(npcData) do
                if action.character_id == npc._id then
                    -- Perform the action on the target character
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

function updateCharacterLocation(engineId, characterId, locationId)
    local updateData = {
        -- Fill with necessary character update information
        current_location_id = locationId
    }
    
    local jsonData = JSON:Encode(updateData)
    local headers = {
        ["Content-Type"] = "application/json",
        ["Authorization"] = YOUR_API_TOKEN
    }
    
    -- Assuming `characterId` and `engineId` are available globally or passed appropriately
    local apiUrl = API_URL .. "/api/character/" .. characterId .. "?engine_id=" .. engineId
    
    HTTP:Post(apiUrl, headers, jsonData, function(response)
        if response.StatusCode ~= 200 then
            print("Error updating character location: " .. response.StatusCode)
        else
            character = JSON:Decode(response.Body)
        end
    end)
end