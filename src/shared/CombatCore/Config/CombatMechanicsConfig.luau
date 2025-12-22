--[[
	Module: CombatMechanicsConfig
	Type: Configuration Module
	Location: ReplicatedStorage.CombatCore.Config.CombatMechanicsConfig
	Path: src/shared/CombatCore/Config/CombatMechanicsConfig.luau
	
	Description:
		Configuration for combat mechanics (attacks, block).
		Contains damage values, cooldowns, ranges, and combat parameters.
		
		Phase 3 Refactoring - Extracted from Config.luau
	
	Author: Professional Roblox Scripter
	Created: December 18, 2025 (Phase 3 - Task 1)
--]]

local CombatMechanicsConfig = {}

-- ========================================
-- LIGHT ATTACK
-- ========================================

CombatMechanicsConfig.LightAttack = {
	Damage = 8, -- Balanced light attack damage
	Cooldown = 0.6, -- Slightly longer to prevent M2 overlap
	FinisherCooldown = 3.0, -- Reduced finisher cooldown
	ComboWindow = 1.5, -- Tighter combo timing
	MaxComboCount = 6, -- Maximum combo hits
	Range = 7, -- Balanced melee range
	HitboxSize = Vector3.new(6, 6, 6), -- Smaller hitbox for precision
	Knockback = 8, -- Better knockback
	StunDuration = 0.3, -- Reduced stun to allow counterplay
	-- Finisher (6th combo) settings
	FinisherKnockback = 35, -- Powerful knockback on 6th hit
	FinisherRagdollDuration = 1.5, -- 1.5 second ragdoll on 6th hit
}

-- ========================================
-- STRONG ATTACK
-- ========================================

CombatMechanicsConfig.StrongAttack = {
	Damage = 20, -- Heavy attack balanced damage
	Cooldown = 3.0, -- Longer cooldown to prevent M1/M2 overlap
	Range = 9, -- Balanced heavy attack reach
	HitboxSize = Vector3.new(8, 8, 8), -- Balanced hitbox
	Knockback = 25, -- Strong knockback
	StunDuration = 0.8, -- Reduced stun for better flow
	RagdollDuration = 1.5, -- Reduced ragdoll for better pacing
}

-- ========================================
-- BLOCK
-- ========================================

CombatMechanicsConfig.Block = {
	DamageReduction = 0.65, -- 65% damage reduction (balanced)
	Cooldown = 0.5, -- Short cooldown
	BlockBreakStunDuration = 1.8, -- Punish for block break
	PerfectBlockWindow = 0.5, -- 500ms window for human reaction time
	PerfectBlockReduction = 0.98, -- 98% damage reduction on perfect block
}

return table.freeze(CombatMechanicsConfig)
