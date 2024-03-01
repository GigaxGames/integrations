Config = {
    Items = {
        "claire.torch",
        "voxels.gate"
    }
}


-- The rest of the variables are unchanged
local BROWN = Color(139, 69, 19)
local CORRIDOR_LENGTH = 150
local door = Shape(Items.voxels.gate)
local CORRIDOR_WIDTH = door.Width
local WALL_HEIGHT = 40
local TORCH_SPACING = 40

-- Constants
local NUMBER_OF_CORRIDORS = 2
local corridors = {}
local doors = {}
local lastDoorIx = 2


Client.OnStart = function()
    -- Add player to game
    World:AddChild(Player, true)

    -- Initialize the corridors and gates
    for i = 1, NUMBER_OF_CORRIDORS do
        corridors[i] = makeCorridor((i-1) * CORRIDOR_LENGTH, i)
    end

    -- Set up the UI
    ease = require "ease"
	ui = require "uikit"
    sfx = require "sfx"
    controls = require "controls"
	controls:setButtonIcon("action1", "⬆️")
end

Pointer.Click = function(pointerEvent)
    local impact = pointerEvent:CastRay(kMapAndItemsCollisionGroups)
    local object = impact.Object

    print(object.isDoor)
    if impact and impact.Distance < 500 then
        if object and object.isDoor then
            doorAction(object, "toggle")
            if object.number == lastDoorIx then  -- Only if the last door is clicked
                -- Move the other corridor in front
                advanceCorridor()
            end
        end
    end
end

function advanceCorridor()
    local corridorToMoveIx = lastDoorIx % 2 + 1
    local corridorToMove = corridors[corridorToMoveIx]
    corridorToMove.Position = Number3(corridorToMove.Position.X + (CORRIDOR_LENGTH * 2), 0, 0)
    -- close the other door
    doorAction(doors[corridorToMoveIx], "close")
    -- Toggle the last door index for the next time
    lastDoorIx = corridorToMoveIx
end

-- Function to create and set up the door
function createDoorAtEndOfCorridor(offset, ix)
    local door = Shape(Items.voxels.gate)
    door.Position = Number3(offset + CORRIDOR_LENGTH, door.Height/2, door.Width)
    door.Rotation = Number3(0, math.pi / 2, 0)  -- Adjusted to face the corridor
    door.Pivot = { 0, door.Height * 0.5, door.Depth * 0.5 }
    door.isDoor = true
    door.number = ix -- If you have more doors, increment this number for each
    door.closed = true
    door.rotClosed = math.pi / 2  -- The rotation when the door is closed
    doors[door.number] = door
    --door.collisionGroups = {DOOR_COLLISION_GROUP}
    World:AddChild(door)
    return door
end

function makeCorridor(offset, ix)
    print("Creating corridor " .. ix)
    local corridor = Object()
    World:AddChild(corridor)
    -- Add a door at the end of the corridor
    doors[ix] = createDoorAtEndOfCorridor(offset, ix)
    corridor:AddChild(doors [ix])

    -- Create floor
    local floor = MutableShape()
    for x = offset, offset + CORRIDOR_LENGTH - 1 do
        for z = 1, CORRIDOR_WIDTH - 2 do -- Subtracting 2 since we're building walls on both sides
            floor:AddBlock(BROWN, x, 0, z)
        end
    end
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

    return corridor
end

function addTorch(x, y, z)
    local torch = Shape(Items.claire.torch)
    torch.Position = Number3(x, y, z) -- Position adjusted for scale
    return torch
end

-- door stuff

-- This function would be called when a monster is defeated
function openDoor(doorNumber)
    local door = doors[doorNumber]
    if door and door.isDoor and door.closed then
        doorAction(door, "open")
    end
end

-- Function to perform actions on doors
function doorAction(object, action)
    print("Performing action on door nb " .. object.number .. ": " .. action)
    if action == "toggle" then
        object.closed = not object.closed
    elseif action == "close" then
        object.closed = true
    elseif action == "open" then
        object.closed = false
    end

    -- Play sound effects based on the action
    if object.closed then
        print("closing door")
        sfx("doorclose_1", object.Position, 0.5)
    else
        print("opening door")
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