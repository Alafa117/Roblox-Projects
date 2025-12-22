--[[
	Module: ValidationHelper
	Type: Validation Utility Module
	Location: ReplicatedStorage.CombatCore.Validation.ValidationHelper
	Path: src/shared/CombatCore/Validation/ValidationHelper.luau
	
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

---Checks if a character is using R6 avatar type
---@param character Model The character model to check
---@return boolean isR6 True if character is R6, false otherwise
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

---Validates if a character is valid for combat (alive, has parts, R6)
---@param character Model? The character model to validate
---@return boolean isValid True if character is valid for combat
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
		-- Note: Logger is imported at module level
		local Logger = require(script.Parent.Parent.Logging.Logger).GetInstance()
		Logger:Warning("Character is not R6! Combat System only supports R6 avatars.", {
			character = character.Name
		})
		return false
	end
	
	return true
end

---Gets Humanoid and HumanoidRootPart from a character
---@param character Model The character model
---@return Humanoid? humanoid The character's Humanoid (nil if not found)
---@return BasePart? rootPart The character's HumanoidRootPart (nil if not found)
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

---Checks if a cooldown has expired and action can be performed
---@param lastUseTime number Last time action was used (os.clock timestamp)
---@param cooldownDuration number Cooldown duration in seconds
---@return boolean isReady True if cooldown has expired
function ValidationHelper.IsCooldownReady(lastUseTime: number, cooldownDuration: number): boolean
	return os.clock() - lastUseTime >= cooldownDuration
end

---Calculates remaining cooldown time
---@param lastUseTime number Last time action was used (os.clock timestamp)
---@param cooldownDuration number Cooldown duration in seconds
---@return number remaining Remaining cooldown time in seconds (0 if ready)
function ValidationHelper.GetCooldownRemaining(lastUseTime: number, cooldownDuration: number): number
	local remaining = cooldownDuration - (os.clock() - lastUseTime)
	return math.max(0, remaining)
end

return ValidationHelper
