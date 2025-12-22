--[[
	Module: CombatTypes
	Type: Type Definitions Module
	Location: ReplicatedStorage.CombatCore.Data.Types
	Path: src/shared/CombatCore/Data/Types.luau
	
	Description:
		Centralized type definitions for the Combat System.
		Provides strict typing for better autocomplete, error detection, and code safety.
		All modules should reference these types for consistency.
	
	Author: Professional Roblox Scripter
	Created: December 9, 2025
--]]

---@alias CombatState "Idle" | "Attacking" | "LightAttacking" | "StrongAttacking" | "Blocking" | "Dashing" | "Sliding" | "Stunned" | "Dead"
export type CombatState = "Idle" | "Attacking" | "Blocking" | "Dashing" | "Sliding" | "Stunned" | "Dead"

---@alias AttackType "LightAttack" | "StrongAttack"
export type AttackType = "LightAttack" | "StrongAttack"

---@alias ActionType "M1" | "M2" | "Q" | "C" | "F"
export type ActionType = "M1" | "M2" | "Q" | "C" | "F"

---@alias HitResult "Success" | "Blocked" | "PerfectBlock"
export type HitResult = "Success" | "Blocked" | "PerfectBlock"

---@alias Direction "Forward" | "Backward" | "Left" | "Right"
export type Direction = "Forward" | "Backward" | "Left" | "Right"

---@alias LogLevel number
export type LogLevel = number

-- ========================================
-- PLAYER COMBAT DATA
-- ========================================

---@class PlayerCombatData
---@field Player Player The player instance
---@field Character Model? The character model
---@field Humanoid Humanoid? The humanoid instance
---@field HumanoidRootPart BasePart? The root part
---@field CurrentState CombatState Current combat state
---@field PreviousState CombatState? Previous combat state
---@field ComboCount number Current combo count (0-6)
---@field LastAttackTime number Last attack timestamp (os.clock)
---@field Cooldowns table<ActionType, number> Cooldown timestamps per action
---@field IsInvulnerable boolean Invulnerability flag
---@field IsStunned boolean Stun status
---@field StunEndTime number? When stun expires (os.clock)
---@field StunTimer thread? Stun cleanup coroutine
---@field IsBlocking boolean Block status
---@field BlockStartTime number? When block started (os.clock)
---@field Health number? Current health
---@field MaxHealth number? Maximum health
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
---@class AttackData
---@field Attacker Player The attacking player
---@field Victim Player? The target victim (optional for hitbox detection)
---@field AttackType AttackType Type of attack (LightAttack/StrongAttack)
---@field Damage number Base damage amount
---@field Knockback number Knockback force magnitude
---@field Range number Attack detection range (studs)
---@field HitboxSize Vector3 Hitbox dimensions
---@field ComboCount number? Combo count for light attacks
---@field Timestamp number Attack execution time (os.clock)
	IsInvulnerable: boolean,
	IsStunned: boolean,
	StunEndTime: number?,
	StunTimer: thread?,
	
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
---@class HitData
---@field Attacker Player The attacking player
---@field Victim Player The victim player
---@field Damage number Original damage
---@field ActualDamage number Damage after reductions (blocking, armor, etc.)
---@field Knockback Vector3 Knockback direction and force
---@field HitResult HitResult Result of attack (Success/Blocked/PerfectBlock)
---@field HitPosition Vector3 World position of hit
---@field Timestamp number Hit timestamp (os.clock)
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
---@class ValidationResult
---@field Success boolean Whether validation passed
---@field ErrorMessage string? Error message if failed
---@field ErrorCode string? Error code for categorization
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

---@class LoggerConfig
---@field MinLevel LogLevel Minimum log level to output
---@field EnableTimestamp boolean Include timestamps in logs
---@field EnableStackTrace boolean Include stack traces in error logs
---@field OutputToConsole boolean Output to Roblox console
-- ========================================
-- LOGGER CONFIG
-- ========================================

export type LoggerConfig = {
	MinLevel: LogLevel,
	EnableTimestamp: boolean,
	EnableStackTrace: boolean,
	OutputToConsole: boolean,
}

return {}
