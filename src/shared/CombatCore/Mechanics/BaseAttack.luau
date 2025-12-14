--[[
	Module: BaseAttack
	Type: Base Class Module (Server)
	Location: ReplicatedStorage.CombatCore.Mechanics.BaseAttack
	Path: src/shared/CombatCore/Mechanics/BaseAttack.luau
	
	Description:
		Base class for attack mechanics (LightAttack, StrongAttack).
		Provides common functionality for hitbox detection, damage application,
		knockback effects, and client broadcasting to eliminate code duplication.
		
		Implements Template Method pattern - subclasses override specific behavior
		while base class handles common flow and validation.
	
	Phase 2 Refactoring:
		- Extracted from LightAttack.luau and StrongAttack.luau
		- Eliminates ~120 lines of duplicated code
		- Provides consistent attack behavior across all attack types
	
	Dependencies:
		- ReplicatedStorage.CombatCore.Core (Config, Enums, Types, Logger, Utility)
		- ServerScriptService.CombatHandler (CombatService)
	
	Author: Professional Roblox Scripter
	Created: December 14, 2025
--]]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

-- Module Imports
local RS = ReplicatedStorage
local CombatSystem = RS:WaitForChild("CombatCore")
local Core = CombatSystem:WaitForChild("Core")

local Config = require(Core.Config)
local Enums = require(Core.Enums)
local Types = require(Core.Types)
local Logger = require(Core.Logger).GetInstance()
local Utility = require(Core.Utility)
local DebugLogger = require(Core.DebugLogger)
local HitboxVisualizer = require(Core.HitboxVisualizer)

-- Server-side helper (Phase 1 - Refactored location)
local AttackHelper = require(ServerScriptService.CombatHandler.Helpers.AttackHelper)

-- Cached service references (Phase 2 optimization)
local CombatHandler = ServerScriptService:WaitForChild("CombatHandler")
local CombatService = require(CombatHandler:WaitForChild("CombatService"))

-- Base Attack Module
local BaseAttack = {}
BaseAttack.__index = BaseAttack

-- ========================================
-- CONSTANTS
-- ========================================

local IS_SERVER = RunService:IsServer()

-- ========================================
-- COMMON VALIDATION
-- ========================================

function BaseAttack:_ValidateExecution(player: Player, mechanicName: string): boolean
	if not IS_SERVER then
		Logger:Warning(mechanicName .. " can only be executed on server")
		return false
	end
	
	-- Get character (support both Players and Test Rigs/NPCs)
	local character = if typeof(player) == "Instance" and player:IsA("Player") then player.Character else player
	if not Utility.IsCharacterValid(character) then
		local playerName = if typeof(player) == "Instance" and player:IsA("Player") then player.Name else "TestRig"
		DebugLogger.MechanicInvalidCharacter(mechanicName, playerName)
		Logger:Warning("Invalid character for " .. mechanicName, {player = playerName})
		return false
	end
	
	return true
end

-- ========================================
-- HITBOX DETECTION (Common Logic)
-- ========================================

function BaseAttack:_DetectHits(attackData: Types.AttackData, forwardOffset: number, maxAngle: number): {Player | Model}
	local attacker = attackData.Attacker
	local character = if typeof(attacker) == "Instance" and attacker:IsA("Player") then attacker.Character else attacker
	local rootPart = Utility.GetRootPart(character)
	
	if not rootPart then
		return {}
	end
	
	-- Calculate hitbox origin
	local origin = rootPart.Position + rootPart.CFrame.LookVector * forwardOffset
	local direction = rootPart.CFrame.LookVector
	
	-- DEBUG: Visualize hitbox
	if Config.Debug.ShowHitboxes then
		local attackTypeName = if attackData.AttackType == Enums.AttackType.LightAttack 
			then "LightAttack" 
			else "StrongAttack"
		
		HitboxVisualizer.ShowAttack(
			origin,
			direction,
			attackData.HitboxSize,
			attackData.Range,
			attackTypeName
		)
	end
	
	-- Get entities in hitbox
	local hitEntities = Utility.GetPlayersInRadius(origin, attackData.Range, {character})
	
	-- Filter valid targets
	local validTargets = {}
	for _, victim in ipairs(hitEntities) do
		if self:_IsValidTarget(attacker, victim) then
			local victimChar = if typeof(victim) == "Instance" and victim:IsA("Player") 
				then victim.Character 
				else victim
			
			-- Check if target is in attack cone
			if Utility.IsInFront(character, victimChar, maxAngle) then
				table.insert(validTargets, victim)
			end
		end
	end
	
	return validTargets
end

function BaseAttack:_IsValidTarget(attacker: Player | Model, victim: Player | Model): boolean
	return AttackHelper.IsValidAttackTarget(attacker, victim)
end

-- ========================================
-- DAMAGE APPLICATION (Common Logic)
-- ========================================

function BaseAttack:_GetCombatService()
	return CombatService.GetInstance()
end

function BaseAttack:_ApplyDamageToVictim(attackData: Types.AttackData, victim: Player | Model)
	local service = self:_GetCombatService()
	
	-- Apply damage through service (handles blocking, invulnerability, etc.)
	local hitData = service:ApplyDamage(attackData.Attacker, victim, attackData.Damage)
	
	return hitData
end

-- ========================================
-- KNOCKBACK EFFECTS (Common Logic)
-- ========================================

function BaseAttack:_ApplyKnockbackToVictim(
	attackData: Types.AttackData, 
	victim: Player | Model, 
	knockbackMultiplier: number?,
	upwardComponent: number?
)
	knockbackMultiplier = knockbackMultiplier or 1
	upwardComponent = upwardComponent or 0
	
	local attacker = attackData.Attacker
	local attackerChar = if typeof(attacker) == "Instance" and attacker:IsA("Player") 
		then attacker.Character 
		else attacker
	local victimChar = if typeof(victim) == "Instance" and victim:IsA("Player") 
		then victim.Character 
		else victim
	
	if not attackerChar or not victimChar then
		return
	end
	
	-- Calculate knockback direction
	local direction = Utility.GetDirectionTo(attackerChar, victimChar)
	if not direction then
		return
	end
	
	-- Apply knockback with optional upward component
	local knockbackDirection = direction
	if upwardComponent > 0 then
		knockbackDirection = (direction + Vector3.new(0, upwardComponent, 0)).Unit
	end
	
	local knockbackForce = attackData.Knockback * knockbackMultiplier
	Utility.ApplyKnockback(victimChar, knockbackDirection, knockbackForce)
	
	-- Notify client (only for players)
	if typeof(victim) == "Instance" and victim:IsA("Player") then
		local NetworkManager = require(CombatSystem:WaitForChild("Network"):WaitForChild("NetworkManager"))
		local netManager = NetworkManager.GetServerInstance()
		
		netManager:SendToClient(victim, Enums.NetworkEvent.ApplyKnockback, {
			Direction = knockbackDirection,
			Force = knockbackForce,
		})
	end
end

-- ========================================
-- STUN EFFECTS (Common Logic)
-- ========================================

function BaseAttack:_ApplyStunToVictim(victim: Player, duration: number)
	if typeof(victim) == "Instance" and victim:IsA("Player") then
		AttackHelper.ApplyStunToPlayer(victim, duration)
	end
end

-- ========================================
-- CLIENT BROADCASTING (Common Logic)
-- ========================================

function BaseAttack:_BroadcastAttackToClients(
	attacker: Player | Model, 
	attackType: string, 
	hitPlayers: {Player | Model}, 
	effectName: string,
	comboCount: number?
)
	AttackHelper.BroadcastAttackEffects(attacker, attackType, hitPlayers, effectName, comboCount)
end

return BaseAttack
