--[[
	Module: CombatConfig
	Type: Configuration Module (Aggregator)
	Location: ReplicatedStorage.CombatCore.Config.Config
	Path: src/shared/CombatCore/Config/Config.luau
	
	Description:
		Central configuration module for the Combat System.
		Aggregates specialized configuration modules for better organization.
		
		Phase 3 Refactoring - Converted to aggregator pattern
		All config values now split into specialized modules:
		- CombatMechanicsConfig: Attack and block mechanics
		- MovementConfig: Dash and slide mechanics
		- AnimationsConfig: All animation IDs
		- SystemConfig: System-wide settings
		- DebugConfig: Debug visualization settings
		
		Maintains backward compatibility with existing code.
	
	Author: Professional Roblox Scripter
	Created: December 9, 2025
	Refactored: December 18, 2025 (Phase 3 - Task 1)
--]]

-- Import specialized config modules
local CombatMechanicsConfig = require(script.Parent.CombatMechanicsConfig)
local MovementConfig = require(script.Parent.MovementConfig)
local AnimationsConfig = require(script.Parent.AnimationsConfig)
local SystemConfig = require(script.Parent.SystemConfig)
local DebugConfig = require(script.Parent.DebugConfig)

-- Aggregate all configs into main Config table
local CombatConfig = {}

-- ========================================
-- COMBAT MECHANICS (from CombatMechanicsConfig)
-- ========================================

CombatConfig.LightAttack = CombatMechanicsConfig.LightAttack
CombatConfig.StrongAttack = CombatMechanicsConfig.StrongAttack
CombatConfig.Block = CombatMechanicsConfig.Block

-- ========================================
-- MOVEMENT MECHANICS (from MovementConfig)
-- ========================================

CombatConfig.Dash = MovementConfig.Dash
CombatConfig.Slide = MovementConfig.Slide

-- ========================================
-- SYSTEM SETTINGS (from SystemConfig)
-- ========================================

-- Maintain backward compatibility with old structure
CombatConfig.System = {
	EnableDebugMode = SystemConfig.EnableDebugMode,
}

-- ========================================
-- DEBUG VISUALIZATION (from DebugConfig)
-- ========================================

-- Maintain backward compatibility with old structure
CombatConfig.Debug = {
	ShowHitboxes = DebugConfig.ShowHitboxes,
	HitboxTransparency = DebugConfig.HitboxTransparency,
	HitboxDuration = DebugConfig.HitboxDuration,
	
	-- Use centralized color configuration from DebugConfig
	HitboxColors = DebugConfig.Colors,
	
	ShowHitboxOrigin = true,
	ShowHitDirection = true,
	ShowHitRange = true,
}

-- ========================================
-- ANIMATIONS (from AnimationsConfig)
-- ========================================

-- Convert from specialized structure to old structure for backward compatibility
CombatConfig.Animations = {
	LightAttack = {
		[1] = AnimationsConfig.LightAttack.Combo1,
		[2] = AnimationsConfig.LightAttack.Combo2,
		[3] = AnimationsConfig.LightAttack.Combo3,
		[4] = AnimationsConfig.LightAttack.Combo4,
		[5] = AnimationsConfig.LightAttack.Combo5,
		[6] = AnimationsConfig.LightAttack.Combo6,
	},
	StrongAttack = {
		Release = AnimationsConfig.StrongAttack.Default,
	},
	Block = {
		Start = AnimationsConfig.Block.Start,
		Hold = AnimationsConfig.Block.Hold,
		End = AnimationsConfig.Block.End,
		Break = "rbxassetid://0", -- Not in new config, kept for compatibility
	},
	Dash = {
		Forward = AnimationsConfig.Dash.Default,
		Backward = AnimationsConfig.Dash.Default,
		Left = AnimationsConfig.Dash.Default,
		Right = AnimationsConfig.Dash.Default,
	},
	Slide = {
		Start = AnimationsConfig.Slide.Default,
	},
	Hit = {
		Light = AnimationsConfig.Hit.Front,
		Heavy = AnimationsConfig.Hit.Back,
		Blocked = AnimationsConfig.Hit.Left,
	},
}

-- ========================================
-- UTILITIES
-- ========================================

-- Deep freeze to prevent accidental modifications
local function DeepFreeze(tbl)
	table.freeze(tbl)
	for _, v in pairs(tbl) do
		if type(v) == "table" then
			DeepFreeze(v)
		end
	end
	return tbl
end

return DeepFreeze(CombatConfig)
