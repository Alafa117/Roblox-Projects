--[[
	Module: CombatUtility
	Type: Utility Module (Legacy Wrapper)
	Location: ReplicatedStorage.CombatCore.Core.Utility
	Path: src/shared/CombatCore/Core/Utility.luau
	
	Description:
		Centralized utility module for combat system operations.
		Delegates some operations to specialized helper modules:
		- ValidationHelper for character/state validation
		- PhysicsHelper for knockback/ragdoll physics
		
		Provides spatial calculations, hit detection, and utility functions.
	
	Author: Professional Roblox Scripter
	Created: December 9, 2025
	Refactored: December 11, 2025
--]]

-- Services
local Players = game:GetService("Players")

-- Module Imports
local ValidationHelper = require(script.Parent.ValidationHelper)
local PhysicsHelper = require(script.Parent.PhysicsHelper)

-- Utility Module (Legacy Wrapper)
local Utility = {}

-- ========================================
-- CHARACTER VALIDATION
-- ========================================

-- CHARACTER VALIDATION (delegates to ValidationHelper)
function Utility.IsCharacterValid(character: Model?): boolean
	return ValidationHelper.IsCharacterValid(character)
end

function Utility.GetHumanoid(character: Model): Humanoid?
	local humanoid, _ = ValidationHelper.GetCharacterComponents(character)
	return humanoid
end

function Utility.GetRootPart(character: Model): BasePart?
	local _, rootPart = ValidationHelper.GetCharacterComponents(character)
	return rootPart
end

-- Checks if character is an R6 model
function Utility.IsR6Character(character: Model): boolean
	if not character then
		return false
	end
	
	-- R6 has these specific parts
	local r6Parts = {"Left Arm", "Right Arm", "Left Leg", "Right Leg", "Torso"}
	for _, partName in ipairs(r6Parts) do
		if not character:FindFirstChild(partName) then
			return false
		end
	end
	
	return true
end

-- ========================================
-- DISTANCE & POSITIONING
-- ========================================

-- Gets direction vector from one character to another
function Utility.GetDirectionTo(fromChar: Model, toChar: Model): Vector3?
	local fromRoot = Utility.GetRootPart(fromChar)
	local toRoot = Utility.GetRootPart(toChar)
	
	if not fromRoot or not toRoot then
		return nil
	end
	
	return (toRoot.Position - fromRoot.Position).Unit
end

-- Checks if target is in front of attacker
function Utility.IsInFront(attacker: Model, target: Model, maxAngle: number?): boolean
	maxAngle = maxAngle or 90 -- Default 90 degrees
	
	local attackerRoot = Utility.GetRootPart(attacker)
	local targetRoot = Utility.GetRootPart(target)
	
	if not attackerRoot or not targetRoot then
		return false
	end
	
	local direction = (targetRoot.Position - attackerRoot.Position).Unit
	local lookVector = attackerRoot.CFrame.LookVector
	
	local dotProduct = direction:Dot(lookVector)
	local angle = math.deg(math.acos(dotProduct))
	
	return angle <= maxAngle
end

-- ========================================
-- HITBOX DETECTION
-- ========================================

-- Performs spherical hitbox detection (more optimized)
-- NOTE: Returns characters (Model), not just players - works with NPCs/Dummies too
function Utility.GetPlayersInRadius(origin: Vector3, radius: number, ignore: any): {Player | Model}
	local hitResults = {}
	
	local overlapParams = OverlapParams.new()
	overlapParams.FilterDescendantsInstances = ignore or {}
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	
	local partsInRadius = workspace:GetPartBoundsInRadius(origin, radius, overlapParams)
	
	local checkedCharacters = {}
	for _, part in ipairs(partsInRadius) do
		local character = part.Parent
		if character and not checkedCharacters[character] then
			checkedCharacters[character] = true
			
			-- Check if it's a valid character (player OR NPC/Dummy)
			if Utility.IsCharacterValid(character) then
				local rootPart = Utility.GetRootPart(character)
				if rootPart and (rootPart.Position - origin).Magnitude <= radius then
					-- Try to get player, but also accept NPCs
					local player = Players:GetPlayerFromCharacter(character)
					if player then
						table.insert(hitResults, player)
					else
						-- It's an NPC/Dummy - add it as a "fake player" with character reference
						-- This allows damage to work on NPCs
						table.insert(hitResults, character)
					end
				end
			end
		end
	end
	
	return hitResults
end

-- ========================================
-- COOLDOWN MANAGEMENT (delegates to ValidationHelper)
-- ========================================

function Utility.IsCooldownReady(lastUseTime: number, cooldownDuration: number): boolean
	return ValidationHelper.IsCooldownReady(lastUseTime, cooldownDuration)
end

function Utility.GetCooldownRemaining(lastUseTime: number, cooldownDuration: number): number
	return ValidationHelper.GetCooldownRemaining(lastUseTime, cooldownDuration)
end

-- ========================================
-- KNOCKBACK & PHYSICS (delegates to PhysicsHelper)
-- ========================================

function Utility.ApplyKnockback(character: Model, direction: Vector3, force: number)
	PhysicsHelper.ApplyKnockback(character, direction, force)
end

function Utility.ApplyRagdoll(character: Model, duration: number)
	PhysicsHelper.ApplyRagdoll(character, duration)
end

return Utility
