--[[
	Module: MovementConfig
	Type: Configuration Module
	Location: ReplicatedStorage.CombatCore.Config.MovementConfig
	Path: src/shared/CombatCore/Config/MovementConfig.luau
	
	Description:
		Configuration for movement mechanics (dash, slide).
		Contains speed, duration, cooldown, and distance parameters.
		
		Phase 3 Refactoring - Extracted from Config.luau
	
	Author: Professional Roblox Scripter
	Created: December 18, 2025 (Phase 3 - Task 1)
--]]

local MovementConfig = {}

-- ========================================
-- DASH
-- ========================================

MovementConfig.Dash = {
	Speed = 60, -- Smoother speed for natural movement
	Duration = 0.45, -- Balanced duration
	Cooldown = 2.0, -- Shorter cooldown for mobility
	Distance = 30, -- Reduced distance for better control
	FrictionMultiplier = 0.3, -- Light friction for smooth natural deceleration
	InvulnerabilityFrames = 0.25, -- Better i-frames
}

-- ========================================
-- SLIDE
-- ========================================

MovementConfig.Slide = {
	Speed = 55, -- Slightly faster for smoother feel
	Duration = 0.4, -- Shorter than Dash (0.45s)
	Cooldown = 1.5, -- Short cooldown
	Distance = 22, -- Slightly less than Dash, balanced
	FrictionMultiplier = 0.55, -- Smoother friction for natural deceleration
}

return table.freeze(MovementConfig)
