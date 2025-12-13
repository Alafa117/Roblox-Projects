--[[
	Module: CombatTypes
	Type: Type Definitions Module
	Location: ReplicatedStorage.Combat_System.Core.Types
	Path: src/shared/Combat_System/Core/Types.luau
	
	Description:
		Centralized type definitions for the Combat System.
		Provides strict typing for better autocomplete, error detection, and code safety.
		All modules should reference these types for consistency.
	
	Author: Professional Roblox Scripter
	Created: December 9, 2025
--]]

export type CombatState = "Idle" | "Attacking" | "Blocking" | "Dashing" | "Sliding" | "Stunned" | "Dead"

export type AttackType = "LightAttack" | "StrongAttack"

export type ActionType = "M1" | "M2" | "Q" | "C" | "F"

export type HitResult = "Success" | "Blocked" | "PerfectBlock"

export type Direction = "Forward" | "Backward" | "Left" | "Right"

export type LogLevel = number

-- ========================================
-- PLAYER COMBAT DATA
-- ========================================

export type PlayerCombatData = {
	Player: Player,
	Character: Model?,
	Humanoid: Humanoid?,
	HumanoidRootPart: BasePart?,
	
	CurrentState: CombatState,
	PreviousState: CombatState?,
	
	ComboCount: number,
	LastAttackTime: number,
	
	-- Cooldowns
	Cooldowns: {
		M1: number,
		M2: number,
		Q: number,
		C: number,
		F: number,
	},
	
	-- Status Effects
	IsInvulnerable: boolean,
	IsStunned: boolean,
	StunEndTime: number?,
	
	-- Block Data
	IsBlocking: boolean,
	BlockStartTime: number?,
	
	-- Stats (Future implementation)
	Health: number?,
	MaxHealth: number?,
}

-- ========================================
-- ATTACK DATA
-- ========================================

export type AttackData = {
	Attacker: Player,
	Victim: Player?,
	AttackType: AttackType,
	Damage: number,
	Knockback: number,
	Range: number,
	HitboxSize: Vector3,
	ComboCount: number?,
	Timestamp: number,
}

-- ========================================
-- HIT DATA
-- ========================================

export type HitData = {
	Attacker: Player,
	Victim: Player,
	Damage: number,
	ActualDamage: number, -- After reductions
	Knockback: Vector3,
	HitResult: HitResult,
	HitPosition: Vector3,
	Timestamp: number,
}

-- ========================================
-- VALIDATION RESULT
-- ========================================

export type ValidationResult = {
	Success: boolean,
	ErrorMessage: string?,
	ErrorCode: string?,
}

-- ========================================
-- LOGGER CONFIG
-- ========================================

export type LoggerConfig = {
	MinLevel: LogLevel,
	EnableTimestamp: boolean,
	EnableStackTrace: boolean,
	OutputToConsole: boolean,
}

-- ========================================
-- COMBAT CONFIG SECTIONS
-- ========================================

export type LightAttackConfig = {
	Damage: number,
	Cooldown: number,
	ComboWindow: number,
	MaxComboCount: number,
	Range: number,
	HitboxSize: Vector3,
	Knockback: number,
	StunDuration: number,
}

export type StrongAttackConfig = {
	Damage: number,
	Cooldown: number,
	Range: number,
	HitboxSize: Vector3,
	Knockback: number,
	StunDuration: number,
}

export type BlockConfig = {
	DamageReduction: number,
	Cooldown: number,
	MaxBlockDuration: number,
	BlockBreakStunDuration: number,
	PerfectBlockWindow: number,
	PerfectBlockReduction: number,
}

export type DashConfig = {
	Speed: number,
	Duration: number,
	Cooldown: number,
	Distance: number,
	InvulnerabilityFrames: number,
}

export type SlideConfig = {
	Speed: number,
	Duration: number,
	Cooldown: number,
	Distance: number,
	FrictionMultiplier: number,
}

return {}
