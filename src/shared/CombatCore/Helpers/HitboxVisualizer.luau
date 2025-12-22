--[[
	Module: HitboxVisualizer
	Type: Debug Utility Module
	Location: ReplicatedStorage.CombatCore.Helpers.HitboxVisualizer
	Path: src/shared/CombatCore/Helpers/HitboxVisualizer.luau
	
	Description:
		Debug utility for visualizing combat hitboxes in real-time.
		Shows hitbox size, position, range, and direction for development/testing.
		Only active when Config.Debug.ShowHitboxes is enabled.
	
	Usage:
		-- Legacy API (backward compatible)
		HitboxVisualizer.ShowHitbox(origin, size, attackType, duration)
		HitboxVisualizer.ShowRange(origin, range, attackType, duration)
		HitboxVisualizer.ShowDirection(origin, direction, attackType, length, duration)
		HitboxVisualizer.ShowAttack(origin, direction, size, range, attackType, duration)
		
		-- New config-based API (recommended for complex calls)
		HitboxVisualizer.ShowDirectionConfig({
			origin = Vector3.new(0, 5, 0),
			direction = character.HumanoidRootPart.CFrame.LookVector,
			attackType = "LightAttack",
			length = 10,
			duration = 2
		})
		
		HitboxVisualizer.ShowAttackConfig({
			origin = rootPart.Position,
			direction = rootPart.CFrame.LookVector,
			size = Vector3.new(6, 6, 6),
			range = 12,
			attackType = "StrongAttack",
			duration = 1.5
		})
	
	Author: Professional Roblox Scripter
	Created: December 13, 2025
	Updated: December 20, 2025 - Added config-based API
--]]

-- Module Imports
local Config = require(script.Parent.Parent.Config.Config)

-- Hitbox Visualizer Module
local HitboxVisualizer = {}

-- ========================================
-- TYPES
-- ========================================

export type VisualizationConfig = {
	origin: Vector3,
	attackType: string,
	duration: number?,
	-- For hitbox
	size: Vector3?,
	-- For range
	range: number?,
	-- For direction
	direction: Vector3?,
	length: number?,
}

-- ========================================
-- CONFIGURATION
-- ========================================

local ENABLED = Config.Debug.ShowHitboxes
local TRANSPARENCY = Config.Debug.HitboxTransparency
local DURATION = Config.Debug.HitboxDuration
local COLORS = Config.Debug.HitboxColors

-- Debug folder in workspace
local function GetDebugFolder(): Folder
	local debugFolder = workspace:FindFirstChild("_CombatDebug")
	if not debugFolder then
		debugFolder = Instance.new("Folder")
		debugFolder.Name = "_CombatDebug"
		debugFolder.Parent = workspace
	end
	return debugFolder
end

-- ========================================
-- HITBOX VISUALIZATION
-- ========================================

-- Show a hitbox (rectangular region)
function HitboxVisualizer.ShowHitbox(origin: Vector3, size: Vector3, attackType: string, duration: number?)
	if not ENABLED then return end
	
	duration = duration or DURATION
	local color = COLORS[attackType] or COLORS.Default
	
	-- Create hitbox part (wireframe style)
	local hitbox = Instance.new("Part")
	hitbox.Name = "Hitbox_" .. attackType
	hitbox.Size = size
	hitbox.CFrame = CFrame.new(origin)
	hitbox.Transparency = TRANSPARENCY -- Almost invisible faces
	hitbox.Color = color
	hitbox.Material = Enum.Material.ForceField -- Special transparent material
	hitbox.CanCollide = false
	hitbox.Anchored = true
	hitbox.CastShadow = false
	
	-- Add thick colored outline (wireframe edges)
	local selectionBox = Instance.new("SelectionBox")
	selectionBox.LineThickness = Config.Debug.EdgeThickness or 0.08
	selectionBox.Color3 = color
	selectionBox.Transparency = 0 -- Solid edges
	selectionBox.Adornee = hitbox
	selectionBox.Parent = hitbox
	
	hitbox.Parent = GetDebugFolder()
	
	-- Auto-destroy after duration with safety check
	local thread = task.delay(duration, function()
		if hitbox and hitbox.Parent then
			hitbox:Destroy()
		end
	end)
	
	-- Cancel thread if hitbox is destroyed early
	hitbox.Destroying:Connect(function()
		task.cancel(thread)
	end)
	
	return hitbox
end

-- Show movement trail (creates boxes along path)
function HitboxVisualizer.ShowMovementTrail(origin: Vector3, size: Vector3, attackType: string, duration: number?)
	if not ENABLED then return end
	
	duration = duration or (DURATION * 0.5) -- Shorter duration for trail
	local color = COLORS[attackType] or COLORS.Default
	
	-- Create trail box part
	local trailBox = Instance.new("Part")
	trailBox.Name = "Trail_" .. attackType
	trailBox.Size = size
	trailBox.CFrame = CFrame.new(origin)
	trailBox.Transparency = Config.Debug.MovementTrailTransparency or 0.85
	trailBox.Color = color
	trailBox.Material = Enum.Material.ForceField
	trailBox.CanCollide = false
	trailBox.Anchored = true
	trailBox.CastShadow = false
	
	-- Add outline
	local selectionBox = Instance.new("SelectionBox")
	selectionBox.LineThickness = (Config.Debug.EdgeThickness or 0.08) * 0.7 -- Slightly thinner for trail
	selectionBox.Color3 = color
	selectionBox.Transparency = 0.3 -- Slightly transparent edges for trail
	selectionBox.Adornee = trailBox
	selectionBox.Parent = trailBox
	
	trailBox.Parent = GetDebugFolder()
	
	-- Fade out and destroy
	local thread = task.delay(duration, function()
		if trailBox and trailBox.Parent then
			trailBox:Destroy()
		end
	end)
	
	trailBox.Destroying:Connect(function()
		task.cancel(thread)
	end)
	
	return trailBox
end

-- Show detection range (sphere)
function HitboxVisualizer.ShowRange(origin: Vector3, range: number, attackType: string, duration: number?)
	if not ENABLED or not Config.Debug.ShowHitRange then return end
	
	duration = duration or DURATION
	local color = COLORS[attackType] or COLORS.Default
	
	-- Create range sphere
	local sphere = Instance.new("Part")
	sphere.Name = "Range_" .. attackType
	sphere.Shape = Enum.PartType.Ball
	sphere.Size = Vector3.new(range * 2, range * 2, range * 2)
	sphere.CFrame = CFrame.new(origin)
	sphere.Transparency = TRANSPARENCY + 0.2 -- More transparent than hitbox
	sphere.Color = color
	sphere.Material = Enum.Material.ForceField
	sphere.CanCollide = false
	sphere.Anchored = true
	sphere.CastShadow = false
	
	sphere.Parent = GetDebugFolder()
	
	-- Auto-destroy after duration with safety check
	local thread = task.delay(duration, function()
		if sphere and sphere.Parent then
			sphere:Destroy()
		end
	end)
	
	-- Cancel thread if sphere is destroyed early
	sphere.Destroying:Connect(function()
		task.cancel(thread)
	end)
	
	return sphere
end

-- Show attack origin point
function HitboxVisualizer.ShowOrigin(origin: Vector3, attackType: string, duration: number?)
	if not ENABLED or not Config.Debug.ShowHitboxOrigin then return end
	
	duration = duration or DURATION
	local color = COLORS[attackType] or COLORS.Default
	
	-- Create origin marker (small sphere)
	local marker = Instance.new("Part")
	marker.Name = "Origin_" .. attackType
	marker.Shape = Enum.PartType.Ball
	marker.Size = Vector3.new(1, 1, 1)
	marker.CFrame = CFrame.new(origin)
	marker.Transparency = 0
	marker.Color = color
	marker.Material = Enum.Material.Neon
	marker.CanCollide = false
	marker.Anchored = true
	marker.CastShadow = false
	
	-- Add bright core
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = 2
	light.Range = 10
	light.Parent = marker
	
	marker.Parent = GetDebugFolder()
	
	-- Auto-destroy after duration with safety check
	local thread = task.delay(duration, function()
		if marker and marker.Parent then
			marker:Destroy()
		end
	end)
	
	-- Cancel thread if marker is destroyed early
	marker.Destroying:Connect(function()
		task.cancel(thread)
	end)
	
	return marker
end

-- Show attack direction arrow (Legacy API for backward compatibility)
function HitboxVisualizer.ShowDirection(origin: Vector3, direction: Vector3, attackType: string, length: number?, duration: number?)
	return HitboxVisualizer.ShowDirectionConfig({
		origin = origin,
		direction = direction,
		attackType = attackType,
		length = length,
		duration = duration,
	})
end

-- Show attack direction arrow (New config-based API)
function HitboxVisualizer.ShowDirectionConfig(config: VisualizationConfig)
	if not ENABLED or not Config.Debug.ShowHitDirection then return end
	
	local origin = config.origin
	local direction = config.direction
	local attackType = config.attackType
	local length = config.length or 5
	local duration = config.duration or DURATION
	local color = COLORS[attackType] or COLORS.Default
	
	-- Create arrow shaft
	local shaft = Instance.new("Part")
	shaft.Name = "Direction_" .. attackType
	shaft.Size = Vector3.new(0.5, 0.5, length)
	shaft.CFrame = CFrame.new(origin) * CFrame.new(0, 0, -length/2) * CFrame.Angles(0, 0, 0)
	shaft.CFrame = CFrame.lookAt(origin, origin + direction) * CFrame.new(0, 0, -length/2)
	shaft.Transparency = 0.3
	shaft.Color = color
	shaft.Material = Enum.Material.Neon
	shaft.CanCollide = false
	shaft.Anchored = true
	shaft.CastShadow = false
	
	-- Create arrow head (cone)
	local head = Instance.new("Part")
	head.Name = "ArrowHead"
	head.Shape = Enum.PartType.Cylinder
	head.Size = Vector3.new(1.5, 1.5, 1.5)
	head.CFrame = shaft.CFrame * CFrame.new(0, 0, -length/2 - 0.75) * CFrame.Angles(0, math.rad(90), 0)
	head.Transparency = 0
	head.Color = color
	head.Material = Enum.Material.Neon
	head.CanCollide = false
	head.Anchored = true
	head.CastShadow = false
	
	local folder = Instance.new("Folder")
	folder.Name = "Arrow_" .. attackType
	folder.Parent = GetDebugFolder()
	
	shaft.Parent = folder
	head.Parent = folder
	
	-- Auto-destroy after duration with safety check
	local thread = task.delay(duration, function()
		if folder and folder.Parent then
			folder:Destroy()
		end
	end)
	
	-- Cancel thread if folder is destroyed early
	folder.Destroying:Connect(function()
		task.cancel(thread)
	end)
	
	return folder
end

-- Show complete attack visualization (Legacy API for backward compatibility)
function HitboxVisualizer.ShowAttack(origin: Vector3, direction: Vector3, size: Vector3, range: number, attackType: string, duration: number?)
	return HitboxVisualizer.ShowAttackConfig({
		origin = origin,
		direction = direction,
		size = size,
		range = range,
		attackType = attackType,
		duration = duration,
	})
end

-- Show complete attack visualization (New config-based API)
function HitboxVisualizer.ShowAttackConfig(config: VisualizationConfig)
	if not ENABLED then return end
	
	local duration = config.duration or DURATION
	
	-- Show all components
	HitboxVisualizer.ShowOrigin(config.origin, config.attackType, duration)
	HitboxVisualizer.ShowHitbox(config.origin, config.size, config.attackType, duration)
	HitboxVisualizer.ShowRange(config.origin, config.range, config.attackType, duration)
	HitboxVisualizer.ShowDirectionConfig({
		origin = config.origin,
		direction = config.direction,
		attackType = config.attackType,
		length = config.range,
		duration = duration,
	})
end

-- ========================================
-- UTILITY
-- ========================================

-- Clear all debug visualizations
function HitboxVisualizer.Clear()
	local debugFolder = workspace:FindFirstChild("_CombatDebug")
	if debugFolder then
		debugFolder:ClearAllChildren()
	end
end

-- Toggle hitbox visualization on/off
function HitboxVisualizer.SetEnabled(enabled: boolean)
	ENABLED = enabled
	if not enabled then
		HitboxVisualizer.Clear()
	end
end

function HitboxVisualizer.IsEnabled(): boolean
	return ENABLED
end

return HitboxVisualizer
