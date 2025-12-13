--[[
	Module: ValidationHelper
	Type: Validation Utility Module
	Location: ReplicatedStorage.Combat_System.Core.ValidationHelper
	Path: src/shared/Combat_System/Core/ValidationHelper.luau
	
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
-- PLAYER VALIDATION
-- ========================================

function ValidationHelper.IsPlayerValid(player: Player): boolean
	if not player or not player:IsDescendantOf(game) then
		return false
	end
	
	if not player.Character then
		return false
	end
	
	return ValidationHelper.IsCharacterValid(player.Character)
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
