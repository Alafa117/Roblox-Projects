--[[
	Module: CombatConfig
	Type: Configuration Module
	Location: ReplicatedStorage.Combat_System.Core.Config
	Path: src/shared/Combat_System/Core/Config.luau
	
	Description:
		Centralized configuration for the Combat System.
		Contains all combat parameters, cooldowns, damage values, and system settings.
		Modifying values here affects the entire combat system behavior.
	
	Author: Professional Roblox Scripter
	Created: December 9, 2025
--]]

local CombatConfig = {}

-- ========================================
-- COMBAT MECHANICS
-- ========================================

CombatConfig.LightAttack = {
	Damage = 8, -- Balanced light attack damage
	Cooldown = 0.5, -- Fast cooldown for fluid combos
	FinisherCooldown = 3.0, -- Reduced finisher cooldown
	ComboWindow = 1.5, -- Tighter combo timing
	MaxComboCount = 6, -- Maximum combo hits
	Range = 7, -- Balanced melee range
	HitboxSize = Vector3.new(6, 6, 6), -- Smaller hitbox for precision
	Knockback = 8, -- Better knockback
	StunDuration = 0.4, -- Slightly longer stun
	-- Finisher (6th combo) settings
	FinisherKnockback = 35, -- Powerful knockback on 6th hit
	FinisherRagdollDuration = 1.5, -- 1.5 second ragdoll on 6th hit
}

CombatConfig.StrongAttack = {
	Damage = 20, -- Heavy attack balanced damage
	Cooldown = 2.5, -- Reasonable cooldown
	Range = 9, -- Balanced heavy attack reach
	HitboxSize = Vector3.new(8, 8, 8), -- Balanced hitbox
	Knockback = 25, -- Strong knockback
	StunDuration = 1.2, -- Significant stun
	RagdollDuration = 2.0, -- 2 second ragdoll effect
}

CombatConfig.Block = {
	DamageReduction = 0.65, -- 65% damage reduction (balanced)
	Cooldown = 0.5, -- Short cooldown
	MaxBlockDuration = 8.0, -- Generous block time
	BlockBreakStunDuration = 1.8, -- Punish for block break
	PerfectBlockWindow = 0.5, -- 500ms window for human reaction time
	PerfectBlockReduction = 0.98, -- 98% damage reduction on perfect block
}

CombatConfig.Dash = {
	Speed = 60, -- Smoother speed for natural movement
	Duration = 0.45, -- Balanced duration
	Cooldown = 2.0, -- Shorter cooldown for mobility
	Distance = 30, -- Reduced distance for better control
	FrictionMultiplier = 0.3, -- Light friction for smooth natural deceleration
	InvulnerabilityFrames = 0.25, -- Better i-frames
}

CombatConfig.Slide = {
	Speed = 55, -- Slightly faster for smoother feel
	Duration = 0.4, -- Shorter than Dash (0.45s)
	Cooldown = 1.5, -- Short cooldown
	Distance = 22, -- Slightly less than Dash, balanced
	FrictionMultiplier = 0.55, -- Smoother friction for natural deceleration
}

-- ========================================
-- SYSTEM SETTINGS
-- ========================================

CombatConfig.System = {
	EnableDebugMode = true, -- Enable debug logs
}

-- ========================================
-- ANIMATION IDS (Replace with your animation IDs)
-- ========================================

CombatConfig.Animations = {
	LightAttack = {
		[1] = "rbxassetid://0", -- Combo 1
		[2] = "rbxassetid://0", -- Combo 2
		[3] = "rbxassetid://0", -- Combo 3
		[4] = "rbxassetid://0", -- Combo 4
		[5] = "rbxassetid://0", -- Combo 5
		[6] = "rbxassetid://0", -- Combo 6 (finisher)
	},
	StrongAttack = {
		Release = "rbxassetid://0", -- Instant attack animation
	},
	Block = {
		Start = "rbxassetid://0",
		Hold = "rbxassetid://0",
		End = "rbxassetid://0",
		Break = "rbxassetid://0",
	},
	Dash = {
		Forward = "rbxassetid://0",
		Backward = "rbxassetid://0",
		Left = "rbxassetid://0",
		Right = "rbxassetid://0",
	},
	Slide = {
		Start = "rbxassetid://0",
	},
	Hit = {
		Light = "rbxassetid://0",
		Heavy = "rbxassetid://0",
		Blocked = "rbxassetid://0",
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
