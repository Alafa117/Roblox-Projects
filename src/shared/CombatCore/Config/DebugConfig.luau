--[[
	Module: DebugConfig
	Type: Configuration Module
	Location: ReplicatedStorage.CombatCore.Config.DebugConfig
	Path: src/shared/CombatCore/Config/DebugConfig.luau
	
	Description:
		Configuration for debug visualization settings.
		Contains hitbox visualization, colors, transparency, and duration parameters.
		
		Phase 3 Refactoring - Extracted from Config.luau
	
	Author: Professional Roblox Scripter
	Created: December 18, 2025 (Phase 3 - Task 1)
--]]

local DebugConfig = {}

-- ========================================
-- HITBOX VISUALIZATION
-- ========================================

DebugConfig.ShowHitboxes = true -- Toggle hitbox visualization

-- ========================================
-- DEBUG LOGGING FLAGS
-- ========================================

-- Categorized debug logging toggles (used by Logger)
DebugConfig.EnableClientDebug = true      -- Client-side debug logs
DebugConfig.EnableServerDebug = true      -- Server-side debug logs
DebugConfig.EnableMechanicDebug = true    -- Mechanic execution debug logs
DebugConfig.EnableValidationDebug = true  -- Validation debug logs

-- Hitbox visualization settings
DebugConfig.HitboxTransparency = 0.95 -- Almost transparent (wireframe style)
DebugConfig.HitboxDuration = 0.5 -- Display duration in seconds
DebugConfig.EdgeThickness = 0.08 -- Thickness of hitbox edges
DebugConfig.MovementTrailInterval = 0.05 -- Interval for movement trail boxes (seconds)
DebugConfig.MovementTrailTransparency = 0.85 -- Transparency for trail boxes

-- ========================================
-- DEBUG COLORS
-- ========================================

-- Colors for different attack types (hitbox visualization)
DebugConfig.Colors = {
	LightAttack = Color3.fromRGB(255, 100, 100),  -- Light Red (rojo claro)
	StrongAttack = Color3.fromRGB(220, 20, 60),   -- Crimson Red (rojo crimson)
	Dash = Color3.fromRGB(200, 200, 200),         -- Light Gray (gris claro)
	Slide = Color3.fromRGB(80, 80, 80),           -- Dark Gray (gris oscuro)
	Block = Color3.fromRGB(100, 100, 255),        -- Blue
	Default = Color3.fromRGB(255, 255, 255),      -- White (fallback)
}

-- Hit result colors
DebugConfig.HitConfirmColor = Color3.fromRGB(0, 255, 0)    -- Green for confirmed hits
DebugConfig.MissColor = Color3.fromRGB(255, 255, 0)        -- Yellow for misses

-- Additional transparencies (if needed per-type)
DebugConfig.HitConfirmTransparency = 0.5
DebugConfig.MissTransparency = 0.8

-- Additional durations (if needed per-type)
DebugConfig.HitConfirmDuration = 0.3
DebugConfig.MissDuration = 0.2

return table.freeze(DebugConfig)
