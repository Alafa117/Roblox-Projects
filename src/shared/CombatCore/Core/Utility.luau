--[[
	Module: CombatUtility
	Type: Utility Module (Legacy Facade)
	Location: ReplicatedStorage.CombatCore.Core.Utility
	Path: src/shared/CombatCore/Core/Utility.luau
	
	Description:
		Facade module that delegates to specialized helper modules.
		Maintains backward compatibility while promoting clean architecture.
		
		Delegates to:
		- ValidationHelper: Character/state validation, cooldowns
		- PhysicsHelper: Knockback, ragdoll effects
		- SpatialHelper: Distance, direction, hitbox detection
		
	Migration Note:
		New code should use specialized helpers directly for better clarity.
		This module exists for backward compatibility with existing code.
	
	Author: Professional Roblox Scripter
	Created: December 9, 2025
	Refactored: December 14, 2025 - Extracted SpatialHelper
--]]

-- Module Imports
local ValidationHelper = require(script.Parent.ValidationHelper)
local PhysicsHelper = require(script.Parent.PhysicsHelper)
local SpatialHelper = require(script.Parent.SpatialHelper)

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
-- SPATIAL CALCULATIONS (delegates to SpatialHelper)
-- ========================================

function Utility.GetDirectionTo(fromChar: Model, toChar: Model): Vector3?
	return SpatialHelper.GetDirectionTo(fromChar, toChar)
end

function Utility.IsInFront(attacker: Model, target: Model, maxAngle: number?): boolean
	return SpatialHelper.IsInFront(attacker, target, maxAngle)
end

function Utility.GetPlayersInRadius(origin: Vector3, radius: number, ignore: any): {Player | Model}
	return SpatialHelper.GetPlayersInRadius(origin, radius, ignore)
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
