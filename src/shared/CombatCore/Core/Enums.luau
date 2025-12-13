--[[
	Module: CombatEnums
	Type: Enumeration Module
	Location: ReplicatedStorage.CombatCore.Core.Enums
	Path: src/shared/CombatCore/Core/Enums.luau
	
	Description:
		Centralized enumerations for the Combat System.
		Provides type-safe constants for combat states, actions, and results.
		Using enums prevents magic strings and improves code maintainability.
	
	Author: Professional Roblox Scripter
	Created: December 9, 2025
--]]

local Enums = {}

-- ========================================
-- COMBAT STATES
-- ========================================

Enums.CombatState = {
	Idle = "Idle",
	Attacking = "Attacking",
	Blocking = "Blocking",
	Dashing = "Dashing",
	Sliding = "Sliding",
	Stunned = "Stunned",
	Dead = "Dead",
}

-- ========================================
-- ATTACK TYPES
-- ========================================

Enums.AttackType = {
	LightAttack = "LightAttack",
	StrongAttack = "StrongAttack",
}

-- ========================================
-- ACTION TYPES
-- ========================================

Enums.ActionType = {
	M1 = "M1", -- Light Attack
	M2 = "M2", -- Strong Attack
	Q = "Q", -- Dash
	C = "C", -- Slide
	F = "F", -- Block
}

-- ========================================
-- HIT RESULTS
-- ========================================

Enums.HitResult = {
	Success = "Success",
	Blocked = "Blocked",
	PerfectBlock = "PerfectBlock",
}

-- ========================================
-- NETWORK EVENTS
-- ========================================

Enums.NetworkEvent = {
	-- Client to Server
	RequestAction = "RequestAction",
	RequestBlock = "RequestBlock",
	RequestDash = "RequestDash",
	RequestSlide = "RequestSlide",
	CancelDash = "CancelDash", -- Cancel active dash
	CancelSlide = "CancelSlide", -- Cancel active slide
	
	-- Server to Client
	ActionResult = "ActionResult",
	StateChanged = "StateChanged",
	TakeDamage = "TakeDamage",
	ApplyKnockback = "ApplyKnockback",
	PlayAnimation = "PlayAnimation",
	PlayVFX = "PlayVFX",
}

-- ========================================
-- LOG LEVELS
-- ========================================

Enums.LogLevel = {
	Debug = 1,
	Info = 2,
	Warning = 3,
	Error = 4,
	Critical = 5,
}

-- ========================================
-- DIRECTIONS
-- ========================================

Enums.Direction = {
	Forward = "Forward",
	Backward = "Backward",
	Left = "Left",
	Right = "Right",
}

-- ========================================
-- ANIMATION PRIORITY
-- ========================================

Enums.AnimationPriority = {
	Idle = Enum.AnimationPriority.Idle,
	Movement = Enum.AnimationPriority.Movement,
	Action = Enum.AnimationPriority.Action,
	Action2 = Enum.AnimationPriority.Action2,
	Action3 = Enum.AnimationPriority.Action3,
	Action4 = Enum.AnimationPriority.Action4,
	Core = Enum.AnimationPriority.Core,
}

-- ========================================
-- VALIDATION
-- ========================================

-- Validates if a value exists in an enum
function Enums.IsValid(enumTable: {[string]: any}, value: any): boolean
	for _, enumValue in pairs(enumTable) do
		if enumValue == value then
			return true
		end
	end
	return false
end

-- ========================================
-- FREEZE AND RETURN
-- ========================================

local function DeepFreeze(tbl)
	table.freeze(tbl)
	for _, v in pairs(tbl) do
		if type(v) == "table" and not table.isfrozen(v) then
			DeepFreeze(v)
		end
	end
	return tbl
end

return DeepFreeze(Enums)
