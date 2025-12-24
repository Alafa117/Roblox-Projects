--[[
	Module: LightAttack
	Type: Combat Mechanic Module (Server)
	Location: ServerScriptService.CombatHandler.Mechanics.LightAttack
	Path: src/server/CombatHandler/Mechanics/LightAttack.luau
	
	Description:
		Implements the Light Attack (M1) combat mechanic.
		Handles hitbox detection, damage calculation, combo multipliers.
		Server-authoritative with range validation and anti-exploit checks.
		Applies knockback and stun effects to hit targets.
	
	Phase 4 Refactoring:
		- Moved from shared/ to server/ (correct architecture)
		- Updated imports to reflect server-only location
	
	Dependencies:
		- ReplicatedStorage.CombatCore (Config, Enums, Types, Logger, ValidationHelper)
		- ServerScriptService.CombatHandler (BaseAttack, AttackHelper, RagdollManager)
	
	Author: Professional Roblox Scripter
	Created: December 11, 2025
	Relocated: December 17, 2025
--]]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

-- Module Imports
local CombatSystem = ReplicatedStorage:WaitForChild("CombatCore")

local Config = require(CombatSystem.Config.Config)
local Enums = require(CombatSystem.Data.Enums)
local Types = require(CombatSystem.Data.Types)
local Logger = require(CombatSystem.Logging.Logger).GetInstance()
local ValidationHelper = require(CombatSystem.Validation.ValidationHelper)
local TypeValidators = require(CombatSystem.Validation.TypeValidators)
local SpatialHelper = require(CombatSystem.Helpers.SpatialHelper)

-- Server-side modules
local CombatHandler = ServerScriptService:WaitForChild("CombatHandler")
local ServerMechanics = CombatHandler:WaitForChild("Mechanics")
local BaseAttack = require(ServerMechanics.BaseAttack)
local AttackHelper = require(CombatHandler.Helpers.AttackHelper)
local RagdollManager = require(CombatHandler.Physics.RagdollManager).GetInstance()

-- Movement mechanics for cancellation
local Dash = require(CombatSystem.Movement.Dash)
local Slide = require(CombatSystem.Movement.Slide)

-- Light Attack Module
local LightAttack = setmetatable({}, BaseAttack)
LightAttack.__index = LightAttack

-- ========================================
-- CONSTANTS
-- ========================================

local HITBOX_FORWARD_OFFSET = 3  -- Studs in front of player
local HITBOX_MAX_ANGLE = 120     -- Degrees

-- ========================================
-- EXECUTE METHOD
-- ========================================

function LightAttack:Execute(player: Player, data: {[string]: any})
	Logger:MechanicExecute("LightAttack", player.Name, "Combo: " .. tostring(data.ComboCount or 1))
	
	-- Validate execution (Phase 2: uses base class)
	if not self:_ValidateExecution(player, "LightAttack") then
		return
	end
	
	-- Cancel active movement mechanics (Dash/Slide)
	Dash:CancelDash(player)
	Slide:CancelSlide(player)
	
	local comboCount = data.ComboCount or 1
	
	-- Get attack parameters
	local attackData = self:_GetAttackData(player, comboCount)
	
	-- Perform hitbox detection (Phase 2: uses base class)
	local hitPlayers = self:_DetectHits(attackData, HITBOX_FORWARD_OFFSET, HITBOX_MAX_ANGLE)
	Logger:MechanicHitDetection("LightAttack", #hitPlayers)
	
	-- Apply damage to hit players
	for _, victim in ipairs(hitPlayers) do
		local victimName = if typeof(victim) == "Instance" and victim:IsA("Player") then victim.Name else victim.Name
		Logger:MechanicDamageApplied("LightAttack", victimName, attackData.Damage)
		self:_ApplyDamage(attackData, victim, comboCount)
	end
	
	-- Broadcast to clients for VFX (Phase 2: uses base class)
	Logger:MechanicVFXBroadcast("LightAttack")
	self:_BroadcastAttackToClients(player, "LightAttack", hitPlayers, "HitSpark", comboCount)
end

-- ========================================
-- ATTACK DATA GENERATION
-- ========================================

function LightAttack:_GetAttackData(player: Player, comboCount: number): Types.AttackData
	-- Get character (support both Players and Test Rigs/NPCs)
	local character = if typeof(player) == "Instance" and player:IsA("Player") then player.Character else player
	local humanoid, _rootPart = ValidationHelper.GetCharacterComponents(character)
	
	-- Combo multipliers
	local damageMultiplier = 1 + (comboCount - 1) * 0.1 -- +10% per combo
	local knockbackMultiplier
	
	-- Special finisher on 6th combo
	if comboCount == 6 then
		knockbackMultiplier = Config.LightAttack.FinisherKnockback / Config.LightAttack.Knockback
	else
		knockbackMultiplier = 1 + (comboCount - 1) * 0.15 -- +15% per combo
	end
	
	local attackData: Types.AttackData = {
		Attacker = player,
		Victim = nil,
		AttackType = Enums.AttackType.LightAttack,
		Damage = Config.LightAttack.Damage * damageMultiplier,
		Knockback = Config.LightAttack.Knockback * knockbackMultiplier,
		Range = Config.LightAttack.Range,
		HitboxSize = Config.LightAttack.HitboxSize,
		ComboCount = comboCount,
		Timestamp = os.clock(),
	}
	
	-- ✅ Validate AttackData structure
	TypeValidators.Assert(
		TypeValidators.AttackData,
		attackData,
		"LightAttack AttackData"
	)
	
	return attackData
end

-- ========================================
-- DAMAGE APPLICATION
-- ========================================

function LightAttack:_ApplyDamage(attackData: Types.AttackData, victim: Player | Model, comboCount: number)
	-- Apply damage through base class (Phase 2: cached service reference)
	local hitData = self:_ApplyDamageToVictim(attackData, victim)
	
	if not hitData then
		return
	end
	
	-- Apply stun (Phase 2: uses base class)
	self:_ApplyStunToVictim(victim, Config.LightAttack.StunDuration)
	
	-- Apply knockback and ragdoll on 6th combo (finisher)
	if comboCount == 6 then
		local victimChar = if typeof(victim) == "Instance" and victim:IsA("Player") then victim.Character else victim
		if victimChar and hitData.HitResult ~= Enums.HitResult.Blocked and hitData.HitResult ~= Enums.HitResult.PerfectBlock then
			-- Calculate knockback direction
			local attacker = attackData.Attacker
			local attackerChar = if typeof(attacker) == "Instance" and attacker:IsA("Player") then attacker.Character else attacker
			
			if attackerChar then
				local SpatialHelper = require(CombatSystem.Helpers.SpatialHelper)
				local direction = SpatialHelper.GetDirectionTo(attackerChar, victimChar)
				
				if direction then
					-- Apply ragdoll WITH integrated knockback physics
					RagdollManager:ApplyRagdoll(
						victimChar, 
						Config.LightAttack.FinisherRagdollDuration,
						direction, -- Knockback direction
						Config.LightAttack.FinisherKnockback -- Knockback force
					)
					
					Logger:Debug("Combo finisher applied", {
						victim = if typeof(victim) == "Instance" and victim:IsA("Player") then victim.Name else victimChar.Name,
						knockback = Config.LightAttack.FinisherKnockback,
						ragdollDuration = Config.LightAttack.FinisherRagdollDuration
					})
				end
			end
		end
	end
end

return LightAttack
