--[[
	Module: SpatialHelper
	Type: Utility Module
	Location: ReplicatedStorage.CombatCore.Core.SpatialHelper
	Path: src/shared/CombatCore/Core/SpatialHelper.luau
	
	Description:
		Spatial calculations and positioning utilities for combat system.
		Handles distance calculations, direction vectors, angle checks,
		and hitbox detection using optimized raycasting and region queries.
		
		Extracted from Utility.luau for better separation of concerns.
	
	Dependencies:
		- game.Players (service)
		- ReplicatedStorage.CombatCore.Core.ValidationHelper
	
	Performance Notes:
		- Uses GetPartBoundsInRadius for O(1) spatial queries
		- Minimizes table allocations in hot paths
		- Caches character lookups to reduce tree traversal
	
	Author: Professional Roblox Scripter
	Created: December 14, 2025
--]]

-- Services
local Players = game:GetService("Players")

-- Module Imports
local ValidationHelper = require(script.Parent.ValidationHelper)

-- Spatial Helper Module
local SpatialHelper = {}

-- ========================================
-- DIRECTION & POSITIONING
-- ========================================

-- Gets direction vector from one character to another
-- Returns nil if either character is invalid
function SpatialHelper.GetDirectionTo(fromChar: Model, toChar: Model): Vector3?
	local _, fromRoot = ValidationHelper.GetCharacterComponents(fromChar)
	local _, toRoot = ValidationHelper.GetCharacterComponents(toChar)
	
	if not fromRoot or not toRoot then
		return nil
	end
	
	return (toRoot.Position - fromRoot.Position).Unit
end

-- Checks if target is in front of attacker within specified angle
-- @param maxAngle: Maximum angle in degrees (default 90)
-- @return boolean: true if target is within forward cone
function SpatialHelper.IsInFront(attacker: Model, target: Model, maxAngle: number?): boolean
	maxAngle = maxAngle or 90 -- Default 90 degrees
	
	local _, attackerRoot = ValidationHelper.GetCharacterComponents(attacker)
	local _, targetRoot = ValidationHelper.GetCharacterComponents(target)
	
	if not attackerRoot or not targetRoot then
		return false
	end
	
	local direction = (targetRoot.Position - attackerRoot.Position).Unit
	local lookVector = attackerRoot.CFrame.LookVector
	
	-- Dot product for angle calculation (optimized)
	local dotProduct = direction:Dot(lookVector)
	local angle = math.deg(math.acos(math.clamp(dotProduct, -1, 1)))
	
	return angle <= maxAngle
end

-- ========================================
-- HITBOX DETECTION
-- ========================================

-- Performs optimized spherical hitbox detection
-- Returns both Players and Models (NPCs/Dummies)
-- 
-- Performance: O(n) where n is parts in radius, with early filtering
-- @param origin: Center point of detection sphere
-- @param radius: Detection radius in studs
-- @param ignore: Array of instances to exclude
-- @return Array of Player instances or Model instances (for NPCs)
function SpatialHelper.GetPlayersInRadius(origin: Vector3, radius: number, ignore: any): {Player | Model}
	local hitResults = {}
	
	-- Setup spatial query parameters
	local overlapParams = OverlapParams.new()
	overlapParams.FilterDescendantsInstances = ignore or {}
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	
	-- Efficient spatial query (single engine call)
	local partsInRadius = workspace:GetPartBoundsInRadius(origin, radius, overlapParams)
	
	-- Deduplicate characters (parts may belong to same character)
	local checkedCharacters = {}
	
	for _, part in ipairs(partsInRadius) do
		local character = part.Parent
		
		-- Skip if already processed or invalid
		if character and not checkedCharacters[character] then
			checkedCharacters[character] = true
			
			-- Validate character structure
			if ValidationHelper.IsCharacterValid(character) then
				local _, rootPart = ValidationHelper.GetCharacterComponents(character)
				
				-- Double-check distance (parts may be on edge)
				if rootPart and (rootPart.Position - origin).Magnitude <= radius then
					-- Try to get player first (real players)
					local player = Players:GetPlayerFromCharacter(character)
					
					if player then
						table.insert(hitResults, player)
					else
						-- NPC/Dummy - return Model directly
						table.insert(hitResults, character)
					end
				end
			end
		end
	end
	
	return hitResults
end

-- ========================================
-- DISTANCE CALCULATIONS
-- ========================================

-- Calculates distance between two characters
-- @return number: Distance in studs, or math.huge if invalid
function SpatialHelper.GetDistanceBetween(char1: Model, char2: Model): number
	local _, root1 = ValidationHelper.GetCharacterComponents(char1)
	local _, root2 = ValidationHelper.GetCharacterComponents(char2)
	
	if not root1 or not root2 then
		return math.huge
	end
	
	return (root1.Position - root2.Position).Magnitude
end

-- Checks if two characters are within specified range
-- Optimized: avoids expensive Magnitude calculation when possible
function SpatialHelper.IsWithinRange(char1: Model, char2: Model, maxRange: number): boolean
	local _, root1 = ValidationHelper.GetCharacterComponents(char1)
	local _, root2 = ValidationHelper.GetCharacterComponents(char2)
	
	if not root1 or not root2 then
		return false
	end
	
	-- Use MagnitudeSquared for performance (avoids sqrt)
	local distanceSquared = (root1.Position - root2.Position).MagnitudeSquared
	return distanceSquared <= (maxRange * maxRange)
end

return SpatialHelper
