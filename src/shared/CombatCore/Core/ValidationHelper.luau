--[[
	Module: ValidationHelper
	Type: Validation Utility Module
	Location: ReplicatedStorage.CombatCore.Core.ValidationHelper
	Path: src/shared/CombatCore/Core/ValidationHelper.luau
	
	Description:
		Centralized validation logic for combat actions.
		Handles character validation, state checks, and cooldown validation.
		Separated from CombatService for better organization.
	
	Author: Professional Roblox Scripter
	Created: December 11, 2025
--]]

-- ValidationHelper Module
local ValidationHelper = {}

-- ========================================
-- CHARACTER VALIDATION
-- ========================================

function ValidationHelper.IsR6Avatar(character: Model): boolean
	if not character then
		return false
	end
	
	-- R6 avatars have specific body parts
	local hasR6Parts = character:FindFirstChild("Torso") 
		and character:FindFirstChild("Left Arm") 
		and character:FindFirstChild("Right Arm")
		and character:FindFirstChild("Left Leg")
		and character:FindFirstChild("Right Leg")
		and character:FindFirstChild("Head")
	
	return hasR6Parts ~= nil
end

function ValidationHelper.IsCharacterValid(character: Model?): boolean
	if not character then
		return false
	end
	
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false
	end
	
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart or not rootPart:IsA("BasePart") then
		return false
	end
	
	-- Validate R6 avatar (Combat System only supports R6)
	if not ValidationHelper.IsR6Avatar(character) then
		warn("[ValidationHelper] Character is not R6! Combat System only supports R6 avatars.")
		return false
	end
	
	return true
end

function ValidationHelper.GetCharacterComponents(character: Model): (Humanoid?, BasePart?)
	if not character then
		return nil, nil
	end
	
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	
	if rootPart and not rootPart:IsA("BasePart") then
		rootPart = nil
	end
	
	return humanoid, rootPart
end

-- ========================================
-- COOLDOWN VALIDATION
-- ========================================

function ValidationHelper.IsCooldownReady(lastUseTime: number, cooldownDuration: number): boolean
	return os.clock() - lastUseTime >= cooldownDuration
end

function ValidationHelper.GetCooldownRemaining(lastUseTime: number, cooldownDuration: number): number
	local remaining = cooldownDuration - (os.clock() - lastUseTime)
	return math.max(0, remaining)
end

return ValidationHelper
