--[[
	Module: AnimationsConfig
	Type: Configuration Module
	Location: ReplicatedStorage.CombatCore.Config.AnimationsConfig
	Path: src/shared/CombatCore/Config/AnimationsConfig.luau
	
	Description:
		Configuration for all combat animation IDs.
		Contains animation IDs for attacks, blocks, movement, and reactions.
		
		Phase 3 Refactoring - Extracted from Config.luau
	
	Author: Professional Roblox Scripter
	Created: December 18, 2025 (Phase 3 - Task 1)
--]]

local AnimationsConfig = {}

-- ========================================
-- LIGHT ATTACK ANIMATIONS
-- ========================================

AnimationsConfig.LightAttack = {
	Combo1 = "rbxassetid://placeholder_lightattack_1", -- Placeholder
	Combo2 = "rbxassetid://placeholder_lightattack_2",
	Combo3 = "rbxassetid://placeholder_lightattack_3",
	Combo4 = "rbxassetid://placeholder_lightattack_4",
	Combo5 = "rbxassetid://placeholder_lightattack_5",
	Combo6 = "rbxassetid://placeholder_lightattack_6",
}

-- ========================================
-- STRONG ATTACK ANIMATIONS
-- ========================================

AnimationsConfig.StrongAttack = {
	Default = "rbxassetid://placeholder_strongattack", -- Placeholder
}

-- ========================================
-- BLOCK ANIMATIONS
-- ========================================

AnimationsConfig.Block = {
	Start = "rbxassetid://placeholder_block_start", -- Placeholder
	Hold = "rbxassetid://placeholder_block_hold",
	End = "rbxassetid://placeholder_block_end",
}

-- ========================================
-- DASH ANIMATIONS
-- ========================================

AnimationsConfig.Dash = {
	Default = "rbxassetid://placeholder_dash", -- Placeholder
}

-- ========================================
-- SLIDE ANIMATIONS
-- ========================================

AnimationsConfig.Slide = {
	Default = "rbxassetid://placeholder_slide", -- Placeholder
}

-- ========================================
-- HIT REACTION ANIMATIONS
-- ========================================

AnimationsConfig.Hit = {
	Front = "rbxassetid://placeholder_hit_front", -- Placeholder
	Back = "rbxassetid://placeholder_hit_back",
	Left = "rbxassetid://placeholder_hit_left",
	Right = "rbxassetid://placeholder_hit_right",
}

return table.freeze(AnimationsConfig)
