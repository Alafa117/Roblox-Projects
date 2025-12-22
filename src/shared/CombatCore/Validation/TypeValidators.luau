--[[
	Module: TypeValidators
	Type: Runtime Validation Module
	Location: ReplicatedStorage.CombatCore.Validation.TypeValidators
	Path: src/shared/CombatCore/Validation/TypeValidators.luau
	
	Description:
		Runtime type validators using the 't' library.
		Validates critical data structures to catch errors early.
		Provides detailed error messages for debugging.
		
		Used for:
		- Server-side validation of client requests
		- Data structure validation before processing
		- Configuration validation on startup
		- Debugging and error prevention
	
	Dependencies:
		- Packages.t (osyrisrblx/t library)
		- ReplicatedStorage.CombatCore.Data.Enums
	
	Author: Professional Roblox Scripter
	Created: December 20, 2025
--]]

-- Import t library
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage.Packages  -- Direct access (no yield)
local t = require(Packages.t)

-- Import Config and Enums (using relative paths - no yields)
local Config = require(script.Parent.Parent.Config.Config)
local Enums = require(script.Parent.Parent.Data.Enums)

-- Type Validators Module
local TypeValidators = {}

-- ========================================
-- BASIC VALIDATORS
-- ========================================

-- Validate CombatState enum
TypeValidators.CombatState = t.union(
	t.literal(Enums.CombatState.Idle),
	t.literal(Enums.CombatState.LightAttacking),
	t.literal(Enums.CombatState.StrongAttacking),
	t.literal(Enums.CombatState.Blocking),
	t.literal(Enums.CombatState.Dashing),
	t.literal(Enums.CombatState.Sliding),
	t.literal(Enums.CombatState.Stunned),
	t.literal(Enums.CombatState.Dead)
)

-- Validate ActionType enum
TypeValidators.ActionType = t.union(
	t.literal(Enums.ActionType.M1),
	t.literal(Enums.ActionType.M2),
	t.literal(Enums.ActionType.Q),
	t.literal(Enums.ActionType.C),
	t.literal(Enums.ActionType.F)
)

-- Validate AttackType enum
TypeValidators.AttackType = t.union(
	t.literal(Enums.AttackType.LightAttack),
	t.literal(Enums.AttackType.StrongAttack)
)

-- Validate HitResult enum
TypeValidators.HitResult = t.union(
	t.literal(Enums.HitResult.Success),
	t.literal(Enums.HitResult.Blocked),
	t.literal(Enums.HitResult.PerfectBlock)
)

-- Validate Direction enum
TypeValidators.Direction = t.union(
	t.literal(Enums.Direction.Forward),
	t.literal(Enums.Direction.Backward),
	t.literal(Enums.Direction.Left),
	t.literal(Enums.Direction.Right)
)

-- ========================================
-- NETWORK REQUEST VALIDATORS (Anti-Exploit)
-- ========================================

-- Validate DashRequest from client (Anti-Exploit: Strict validation)
TypeValidators.DashRequest = t.strictInterface({
	Direction = TypeValidators.Direction, -- Must be valid direction enum
})

-- Validate SlideRequest from client (Anti-Exploit: Strict validation)
TypeValidators.SlideRequest = t.strictInterface({
	Direction = TypeValidators.Direction, -- Must be valid direction enum
})

-- Validate BlockRequest from client
TypeValidators.BlockRequest = t.strictInterface({
	IsBlocking = t.boolean, -- true = start block, false = end block
})

-- ========================================
-- PLAYER COMBAT DATA VALIDATOR
-- ========================================

TypeValidators.PlayerCombatData = t.strictInterface({
	Player = t.Instance,
	Character = t.optional(t.Instance),
	Humanoid = t.optional(t.instanceOf("Humanoid")),
	HumanoidRootPart = t.optional(t.instanceOf("BasePart")),
	
	CurrentState = TypeValidators.CombatState,
	PreviousState = t.optional(TypeValidators.CombatState),
	
	ComboCount = t.integer,
	LastAttackTime = t.number,
	
	Cooldowns = t.strictInterface({
		M1 = t.number,
		M2 = t.number,
		Q = t.number,
		C = t.number,
		F = t.number,
	}),
	
	IsInvulnerable = t.boolean,
	IsStunned = t.boolean,
	StunEndTime = t.optional(t.number),
	StunTimer = t.optional(t.thread),
	
	IsBlocking = t.boolean,
	BlockStartTime = t.optional(t.number),
	
	Health = t.optional(t.number),
	MaxHealth = t.optional(t.number),
})

-- ========================================
-- ATTACK DATA VALIDATOR
-- ========================================

TypeValidators.AttackData = t.strictInterface({
	Attacker = t.Instance,
	Victim = t.optional(t.Instance),
	AttackType = TypeValidators.AttackType,
	Damage = t.numberPositive,
	Knockback = t.numberPositive,
	Range = t.numberPositive,
	HitboxSize = t.Vector3,
	ComboCount = t.optional(t.integer),
	Timestamp = t.number,
})

-- ========================================
-- HIT DATA VALIDATOR
-- ========================================

TypeValidators.HitData = t.strictInterface({
	Attacker = t.Instance,
	Victim = t.Instance,
	Damage = t.numberPositive,
	ActualDamage = t.numberPositive,
	Knockback = t.Vector3,
	HitResult = TypeValidators.HitResult,
	HitPosition = t.Vector3,
	Timestamp = t.number,
})

-- ========================================
-- ACTION REQUEST VALIDATOR (Client → Server)
-- ========================================

-- Unified ActionRequest validator with strict range validation (Anti-Exploit)
-- Prevents infinite combos, one-shot exploits, and timestamp manipulation
TypeValidators.ActionRequest = t.strictInterface({
	ActionType = TypeValidators.ActionType,
	
	-- Timestamp: Must be recent (±1 second tolerance for latency)
	Timestamp = t.optional(t.intersection(
		t.number,
		function(v)
			local now = os.clock()
			return v >= (now - 1) and v <= (now + 1), "Timestamp must be within ±1s of server time"
		end
	)),
	
	-- ComboCount: Must be 0-6 (Light Attack combo chain limit)
	ComboCount = t.optional(t.intersection(
		t.integer,
		function(v)
			return v >= 0 and v <= 6, "ComboCount must be between 0 and 6"
		end
	)),
	
	-- ChargeTime: Maximum 5 seconds (Strong Attack charge limit)
	ChargeTime = t.optional(t.intersection(
		t.numberPositive,
		function(v)
			return v <= 5, "ChargeTime must not exceed 5 seconds"
		end
	)),
	
	-- Direction: Must be unit vector (magnitude ≈ 1)
	-- Deprecated - use DashRequest/SlideRequest instead
	Direction = t.optional(t.intersection(
		t.Vector3,
		function(v)
			return v.Magnitude <= 1.1, "Direction must be a unit vector (magnitude ≤ 1.1)"
		end
	)),
	
	CancelledMovement = t.optional(t.boolean),
})

-- ========================================
-- MOVEMENT VALIDATION CONFIG
-- ========================================

TypeValidators.MovementValidationConfig = t.strictInterface({
	MaxDistance = t.numberPositive,
	MaxSpeed = t.numberPositive,
	DistanceTolerance = t.optional(t.numberPositive),
	SpeedTolerance = t.optional(t.numberPositive),
})

-- ========================================
-- HITBOX VISUALIZATION CONFIG
-- ========================================

TypeValidators.VisualizationConfig = t.strictInterface({
	origin = t.Vector3,
	attackType = t.string,
	duration = t.optional(t.number),
	size = t.optional(t.Vector3),
	range = t.optional(t.number),
	direction = t.optional(t.Vector3),
	length = t.optional(t.number),
})

-- ========================================
-- HELPER FUNCTIONS
-- ========================================

-- Validate and return detailed error message
-- Respects Config.System.EnableTypeValidation for production toggle
function TypeValidators.ValidateWithError(validator: any, value: any, name: string?): (boolean, string?)
	-- Skip validation if disabled (production mode - 0 overhead)
	if not Config.System.EnableTypeValidation then
		return true, nil
	end
	
	local success, errorMessage = validator(value)
	if not success then
		local valueName = name or "value"
		return false, string.format("❌ [TypeValidation] Invalid %s: %s", valueName, errorMessage)
	end
	return true, nil
end

-- Assert validation (throws error if invalid)
-- Respects Config.System.EnableTypeValidation for production toggle
function TypeValidators.Assert(validator: any, value: any, name: string?)
	-- Skip validation if disabled (production mode - 0 overhead)
	if not Config.System.EnableTypeValidation then
		return
	end
	
	local success, errorMessage = TypeValidators.ValidateWithError(validator, value, name)
	if not success then
		error(errorMessage, 2)
	end
end

-- Validate with warning (logs warning but doesn't throw)
-- Respects Config.System.EnableTypeValidation for production toggle
function TypeValidators.ValidateWithWarning(validator: any, value: any, name: string?): boolean
	-- Skip validation if disabled (production mode - 0 overhead)
	if not Config.System.EnableTypeValidation then
		return true
	end
	
	local success, errorMessage = TypeValidators.ValidateWithError(validator, value, name)
	if not success then
		warn(errorMessage)
		return false
	end
	return true
end

-- ========================================
-- VALIDATION PRESETS
-- ========================================

-- Common validation patterns for frequently validated types
TypeValidators.Presets = {
	-- Validate Player instance
	Player = function(value: any): boolean
		return t.Instance(value) and value:IsA("Player")
	end,
	
	-- Validate living character
	LivingCharacter = function(character: any): boolean
		if not t.Instance(character) then return false end
		local humanoid = character:FindFirstChild("Humanoid")
		if not humanoid or not humanoid:IsA("Humanoid") then return false end
		return humanoid.Health > 0
	end,
	
	-- Validate positive cooldown time
	CooldownTime = t.intersection(t.number, function(value)
		return value >= 0, "Cooldown time must be non-negative"
	end),
	
	-- Validate combo count
	ComboCount = t.intersection(t.integer, function(value)
		return value >= 0 and value <= 100, "Combo count must be between 0 and 100"
	end),
}

return TypeValidators
