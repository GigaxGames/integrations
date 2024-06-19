Config = {
    Items = {
        -- the same as opponentsList
        "kooow.white_yeti",
        "kooow.small_boar",
        "kooow.ribberhead_dino",
        "kooow.purple_demon",
        "kooow.lion",
        "kooow.brown_bear",
        "kooow.pinky_demon",
        "kooow.purple_bat",
        "kooow.beagle_dog",
        "kooow.lava_golem",
        "kooow.grey_blue_robot",
        "kooow.snowman_with_broom",
        "kooow.gorilla",
        "kooow.young_piggy",
        "kooow.blocky_giant",
        "kooow.grey_flying_dragon",
        "kooow.cactus_creature",
        "kooow.cow",
        -- becouse i cannot get name from Items
        "claire.torch",
        "voxels.gate",
        "petroglyph.hp_bar",
        "petroglyph.block_red",
        "petroglyph.block_green",
        "tantris.craft_item",
        "tantris.craft_button",
        "xavier.win",
    }
}

local opponentsList = {
    "kooow.white_yeti",
    "kooow.small_boar",
    "kooow.ribberhead_dino",
    "kooow.purple_demon",
    "kooow.lion",
    "kooow.brown_bear",
    "kooow.pinky_demon",
    "kooow.purple_bat",
    "kooow.beagle_dog",
    "kooow.lava_golem",
    "kooow.grey_blue_robot",
    "kooow.snowman_with_broom",
    "kooow.gorilla",
    "kooow.young_piggy",
    "kooow.blocky_giant",
    "kooow.grey_flying_dragon",
    "kooow.cactus_creature",
    "kooow.cow",
}

-- becouse i cannot use https://docs.cu.bzh/reference/items - local s = Shape(Items[ "aduermael.pumpkin" ])
local randomOpponent = {}
local miniOpponents = {}
local miniHeight = 40
local miniWidth = 40

-- DEBUG
local DEBUG = false

-- Corridor stuff
local NUMBER_OF_CORRIDORS = #opponentsList
local CORRIDOR_LENGTH = 150
local WALL_HEIGHT = 40
local TORCH_SPACING = 40
local corridors = {}

-- Door stuff
local PADDING = 8 -- used for UI elements
local doors = {}

-- HP bars settings
hpBars = {}  -- may be we can use only 2 parameter player and opponent
playerMaxHP = 100
playerHPDuration = .5 -- update animation in seconds
playerHPNegativeShake = .3
playerHPPositiveBump = .6
damageToApply = nil

-- Misc
local BROWN = Color(139, 69, 19)
local POINTER_OFFSET = 20
local GENERATED_ITEM_COLLISION_GROUP = 5
faceNormals = {
    [Face.Back] = Number3(0, 0, -1), [Face.Bottom] = Number3(0, -1, 0), [Face.Front] = Number3(0, 0, 1),
    [Face.Left] = Number3(-1, 0, 0), [Face.Right] = Number3(1, 0, 0), [Face.Top] = Number3(0, 1, 0)
}

Client.OnStart = function()
    -- Add player to game
    World:AddChild(Player, true)

    -- Initialize the corridors and gates
    makeMap()

    -- Set up the UI
    ease = require "ease"
    ui = require "uikit"
    sfx = require "sfx"
    controls = require "controls"
    controls:setButtonIcon("action1", "⬆️")
    hierarchyActions = require "hierarchyactions"

    -- ui : score, opponent.name, miniOpponent
    uiScore = ui:createText("", Color.White)
    uiScore.pos.X = (Screen.Width - Screen.SafeArea.Right - uiScore.Width - PADDING) / 2
    uiScore.pos.Y = Screen.Height - Screen.SafeArea.Top - uiScore.Height - PADDING

    uiOpponent = ui:createText("", Color.White)
    uiOpponent.pos.X = 0
    uiOpponent.pos.Y = Screen.SafeArea.Top + uiOpponent.Height + PADDING

    if (Screen.Width / NUMBER_OF_CORRIDORS < miniWidth) then
        miniWidth = Screen.Width / NUMBER_OF_CORRIDORS
    end
    local node = ui:createNode()
    for i = 1, NUMBER_OF_CORRIDORS, 1 do
        mOp = ui:createShape(Shape(Items[i]))
        mOp.Height = miniHeight
        mOp.Width = miniWidth
        mOp.pos.X = (i - 1) * miniWidth
        mOp:setParent(node)
        table.insert(miniOpponents, mOp)
    end

    -- restartButton = ui:Button("Restart!")
    -- restartButton.OnRelease = initGame
    initGame()
end

function initGame()
    paused = false

    -- Game variable init start
    level = 0
    generatedImage = nil
    gens = {}

    uiScore.Text = "Level: " .. level

    -- HP bars array init
    for i = 1, NUMBER_OF_CORRIDORS + 1, 1 do
        hpBars[i] = {}
    end

    -- Start Information
    showInstructions()
    showWelcomeHint()

    -- bad idea, but i cannot add opponentList to Items and cannot mix or fint element of opponentList in Items....
    createRandomSpawnList()
    opponent = spawnRandomOpponent()

    -- update door
    closeAllDoor()

    dropPlayer(Player)
    Player.healthIndex = 0
    Player.name = "player"
    attachHPBar(Player)

    for i = 1, NUMBER_OF_CORRIDORS, 1 do
        miniOpponents[i]:show()
    end

    -- Player.IsHidden = false
    -- Pointer:Hide()
    -- UI.Crosshair = true
end

function endGame(action)
    paused = true
    -- Player.IsHidden = true
    -- Pointer:Show()
    -- UI.Crosshair = false

    -- restartButton:Add(Anchor.HCenter, Anchor.VCenter)

    initGame()
end

Pointer.Click = function(pointerEvent)
    hideWelcomeHint()
    hideInstructions()
    showMenu(pointerEvent)
end

Client.OnPlayerJoin = function(p)
    if p == Player then
        return
    end
    dropPlayer(p)
end

Client.Tick = function(dt)
    if paused then
        return
    end
    -- Detect if player is falling,
    -- drop it above the map when it happens.
    if Player.Position.Y < -500 then
        dropPlayer(Player)
        Player:TextBubble("💀 Oops!")
    end
    updateHPBars(dt)
    launchToolOnOpponent(dt)
end

function dropPlayer(p)
    World:AddChild(p)
    p.Position = Number3(corridors[1].Position.X + 10, 10, corridors[1].Position.Z + 20)
    -- Rotate player 90 degres to the right to face the corridor
    p.Rotation = { 0, math.pi / 2, 0 }
    p.Velocity = { 0, 0, 0 }
end

function cancelMenu()
    --     hideMenu()
    --     showInstructions()
end

-- Function to create and set up the map
function closeAllDoor()
    for i = 1, NUMBER_OF_CORRIDORS do
        if doors[i].closed == false then
            doors[i].closed = true
            doors[i].Rotation = { 0, doors[i].rotClosed, 0 }
        end
    end
end

function makeMap()
    for i = 1, NUMBER_OF_CORRIDORS do
        corridors[i] = makeCorridor((i - 1) * CORRIDOR_LENGTH, i)
    end

    winTextSet(doors[NUMBER_OF_CORRIDORS].Position.X,
            doors[NUMBER_OF_CORRIDORS].Position.Y / 2,
            doors[NUMBER_OF_CORRIDORS].Position.Z / 2,
            2, 0, math.pi / 2, 0)
end

function winTextSet(x, y, z, scale, x_rot, y_rot, z_rot)
    wintext = Shape(Items.xavier.win)
    wintext.Position = { x, y, z }
    wintext.Rotation = { x_rot, y_rot, z_rot }
    wintext.Scale = scale
    wintext.CollisionGroups = { GENERATED_ITEM_COLLISION_GROUP }
    corridors[1]:AddChild(wintext)
end

function createDoorAtEndOfCorridor(offset, ix)
    local door = Shape(Items.voxels.gate)
    door.Position = Number3(offset + CORRIDOR_LENGTH, door.Height / 2, door.Width)
    door.Rotation = Number3(0, math.pi / 2, 0)  -- Adjusted to face the corridor
    door.Pivot = { 0, door.Height * 0.5, door.Depth * 0.5 }
    door.isDoor = true
    door.number = ix -- If you have more doors, increment this number for each
    door.closed = true
    door.rotClosed = math.pi / 2  -- The rotation when the door is closed
    doors[door.number] = door
    World:AddChild(door) -- for what? if we attach it to corridor
    return door
end

function makeCorridor(offset, ix)
    local corridor = Object()
    corridor.CollisionGroups = { GENERATED_ITEM_COLLISION_GROUP }
    World:AddChild(corridor)

    -- Add a door at the end of the corridor
    doors[ix] = createDoorAtEndOfCorridor(offset, ix)
    corridor:AddChild(doors[ix])

    local CORRIDOR_WIDTH = doors[ix].Width
    -- Create floor
    local floor = MutableShape()
    for x = offset, offset + CORRIDOR_LENGTH - 1 do
        for z = 1, CORRIDOR_WIDTH - 2 do
            -- Subtracting 2 since we're building walls on both sides
            floor:AddBlock(BROWN, x, 0, z)
        end
    end
    floor.CollisionGroups = { GENERATED_ITEM_COLLISION_GROUP }
    corridor:AddChild(floor)

    -- Create walls
    local leftWall = MutableShape()
    local rightWall = MutableShape()
    for x = offset, offset + CORRIDOR_LENGTH - 1 do
        for y = 1, WALL_HEIGHT do
            -- Left wall
            leftWall:AddBlock(BROWN, x, y, 0)
            -- Right wall
            rightWall:AddBlock(BROWN, x, y, CORRIDOR_WIDTH - 1)
        end
    end
    leftWall.CollisionGroups = { GENERATED_ITEM_COLLISION_GROUP }
    rightWall.CollisionGroups = { GENERATED_ITEM_COLLISION_GROUP }
    corridor:AddChild(leftWall)
    corridor:AddChild(rightWall)

    -- Add torches alongside the walls, spaced evenly
    for x = offset, offset + CORRIDOR_LENGTH - 1, TORCH_SPACING do
        -- Left wall torches
        local leftTorch = addTorch(x, 10, 4) -- Position adjusted for the left wall
        -- Right wall torches
        local rightTorch = addTorch(x, 10, CORRIDOR_WIDTH - 5) -- Position adjusted for the right wall
        corridor:AddChild(leftTorch)
        corridor:AddChild(rightTorch)
    end

    -- Add the "Craft Button" sign on the Left wall
    local infoPanel = Shape(Items.tantris.craft_item)
    infoPanel.Position = Number3(offset + 15, 15, CORRIDOR_WIDTH - 1) -- Position adjusted for scale
    -- Scale it down to 1/2 size
    infoPanel.Scale = 0.5
    corridor:AddChild(infoPanel)

    local craftButton = Shape(Items.tantris.craft_button)
    craftButton.Position = Number3(offset + 27, 9, CORRIDOR_WIDTH - 2) -- Position adjusted for scale
    craftButton.isCraftButton = true
    -- Add it to the collision group
    craftButton.CollisionGroups = { GENERATED_ITEM_COLLISION_GROUP }
    corridor:AddChild(craftButton)

    return corridor
end

function addTorch(x, y, z)
    local torch = Shape(Items.claire.torch)
    torch.Position = Number3(x, y, z) -- Position adjusted for scale
    return torch
end

-- door stuff
function openDoor(doorNumber)
    local door = doors[doorNumber]
    if door and door.isDoor and door.closed then
        doorAction(door, "open")
    end
end

-- Function to perform actions on doors
function doorAction(object, action)
    if action == "toggle" then
        object.closed = not object.closed
    elseif action == "close" then
        object.closed = true
    elseif action == "open" then
        object.closed = false
    end

    -- Play sound effects based on the action
    if object.closed then
        sfx("doorclose_1", object.Position, 0.5)
    else
        sfx("dooropen_1", object.Position, 0.5)
    end

    -- Set physics to trigger to allow for interaction, but not immediately solid
    object.Physics = PhysicsMode.Trigger
    object.colliders = 0

    -- Set the door's rotation based on whether it's open or closed
    if object.closed then
        object.Rotation = { 0, object.rotClosed, 0 }
    else
        object.Rotation = { 0, object.rotClosed + math.pi * 0.5, 0 }
    end
end

-- "Craft Menu" (Just a text input UI for now)
function displayCraftMenu(pointerEvent, impact, pos)
    local screenPos = Number2(pointerEvent.X * Screen.Width, pointerEvent.Y * Screen.Height)

    -- Modify the position to be at y = 1 and z - 3 vs the pos
    pos = Number3(pos.X, 1, pos.Z - 6)
    showTarget(impact, pos)

    prompt = ui:createNode()
    local input = ui:createTextInput(nil, "What do you want?")
    input:setParent(prompt)
    input:focus()

    local send = function()
        if input.Text ~= "" then
            imageQuery(input.Text, impact, pos)
            sfx("modal_3", { Spatialized = false, Pitch = 2.0 })
        end
        prompt:remove()
        prompt = nil
        deleteTarget()
    end

    input.onSubmit = send

    local sendBtn = ui:createButton("✅", { textSize = "big" })
    sendBtn:setParent(prompt)
    sendBtn.onRelease = send

    input.Height = sendBtn.Height
    input.Width = 250
    sendBtn.pos.X = input.Width

    local width = input.Width + sendBtn.Width
    local height = sendBtn.Height

    local px = screenPos.X - width * 0.5
    if px < Screen.SafeArea.Left + PADDING then
        px = Screen.SafeArea.Left + PADDING
    end
    if px > Screen.Width - Screen.SafeArea.Right - width - PADDING then
        px = Screen.Width - Screen.SafeArea.Right - width - PADDING
    end

    local py = screenPos.Y + POINTER_OFFSET
    if py < Screen.SafeArea.Bottom + PADDING then
        py = Screen.SafeArea.Bottom + PADDING
    end
    if py > Screen.Height - Screen.SafeArea.Top - height - PADDING then
        py = Screen.Height - Screen.SafeArea.Top - height - PADDING
    end

    prompt.pos.X = px
    prompt.pos.Y = py
end

-- Image query
function imageQuery(message, impact, pos)
    if impact then
        pos = pos + { 0, 1, 0 }

        local e = Event()
        e.id = math.floor(math.random() * 1000000)
        e.pos = pos
        e.rotY = Player.Rotation.Y
        e.action = "requestImageGeneration" -- This is the important bit; it tells the server to generate an image
        local _, name = splitAtFirst(opponent.ItemName, '.') -- Assuming this contains the "opponent" name
        e.opponentName = name
        e.userInput = message
        e.m = message
        e:SendTo(Server)

        local e2 = Event()
        e2.action = "otherGen"
        e2.id = e.id
        e2.m = message
        e2.pos = e.pos
        e2.rotY = e.rotY
        e2:SendTo(OtherPlayers)

        makeBubble(e2)
    end
end

-- Spawn an opponent from the opponentsList
function shuffleList(list)
    math.randomseed(os.time())  -- init random generator from time (like C++)
    local len = #list
    for i = len, 2, -1 do
        local j = math.random(i)
        list[i], list[j] = list[j], list[i]
    end
    return list
end

function createRandomSpawnList()
    for i = 1, NUMBER_OF_CORRIDORS, 1 do
        randomOpponent[i] = i
    end
    shuffleList(randomOpponent)
end

function spawnRandomOpponent()
    -- Randomly select an opponent from the Config.Items list
    local opponentIndex = randomOpponent[level + 1] -- math.random(1, #opponentsList)
    local opponentKey = opponentsList[opponentIndex]

    local opponentShape = Shape(Items[opponentIndex], { includeChildren = true })

    -- Like above, but iterating over all children to find the lowest y value in child.BoundingBox.Min.Y
    local minY = 1000
    local minX = 1000
    local minZ = 1000
    -- using hierarchyActions
    hierarchyActions:applyToDescendants(opponentShape, function(sh)
        local bb = sh:ComputeWorldBoundingBox()
        if bb.Min.Y < minY then
            minY = bb.Min.Y
        end
        if bb.Min.X < minX then
            minX = bb.Min.X
        end
    end)

    -- Set opponent properties and add it to the world
    -- opponentShape:SetParent(World)
    World:AddChild(opponentShape)

    opponentShape.Position = { doors[level + 1].Position.X + minX, -minY, (doors[level + 1].Position.Z - opponentShape.Width) / 2 }
    opponentShape.Rotation = { 0, -math.pi / 2, 0 }
    opponentShape.IsHidden = false
    opponentShape.tag = "opponent"
    opponentShape.name = opponentKey
    -- split name to get only name without prefix
    local _, opponentName = splitAtFirst(opponentKey, '.')
    opponentShape.healthIndex = opponentIndex

    --Add to collision group
    opponentShape.CollisionGroups = Map.CollisionGroups
    attachHPBar(opponentShape)
    uiOpponent.Text = "Current opponent: " .. opponentName
    return opponentShape
end

Client.DidReceiveEvent = function(e)
    if paused then
        return
    end
    if e.action == "imageIsGenerated" then
        handleGeneratedImage(e)
    elseif e.action == "damageToApply" then
        damageToApply = e
    end
end

function handleGeneratedImage(e)
    local pos
    local rotY

    local bubble = gens[e.id]
    if bubble then
        pos = bubble.Position:Copy()
        rotY = bubble.Rotation.Y
        bubble.Tick = nil
        if bubble.text then
            bubble.text:RemoveFromParent()
        end
        bubble:RemoveFromParent()
        gens[e.id] = nil
        if e.vox == nil then
            print("sorry, request failed!")
            return
        end
    elseif e.pos then
        pos = e.pos
        rotY = e.rotY
    else
        return
    end

    local success = pcall(function()
        if JSON:Encode(e.vox)[1] == "{" then
            print(JSON:Encode(e.vox))
            return
        end
        local s = Shape(e.vox)
        s.CollisionGroups = Map.CollisionGroups
        s.tag = "generatedImage" -- Tagging the object as a generated image
        s.userInput = e.userInput
        s.user = e.user
        s:SetParent(World)

        -- first block is not at 0,0,0
        -- use collision box min to offset the pivot
        local collisionBoxMin = s.CollisionBox.Min
        local center = s.CollisionBox.Center:Copy()

        center.Y = s.CollisionBox.Min.Y
        s.Pivot = { s.Width * 0.5 + collisionBoxMin.X,
                    0 + collisionBoxMin.Y,
                    s.Depth * 0.5 + collisionBoxMin.Z }
        s.Position = pos
        s.Rotation.Y = rotY
        s.Physics = PhysicsMode.Dynamic

        Timer(1, function()
            s.Physics = PhysicsMode.TriggerPerBlock
            s.CollisionGroups = { GENERATED_ITEM_COLLISION_GROUP }
            firing = true
        end)
        generatedImage = s
        sfx("waterdrop_2", { Position = pos })
    end)
    if not success then
        sfx("twang_2", { Position = pos })
    end
end

function weaponAction(action)
    if generatedImage then
        generatedImage:RemoveFromParent()
    end
    generatedImage = nil
    print("" .. action)
    firing = false
end

launchToolOnOpponent = function(dt)
    if firing and generatedImage then
        if opponent.IsHidden then
            weaponAction("there is no opponent") -- don't work????
        elseif (opponent.Position - generatedImage.Position).Length > CORRIDOR_LENGTH then
            weaponAction("opponent is too far")
            Player:TextBubble("opponent is too far. Use another button")
        else
            local targetPosition = opponent.Position  -- Assume 'opponent' is accessible and has a position
            local animationTime = 1.0 -- Duration to reach the target, adjust as needed
            ease:outSine(generatedImage, animationTime).Position = targetPosition

            -- Check if the tool has reached the opponent or if you need to stop firing
            generatedImage.OnCollision = function(self, other)
                if other == opponent then
                    applyDamage(damageToApply)
                    firing = false
                    -- destroy the tool
                    generatedImage:RemoveFromParent()
                end
            end
        end
    end
end

function applyDamage(e)
    local target = Player
    if e.targetName ~= "player" then
        target = opponent
    end

    if target and hpBars[target.healthIndex + 1] and e.damageAmount then
        local hpBarInfo = hpBars[target.healthIndex + 1]
        -- Assuming damageAmount is the amount of HP to remove
        local damageAmount = tonumber(e.damageAmount)
        local currentPercentage = hpBarInfo.hpShape.LocalScale.Z / hpBarMaxLength
        local currentHP = currentPercentage * playerMaxHP
        -- Calculate new HP after taking damage
        local newHP = math.max(currentHP - damageAmount, 0)
        -- Update the target's HP visually
        setHPBar(target, newHP, true) -- true to animate the HP bar change
        -- Create a message to display the damage taken
        Player:TextBubble(e.message)
        -- if HP reaches 0, explode the target
        if newHP <= 0 then
            require("explode"):shapes(target)
            -- Destroy the target
            target:RemoveFromParent()
            if target == opponent then
                level = level + 1
                miniOpponents[randomOpponent[level]]:hide()
                uiScore.Text = "Level: " .. level
                doorAction(doors[level], "open")

                if level == NUMBER_OF_CORRIDORS then
                    opponent = nil
                    print("YOU WIN")
                    Player:TextBubble("Next Round")
                    endGame("YOU WIN") -- stop game........ if finish
                else
                    opponent = spawnRandomOpponent()
                end
            elseif target == Player then
                print("YOU LOSE")
                Player:TextBubble("YOU Lose")
                endGame("YOU Lose") -- stop game........ if finish
            end
        end
    end
end

-- Target
function showTarget(impact, pos)
    if impact == nil then
        return
    end

    if _target == nil then
        local ms = MutableShape()
        ms:AddBlock(Color.White, 0, 0, 0)

        ms:AddBlock(Color.White, -2, 0, -2)
        ms:AddBlock(Color.White, -2, 0, -1)
        ms:AddBlock(Color.White, -1, 0, -2)

        ms:AddBlock(Color.White, -2, 0, 2)
        ms:AddBlock(Color.White, -2, 0, 1)
        ms:AddBlock(Color.White, -1, 0, 2)

        ms:AddBlock(Color.White, 2, 0, 2)
        ms:AddBlock(Color.White, 2, 0, 1)
        ms:AddBlock(Color.White, 1, 0, 2)

        ms:AddBlock(Color.White, 2, 0, -2)
        ms:AddBlock(Color.White, 2, 0, -1)
        ms:AddBlock(Color.White, 1, 0, -2)

        _target = Shape(ms)
        _target.Pivot = { 0.5, 0.5, 0.5 }
        _target.Physics = PhysicsMode.Disabled
    end

    _target.LocalScale = Number3(0, 0, 0)
    _target.LocalPosition = pos
    _target.Up = faceNormals[impact.FaceTouched] or Number3(0, 1, 0)
    _target.Tick = function(o, dt)
        o:RotateLocal(o.Up, dt)
    end
    _target:SetParent(World)
    ease:outElastic(_target, 0.4).LocalScale = { 1.6, 1, 1.6 }
end

function deleteTarget()
    if _target ~= nil then
        _target:SetParent(nil)
    end
end

function showMenu(pointerEvent)
    hideMenu()

    local impact = pointerEvent:CastRay(Map.CollisionGroups + { GENERATED_ITEM_COLLISION_GROUP })
    if impact ~= nil then
        if impact.Object and impact.Object.isCraftButton then
            impact.Object.LocalPosition.Z = impact.Object.LocalPosition.Z + 1
            displayCraftMenu(pointerEvent, impact, impact.Object.Position)
            Timer(0.2, function()
                impact.Object.LocalPosition.Z = impact.Object.LocalPosition.Z - 1
                impact.Object.pushed = false
            end)
        end
    end
end

function hideMenu()
    if createButton then
        createButton:remove()
        createButton = nil
    end
    if prompt then
        prompt:remove()
        prompt = nil
    end
    if itemDetails then
        itemDetails:remove()
        itemDetails = nil
    end
    deleteTarget()
end

Client.OnChat = function(message)
    local e = Event()
    e.action = "chat"
    e.msg = message
    e:SendTo(Players)
end

-- Server code
Server.OnStart = function()
    gens = {}
    encounterEvents = {}
    firing = false
end

Server.OnPlayerJoin = function(p)
    print("Player joined: " .. p.Username)
    Timer(2, function()
        for _, d in ipairs(gens) do
            local headers = {}
            headers["Content-Type"] = "application/octet-stream"
            HTTP:Get(d.url, headers, function(data)
                local e = Event()
                e.vox = data.Body
                e.id = d.e.id
                e.pos = d.e.pos
                e.rotY = d.e.rotY
                e.userInput = d.e.userInput
                e.user = d.e.user
                e.action = "imageIsGenerated"
                e:SendTo(p)
            end)
        end
    end)
end

Server.DidReceiveEvent = function(e)
    if e.action == "requestImageGeneration" then
        local eMy = Event()
        eMy.opponentName = e.opponentName
        eMy.userInput = e.userInput
        resolveEncounter(eMy)

        -- Step 2: Continue with the image generation request
        local headers = {}
        local apiURL = "https://api.voxdream.art"

        headers["Content-Type"] = "application/json"
        HTTP:Post(apiURL .. "/pixelart/vox", headers, { userInput = e.userInput }, function(data)
            local body = JSON:Decode(data.Body)
            if not body.urls or #body.urls == 0 then
                print("Error: can't generate content.")
                return
            end
            voxURL = apiURL .. "/" .. body.urls[1]
            table.insert(gens, { e = e, url = voxURL })

            local headers = {}
            headers["Content-Type"] = "application/octet-stream"
            HTTP:Get(voxURL, headers, function(data)
                local e2 = Event()
                e2.vox = data.Body
                e2.user = e.Sender.Username
                e2.userInput = e.userInput
                e2.id = e.id
                e2.action = "imageIsGenerated"
                e2:SendTo(Players)
            end)
        end)
    else
        print("Unknown action: " .. e.action)
    end
end

function resolveEncounter(e)
    -- Construct the URL for the encounter resolution
    local apiURL = "https://gig.ax/api/encounter/"
    apiURL = apiURL .. "?opponent=" .. e.opponentName .. "&tool=" .. e.userInput

    HTTP:Get(apiURL, {}, function(data)
        local result = JSON:Decode(data.Body)

        if result and result.operations then
            encounterEvents = processEncounterResult(result)
            -- Send all events to all players
            for _, event in ipairs(encounterEvents) do
                event:SendTo(Players)
            end
        else
            print("Error: can't resolve encounter or no operations returned.")
        end
    end)
end

function processEncounterResult(result)
    local events = {}
    for _, operation in ipairs(result.operations) do
        if operation.name == "HURT" then
            local targetName = operation.parameters[1]
            local damageAmount = tonumber(operation.parameters[2])

            local hpUpdateEvent = Event()
            hpUpdateEvent.action = "damageToApply"
            hpUpdateEvent.targetName = targetName
            hpUpdateEvent.damageAmount = damageAmount
            hpUpdateEvent.message = result.description.text
            table.insert(events, hpUpdateEvent)
        elseif operation.name == "NOTHING" then
            local updateEvent = Event()
            updateEvent.action = "no_effect"
            updateEvent.description = result.description.text
            table.insert(events, updateEvent)
        end
    end

    return events
end


-- #### HP Bar stuff #####################
-- create and attach HP bar to given player
attachHPBar = function(obj)
    local frame = Shape(Items.petroglyph.hp_bar)
    obj:AddChild(frame)
    frame.LocalPosition = { 0, 35, 4.5 }
    frame.LocalRotation = { 0, math.pi * .5, 0 } -- item was drawn along Z
    if hpBarMaxLength == nil then
        hpBarMaxLength = frame.Depth - 2
    end

    local hp = Shape(Items.petroglyph.block_red)
    frame:AddChild(hp)
    hp.Pivot.Z = 0
    hp.LocalPosition.Z = -hpBarMaxLength * .5
    hp.LocalScale.Z = hpBarMaxLength
    hp.IsHidden = true

    local hpFull = Shape(Items.petroglyph.block_green)
    frame:AddChild(hpFull)
    hpFull.LocalScale.Z = hpBarMaxLength

    --print("Attaching HP bar to player at index: " .. obj.healthIndex .. " player name is " .. obj.name)
    hpBar = {
        player = obj,
        startScale = hpBarMaxLength,
        targetScale = hpBarMaxLength,
        timer = 0,
        hpShape = hp,
        hpFullShape = hpFull,
        frameShape = frame
    }
    --print("hpBar length: " .. hpBar.hpShape.LocalScale.Z)
    hpBars[obj.healthIndex + 1] = hpBar
end

-- remove HP bar from player
removeHPBar = function(player)
    hpBars[player.healthIndex + 1] = {}
end

-- sets target HP for given player, animated by default
setHPBar = function(player, hpValue, isAnimated)
    local hp = hpBars[player.healthIndex + 1]
    local v = clamp(hpValue / playerMaxHP, 0, 1)
    if isAnimated or isAnimated == nil then
        hp.startScale = hp.hpShape.LocalScale.Z
        hp.targetScale = hpBarMaxLength * v
        hp.timer = playerHPDuration
    else
        if v == 1.0 then
            hp.hpFullShape.IsHidden = false
            hp.hpShape.IsHidden = true
        else
            hp.hpFullShape.IsHidden = true
            hp.hpShape.IsHidden = false
            hp.hpShape.LocalScale.Z = hpBarMaxLength * v
        end
        hp.timer = 0
    end
end

-- update all HP bars animation
updateHPBars = function(dt, i)
    local hp = nil
    for i = 1, #hpBars, 1 do
        hp = hpBars[i]
        if hp.timer ~= nil and hp.timer > 0 then
            hp.timer = hp.timer - dt

            local delta = hp.targetScale - hp.startScale
            local v = clamp(1 - hp.timer / playerHPDuration, 0, 1)
            hp.hpShape.LocalScale.Z = hp.startScale + delta * v

            local isFull = hp.hpShape.LocalScale.Z == hpBarMaxLength
            hp.hpFullShape.IsHidden = not isFull
            hp.hpShape.IsHidden = isFull

            if delta < 0 then
                hp.frameShape.LocalPosition.X = playerHPNegativeShake * math.sin(60 * hp.timer)
            else
                hp.frameShape.LocalPosition.Y = 26 + playerHPPositiveBump * math.sin(v * math.pi)
            end
        end
    end
end


-- #### UI Stuff #####################

-- shows instructions at the top left corner of the screen
function showInstructions()
    if instructions ~= nil then
        instructions:show()
        return
    end

    instructions = ui:createFrame(Color(0, 0, 0, 128))
    local line1 = ui:createText("🎥 Drag to move camera", Color.White)
    line1:setParent(instructions)
    local line2 = ui:createText("☝️ Click on the CRAFT WEAPON button to attack the monster!", Color.White)
    line2:setParent(instructions)
    local line3 = ui:createText("🔎 Beat all the monsters to win the game.", Color.White)
    line3:setParent(instructions)

    instructions.parentDidResize = function()
        local width = math.max(line1.Width, line2.Width, line3.Width) + PADDING * 2
        local height = line1.Height + line2.Height + line3.Height + PADDING * 4
        instructions.Width = width
        instructions.Height = height
        line1.pos = { PADDING, instructions.Height - PADDING - line1.Height, 0 }
        line2.pos = line1.pos - { 0, line1.Height + PADDING, 0 }
        line3.pos = line2.pos - { 0, line2.Height + PADDING, 0 }
        instructions.pos = { Screen.SafeArea.Left + PADDING, Screen.Height - Screen.SafeArea.Top - instructions.Height - PADDING, 0 }
    end
    instructions:parentDidResize()
end

function hideInstructions()
    if instructions ~= nil then
        instructions:hide()
    end
end

function showWelcomeHint()
    if welcomeHint ~= nil then
        return
    end
    welcomeHint = ui:createText("Click on the CRAFT WEAPON block!", Color(1.0, 1.0, 1.0), "big")
    welcomeHint.parentDidResize = function()
        welcomeHint.pos.X = Screen.Width * 0.5 - welcomeHint.Width * 0.5
        welcomeHint.pos.Y = Screen.Height * 0.66 - welcomeHint.Height * 0.5
    end
    welcomeHint:parentDidResize()

    local t = 0
    welcomeHint.object.Tick = function(o, dt)
        t = t + dt
        if (t % 0.4) <= 0.2 then
            o.Color = Color(0.0, 0.8, 0.6)
        else
            o.Color = Color(1.0, 1.0, 1.0)
        end
    end
end

function hideWelcomeHint()
    if welcomeHint == nil then
        return
    end
    welcomeHint:remove()
    welcomeHint = nil
end

-- creates loading bubble
function makeBubble(e)
    local bubble = MutableShape()
    bubble:AddBlock(Color.White, 0, 0, 0)
    bubble:SetParent(World)
    bubble.Pivot = Number3(0.5, 0, 0.5)
    bubble.Position = e.pos
    bubble.Rotation.Y = e.rotY
    bubble.eid = e.id

    bubble.Tick = function(o, dt)
        o.Scale.X = o.Scale.X + dt * 2
        o.Scale.Y = o.Scale.Y + dt * 2
        if o.text ~= nil then
            o.text.Position = o.Position
            o.text.Position.Y = o.Position.Y + o.Height * o.Scale.Y + 1
        end
    end

    local t = Text()
    t:SetParent(World)
    t.Rotation.Y = e.rotY
    t.Text = e.m
    t.Type = TextType.World
    t.IsUnlit = true
    t.Tail = true
    t.Anchor = { 0.5, 0 }
    t.Position.Y = bubble.Position.Y + bubble.Height * bubble.Scale.Y + 1
    bubble.text = t

    -- remove after 15 seconds without response
    Timer(15, function()
        if bubble then
            gens[bubble.eid] = nil
            bubble.Tick = nil
            if bubble.text then
                bubble.text:RemoveFromParent()
            end
            bubble:RemoveFromParent()
        end
    end)

    gens[e.id] = bubble
end

function splitAtFirst(inputString, delimiter)
    local pos = string.find(inputString, delimiter, 1, true)
    if pos then
        return string.sub(inputString, 1, pos - 1), string.sub(inputString, pos + 1)
    else
        return inputString
    end
end

-- #### Utility functions #####################

clamp = function(value, min, max)
    if value < min then
        return min
    elseif value > max then
        return max
    else
        return value
    end
end