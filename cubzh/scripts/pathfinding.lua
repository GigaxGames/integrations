-- Modules
-- Pathfinding
-- Map loader
-- Ressources
-- Collect & Respawn
-- Craft
Config = {
	Map = "buche.playground_heights",
}

local UI_ICON_SIZE = 32
local UI_MARGIN_SMALL = 4

localPlayerResources = {
	["Iron"] = 10,
	["Ash"] = 7,
}

inventory = {
	maxWeight = 500,
}

resourcesList = {
	["Iron"] = { min = 0, level = 1, trade = "Miner", weight = 5, icon = "jacksbertox.iron_ingot" },
	["Copper"] = { min = 0, level = 2, trade = "Miner", weight = 5, icon = "jacksbertox.iron_ingot" },
	["Bronze"] = { min = 0, level = 3, trade = "Miner", weight = 5, icon = "jacksbertox.iron_ingot" },
	["Cobalt"] = { min = 0, level = 4, trade = "Miner", weight = 5, icon = "jacksbertox.iron_ingot" },
	["Tin"] = { min = 0, level = 5, trade = "Miner", weight = 5, icon = "jacksbertox.iron_ingot" },
	--
	["Ash"] = { min = 0, level = 1, trade = "Lumberjack", weight = 5, icon = "voxels.log_2" },
	["Chestnut"] = { min = 0, level = 2, trade = "Lumberjack", weight = 5, icon = "voxels.log_2" },
	["Walnut"] = { min = 0, level = 3, trade = "Lumberjack", weight = 5, icon = "voxels.log_2" },
	["Oak"] = { min = 0, level = 4, trade = "Lumberjack", weight = 5, icon = "voxels.log_2" },
	["Maple"] = { min = 0, level = 5, trade = "Lumberjack", weight = 5, icon = "voxels.log_2" },
	--
	["Wheat"] = { min = 0, level = 1, trade = "Farmer", weight = 2, icon = "pratamacam.corn" },
	["Barley"] = { min = 0, level = 2, trade = "Farmer", weight = 2, icon = "pratamacam.corn" },
	["Oats"] = { min = 0, level = 3, trade = "Farmer", weight = 2, icon = "pratamacam.corn" },
	["Hop"] = { min = 0, level = 4, trade = "Farmer", weight = 2, icon = "pratamacam.corn" },
	["Flax"] = { min = 0, level = 5, trade = "Farmer", weight = 2, icon = "pratamacam.corn" },
	--
	["Nettles"] = { min = 0, level = 1, trade = "Alchemist", weight = 1, icon = "aduermael.leaf" },
	["Sage"] = { min = 0, level = 2, trade = "Alchemist", weight = 1, icon = "aduermael.leaf" },
	["Clover"] = { min = 0, level = 3, trade = "Alchemist", weight = 1, icon = "aduermael.leaf" },
	["Mint"] = { min = 0, level = 4, trade = "Alchemist", weight = 1, icon = "aduermael.leaf" },
	["Edelweiss"] = { min = 0, level = 5, trade = "Alchemist", weight = 1, icon = "aduermael.leaf" },
}

craftsList = {
	["Ferrite"] = {
		trade = "Miner",
		level = 2,
		weight = 10,
		ingredients = {
			["Iron"] = 10,
			["Copper"] = 10,
		},
	},
	["Loaf"] = {
		trade = "Farmer",
		level = 2,
		weight = 4,
		ingredients = {
			["Wheat"] = 10,
			["Barley"] = 10,
		},
	},
}

uiUpdateResource = function(_, resourceName, amount)
	local text = uiElements[resourceName]
	text.Text = string.format("%d", amount)
	text.pos = text.icon.pos + { -text.Width - 10, text.icon.Height * 0.5 - text.Height * 0.5, 0 }
	if amount > 0 then
		text.icon:show()
		text:show()
	else
		text.icon:hide()
		text:hide()
	end
end

Client.OnStart = function()
	require("multi")
	require("sfx")
	require("textbubbles").displayPlayerChatBubbles = true
	walkSFX = require("walk_sfx")
	ui = require("uikit")

	cResources:init(resourcesList)
	for k, _ in pairs(resourcesList) do
		cResources:addResourceCallbacks(k, {
			onChange = uiUpdateResource,
		})
	end

	initMap()
	initUI()
	initPlayer(Player)
	dropPlayer(Player, Number3(Map.Width * 0.5, Map.Height + 1, Map.Depth * 0.5), Number3(0, 0, 0))

	--map = loadMap(0, 0)
end

mapList = {}
initMap = function()
	for i = 0, 3 do
		mapList[i] = {}
	end
	mapList[0][0] = "buche.playground_heights"
	mapList[0][1] = "buche.playground_heights"
end

uiElements = {}
initUI = function()
	local idx = 0
	for k, v in pairs(resourcesList) do
		local i = idx + 1
		Object:Load(v.icon, function(obj)
			local text = ui:createText(string.format("%d", v.min), Color.White, "default")
			local icon = ui:createShape(obj, { spherized = true })
			icon.Size = UI_ICON_SIZE
			text.icon = icon
			text.displayIndex = i
			uiElements[k] = text
			text.parentDidResize = function(self)
				self.icon.pos = {
					Screen.Width - UI_MARGIN_SMALL - self.icon.Width,
					Screen.Height - Screen.SafeArea.Top - (self.icon.Height + UI_MARGIN_SMALL) * self.displayIndex,
				}
				self.pos = self.icon.pos + { -self.Width - 10, self.Height * 0.5 - self.Height * 0.5, 0 }
			end
			text:parentDidResize()
		end)
		idx = idx + 1
	end
end

initPlayer = function(p)
	World:AddChild(p)
	p.Head:AddChild(AudioListener)
	p.Physics = true
	walkSFX:register(p)
end

dropPlayer = function(p, pos, rot)
	p.Position = pos
	p.Rotation = rot
end

-- CRESOURCES MODULE
cResources = {}
local index = {
	resourcesListeners = {},
}

local metatable = {
	__index = index,
	__metatable = false,
}
setmetatable(cResources, metatable)

-- table of "name = { min, max, default }"
index.init = function(_, resourcesList)
	index.resourcesList = resourcesList
	for _, v in pairs(index.resourcesList) do
		v.default = v.default or v.min
	end
end

-- config can be { max = 20 } to change the max value for example
index.updateResource = function(_, target, resourceName, config)
	for k, v in pairs(config) do
		target.cResources[resourceName][k] = v
	end
	if index.resourcesListeners[resourceName] then
		for _, callbacks in ipairs(index.resourcesListeners[resourceName]) do
			if callbacks.onChange then
				callbacks.onChange(target, resourceName, target.cResources[resourceName].value)
			end
		end
	end
end

-- return a listener with a Remove function
-- callbacks is an array containing two functions (optional)
--   - onChange = function(target, resourceName, amount)
--   - onMinReach = function(target, resourceName, amount)
--   - onMaxReach = function(target, resourceName, amount)
index.addResourceCallbacks = function(_, resourceName, callbacks)
	index.resourcesListeners[resourceName] = index.resourcesListeners[resourceName] or {}
	table.insert(index.resourcesListeners[resourceName], callbacks)
	return {
		Remove = function()
			for i = #index.resourcesListeners[resourceName], 1, -1 do
				local item = index.resourcesListeners[resourceName][i]
				if item == callbacks then
					table.remove(index.resourcesListeners[resourceName], i)
					return
				end
			end
		end,
	}
end

index.add = function(_, target, resourceName, amount)
	local resource = target.cResources[resourceName]
	if resource.max and resource.value >= resource.max then
		if index.resourcesListeners[resourceName] then
			for _, callbacks in ipairs(index.resourcesListeners[resourceName]) do
				if callbacks.onMaxReach then
					callbacks.onMaxReach(target, resourceName, target.cResources[resourceName].value)
				end
			end
		end
		return false
	end

	resource.value = math.floor(resource.value + amount)

	if resource.max and resource.value > resource.max then
		resource.value = resource.max
		if index.resourcesListeners[resourceName] then
			for _, callbacks in ipairs(index.resourcesListeners[resourceName]) do
				if callbacks.onMaxReach then
					callbacks.onMaxReach(target, resourceName, resource.value)
				end
			end
		end
	end

	if index.resourcesListeners[resourceName] then
		for _, callbacks in ipairs(index.resourcesListeners[resourceName]) do
			if callbacks.onChange then
				callbacks.onChange(target, resourceName, resource.value)
			end
		end
	end

	-- TODO: save
	return true
end

index.remove = function(_, target, resourceName, amount)
	local resource = target.cResources[resourceName]
	local newValue = math.floor(resource.value - amount)
	if resource.min and resource.value < resource.min then
		if index.resourcesListeners[resourceName] then
			for _, callbacks in ipairs(index.resourcesListeners[resourceName]) do
				if callbacks.onMinReach then
					callbacks.onMinReach(target, resourceName, resource.value)
				end
			end
		end
		return false
	end

	resource.value = newValue

	if index.resourcesListeners[resourceName] then
		for _, callbacks in ipairs(index.resourcesListeners[resourceName]) do
			if callbacks.onChange then
				callbacks.onChange(target, resourceName, resource.value)
			end
		end
	end

	-- TODO: save
	return true
end

LocalEvent:Listen(LocalEvent.Name.OnPlayerJoin, function(p)
	if not index.resourcesList then
		--error("resourcesList is not defined")
		return
	end
	p.cResources = {}
	for name, v in pairs(index.resourcesList) do
		p.cResources[name] = {
			value = v.default,
			default = v.default,
			min = v.min,
			max = v.max,
		}
	end

	for k, v in pairs(localPlayerResources) do
		index:add(p, k, v)
	end
end)
-- END CRESOURCES MODULE

-- MODULE
-- POINT AND CLICK
-- Create a point and click mode with a topdown camera with movement mechanics including pathfinding
pointAndClick = {}

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

local CURSOR_SCALE = Number3(0.5, 0.5, 0.5)
local OFFSET_XZ = Number3(0.5, 0, 0.5)
local OFFSET_Y = Number3(0, 1, 0)
local BOXCAST_DIST = 500

local multi = require("multi")
local ease = require("ease")
local particles = require("particles")

local _config = nil
local instance = {}
instance.camera = nil
instance.pfMap = nil
instance.pfPath = nil
instance.pfStep = nil
instance.cursorPath = {}
instance.cursors = {}

-- AUTO INTEGRATION
LocalEvent:Listen(LocalEvent.Name.OnPlayerJoin, function(p)
	if type(Client.IsMobile) == "boolean" then
		print("lol")
		pointAndClick:init(p)
	end
end)
LocalEvent:Listen(LocalEvent.Name.Tick, function(dt)
	if _config == nil then
		return
	end
	_cameraFollow(_config.camera, Player)
	_cameraHideBlockingObjects(_config.camera)
	_moveNoPhysics(dt)
end)
LocalEvent:Listen(LocalEvent.Name.PointerUp, function(pointerEvent)
	if not instance.pfMap then
		return
	end
	_pathTo(pointerEvent)
end)
LocalEvent:Listen(LocalEvent.Name.PointerWheel, function(value)
	if not instance.camera then
		return
	end
	_cameraZoom(instance.camera, value)
end)
LocalEvent:Listen(LocalEvent.Name.PointerDrag, function(pointerEvent)
	if not instance.camera then
		return
	end
	_cameraRotate(instance.camera, pointerEvent)
end)

multi:onAction("showCursor", function(_, data)
	_showCursor(Players[data.id], data.pos)
end)

-- INIT FUNCTIONS
pointAndClick.init = function(_, p)
	Client.DirectionalPad = nil
	Client.AnalogPad = nil
	Pointer.Drag = nil

	if not _config then
		_setConfig()
	end
	_initializePlayer(p, _config.camera)
	if not p == Player then
		return
	end
	_initializeMap(_config.map)
end

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
		print("init player")
		instance.camera = _initializeCamera(c)
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
	_cursorCreate(p)
end

_initializeMap = function()
	instance.pfMap = pathfinding.createPathfindingMap()
end

_initializeCamera = function(c)
	Fog.On = false
	-- c:SetModeFree()
	-- c.zoom = defaultConfig.zoomDefault
	return c
end

-- CAMERA FUNCTIONS
_cameraZoom = function(c, value)
	if c.zoom + config.zoomSpeed * value < config.zoomMin then
		c.zoom = config.zoomMin
	elseif c.zoom + config.zoomSpeed * value > config.zoomMax then
		c.zoom = config.zoomMax
	else
		c.zoom = c.zoom + config.zoomSpeed * value
	end
end

_cameraFollow = function(c, t)
	-- c.Position.X, c.Position.Z = t.Position.X + config.cameraOffset.X, t.Position.Z + config.cameraOffset.Z
	-- c.Position.Y = c.zoom
	-- c.Forward = Number3(t.Position.X, config.cameraFocusY, t.Position.Z) - c.Position
end

_cameraRotate = function(c, pe)
	c:RotateLocal({ 0, 1, 0 }, pe.DX * 0.01)
end

_cameraHideBlockingObjects = function(c)
	-- local box = Box(c.Position - Map.Scale, c.Position + Map.Scale)
	-- local dist = math.min((c.Position - Player.Position).Length, BOXCAST_DIST)
	-- local impact = box:Cast(c.Forward, dist, config.obstacleGroups)
	-- if not impact.Object then
	-- 	return
	-- end

	-- impact.Object.PrivateDrawMode = 1
	-- if not impact.Object.drawTimer then
	-- 	impact.Object.drawTimer = Timer(0.5, function()
	-- 		impact.Object.PrivateDrawMode = 0
	-- 		impact.Object.drawTimer = nil
	-- 	end)
	-- end
end

-- MOVEMENT FUNCTIONS
_pathTo = function(pointerEvent)
	local impact = pointerEvent:CastRay(config.mapGroups)
	if impact.Block == nil then
		return
	end

	local origin = Map:WorldToBlock(Player.Position)
	origin = Number3(math.floor(origin.X), math.floor(origin.Y), math.floor(origin.Z))
	local destination = impact.Block.Position / Map.Scale + OFFSET_Y
	local path = pathfinding.findPath(origin, destination, instance.pfMap)
	if not path then
		return
	end

	instance.pfPath = path
	instance.pfStep = #path - 1 --skipping the first block, which we're standing on

	destination = impact.Block.Position + (OFFSET_XZ + OFFSET_Y) * Map.Scale
	_showCursor(Player, destination)
	_showPath(instance.pfPath)
	_followPath(Player, instance.pfPath, instance.pfStep)
end

_showCursor = function(p, pos)
	if p == Player then
		multi:action("showCursor", { id = Player.ID, pos = pos })
	end
	_cursorSet(instance.cursors[p.ID], pos)
end

_followPath = function(p, path, idx)
	if not path[idx] then
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

----------------------
--module "pathfinding"
----------------------
pathfinding = {}

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
	return false
end