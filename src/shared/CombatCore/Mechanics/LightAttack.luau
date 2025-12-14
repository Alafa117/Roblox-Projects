--[[
	Module: LightAttack
	Type: Combat Mechanic Module (Server)
	Location: ReplicatedStorage.CombatCore.Mechanics.LightAttack
	Path: src/shared/CombatCore/Mechanics/LightAttack.luau
	
	Description:
		Implements the Light Attack (M1) combat mechanic.
		Handles hitbox detection, damage calculation, combo multipliers.
		Server-authoritative with range validation and anti-exploit checks.
		Applies knockback and stun effects to hit targets.
	
	Dependencies:
		- ReplicatedStorage.CombatCore.Core (Config, Enums, Types, Logger, Utility)
	
	Author: Professional Roblox Scripter
	Created: December 11, 2025
--]]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

-- Module Imports
local RS = ReplicatedStorage
local CombatSystem = RS:WaitForChild("CombatCore")
local Core = CombatSystem:WaitForChild("Core")
local Mechanics = CombatSystem:WaitForChild("Mechanics")

local Config = require(Core.Config)
local Enums = require(Core.Enums)
local Types = require(Core.Types)
local Logger = require(Core.Logger).GetInstance()
local Utility = require(Core.Utility)
local DebugLogger = require(Core.DebugLogger)

-- Phase 2: Base class with common attack logic
local BaseAttack = require(Mechanics.BaseAttack)

-- Server-side helper (Phase 1 - Refactored location)
local AttackHelper = require(ServerScriptService.CombatHandler.Helpers.AttackHelper)

-- Movement mechanics for cancellation
local Dash = require(Mechanics.Dash)
local Slide = require(Mechanics.Slide)

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
	DebugLogger.MechanicExecute("LightAttack", player.Name, "Combo: " .. tostring(data.ComboCount or 1))
	
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
	DebugLogger.MechanicHitDetection("LightAttack", #hitPlayers)
	
	-- Apply damage to hit players
	for _, victim in ipairs(hitPlayers) do
		local victimName = if typeof(victim) == "Instance" and victim:IsA("Player") then victim.Name else victim.Name
		DebugLogger.MechanicDamageApplied("LightAttack", victimName, attackData.Damage)
		self:_ApplyDamage(attackData, victim, comboCount)
	end
	
	-- Broadcast to clients for VFX (Phase 2: uses base class)
	DebugLogger.MechanicVFXBroadcast("LightAttack")
	self:_BroadcastAttackToClients(player, "LightAttack", hitPlayers, "HitSpark", comboCount)
end

-- ========================================
-- ATTACK DATA GENERATION
-- ========================================

function LightAttack:_GetAttackData(player: Player, comboCount: number): Types.AttackData
	-- Get character (support both Players and Test Rigs/NPCs)
	local character = if typeof(player) == "Instance" and player:IsA("Player") then player.Character else player
	local _rootPart = Utility.GetRootPart(character)
	
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
	
	-- Apply knockback if not blocked (Phase 2: uses base class)
	if hitData.HitResult ~= Enums.HitResult.Blocked and hitData.HitResult ~= Enums.HitResult.PerfectBlock then
		self:_ApplyKnockbackToVictim(attackData, victim)
	end
	
	-- Apply stun (Phase 2: uses base class)
	self:_ApplyStunToVictim(victim, Config.LightAttack.StunDuration)
	
	-- Apply ragdoll on 6th combo (finisher)
	if comboCount == 6 then
		local victimChar = if typeof(victim) == "Instance" and victim:IsA("Player") then victim.Character else victim
		if victimChar then
			Utility.ApplyRagdoll(victimChar, Config.LightAttack.FinisherRagdollDuration)
			
			local victimName = if typeof(victim) == "Instance" and victim:IsA("Player") then victim.Name else victimChar.Name
			Logger:Debug("Combo finisher ragdoll applied", {
				victim = victimName,
				duration = Config.LightAttack.FinisherRagdollDuration
			})
		end
	end
end

return LightAttack
