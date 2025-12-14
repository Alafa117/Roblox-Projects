--[[
	Module: StrongAttack
	Type: Combat Mechanic Module (Server)
	Location: ReplicatedStorage.CombatCore.Mechanics.StrongAttack
	Path: src/shared/CombatCore/Mechanics/StrongAttack.luau
	
	Description:
		Implements the Strong Attack (M2) combat mechanic.
		Charged heavy attack with increased damage, range, and knockback.
		Server-authoritative with charge time validation.
		Applies significant knockback and longer stun duration.
	
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
local HitboxVisualizer = require(Core.HitboxVisualizer)

-- Server-side helper (Phase 1 - Refactored location)
local AttackHelper = require(ServerScriptService.CombatHandler.Helpers.AttackHelper)

-- Movement mechanics for cancellation
local Dash = require(Mechanics.Dash)
local Slide = require(Mechanics.Slide)

-- Strong Attack Module
local StrongAttack = {}

-- ========================================
-- CONSTANTS
-- ========================================

local IS_SERVER = RunService:IsServer()

-- ========================================
-- EXECUTE METHOD
-- ========================================

function StrongAttack:Execute(player: Player, _data: {[string]: any})
	DebugLogger.MechanicExecute("StrongAttack", player.Name)
	
	if not IS_SERVER then
		Logger:Warning("StrongAttack can only be executed on server")
		return
	end
	
	-- Cancel active movement mechanics (Dash/Slide)
	Dash:CancelDash(player)
	Slide:CancelSlide(player)
	
	-- Get character (support both Players and Test Rigs/NPCs)
	local character = if typeof(player) == "Instance" and player:IsA("Player") then player.Character else player
	if not Utility.IsCharacterValid(character) then
		local playerName = if typeof(player) == "Instance" and player:IsA("Player") then player.Name else "TestRig"
		DebugLogger.MechanicInvalidCharacter("StrongAttack", playerName)
		Logger:Warning("Invalid character for StrongAttack", {player = playerName})
		return
	end
	
	-- Get attack parameters (instant attack)
	local attackData = self:_GetAttackData(player)
	
	-- Perform hitbox detection
	local hitPlayers = self:_DetectHits(attackData)
	DebugLogger.MechanicHitDetection("StrongAttack", #hitPlayers)
	
	-- Apply damage to hit players
	for _, victim in ipairs(hitPlayers) do
		local victimName = if typeof(victim) == "Instance" and victim:IsA("Player") then victim.Name else victim.Name
		DebugLogger.MechanicDamageApplied("StrongAttack", victimName, attackData.Damage)
		self:_ApplyDamage(attackData, victim)
	end
	
	-- Broadcast to clients for VFX
	DebugLogger.MechanicVFXBroadcast("StrongAttack")
	self:_BroadcastAttack(player, hitPlayers)
end

-- ========================================
-- ATTACK DATA GENERATION
-- ========================================

function StrongAttack:_GetAttackData(player: Player): Types.AttackData
	-- Get character (support both Players and Test Rigs/NPCs)
	local character = if typeof(player) == "Instance" and player:IsA("Player") then player.Character else player
	local _rootPart = Utility.GetRootPart(character)
	
	-- Instant attack with full damage
	local attackData: Types.AttackData = {
		Attacker = player,
		Victim = nil,
		AttackType = Enums.AttackType.StrongAttack,
		Damage = Config.StrongAttack.Damage,
		Knockback = Config.StrongAttack.Knockback,
		Range = Config.StrongAttack.Range,
		HitboxSize = Config.StrongAttack.HitboxSize,
		ComboCount = nil,
		Timestamp = os.clock(),
	}
	
	return attackData
end

-- ========================================
-- HITBOX DETECTION
-- ========================================

function StrongAttack:_DetectHits(attackData: Types.AttackData): {Player}
	local attacker = attackData.Attacker
	-- Get character (support both Players and Test Rigs/NPCs)
	local character = if typeof(attacker) == "Instance" and attacker:IsA("Player") then attacker.Character else attacker
	local rootPart = Utility.GetRootPart(character)
	
	if not rootPart then
		return {}
	end
	
	-- Calculate hitbox origin (further in front for strong attack)
	local origin = rootPart.Position + rootPart.CFrame.LookVector * 4
	local direction = rootPart.CFrame.LookVector
	
	-- DEBUG: Visualize hitbox
	if Config.Debug.ShowHitboxes then
		HitboxVisualizer.ShowAttack(
			origin,
			direction,
			attackData.HitboxSize,
			attackData.Range,
			"StrongAttack"
		)
	end
	
	-- Get players in hitbox (larger radius)
	local hitPlayers = Utility.GetPlayersInRadius(origin, attackData.Range, {character})
	
	-- Filter valid targets
	local validTargets = {}
	for _, victim in ipairs(hitPlayers) do
		if self:_IsValidTarget(attacker, victim) then
			-- Get victim character (either Player.Character or the Model itself for NPCs)
			local victimChar = if typeof(victim) == "Instance" and victim:IsA("Player") then victim.Character else victim
			-- Wider angle for strong attack
			if Utility.IsInFront(character, victimChar, 150) then
				table.insert(validTargets, victim)
			end
		end
	end
	
	return validTargets
end

function StrongAttack:_IsValidTarget(attacker: Player, victim: Player | Model): boolean
	return AttackHelper.IsValidAttackTarget(attacker, victim)
end

-- ========================================
-- DAMAGE APPLICATION
-- ========================================

function StrongAttack:_ApplyDamage(attackData: Types.AttackData, victim: Player | Model)
	-- Get CombatService to apply damage
	local ServerScriptService = game:GetService("ServerScriptService")
	local CombatHandler = ServerScriptService:WaitForChild("CombatHandler")
	local CombatService = require(CombatHandler:WaitForChild("CombatService"))
	local service = CombatService.GetInstance()
	
	-- Apply damage through service
	local hitData = service:ApplyDamage(attackData.Attacker, victim, attackData.Damage)
	
	if not hitData then
		return
	end
	
	-- Apply heavy knockback (even on block)
	self:_ApplyKnockback(attackData, victim, hitData.HitResult)
	
	-- Apply longer stun (only for players)
	if typeof(victim) == "Instance" and victim:IsA("Player") then
		self:_ApplyStun(victim, Config.StrongAttack.StunDuration)
	end
	
	-- Break block if blocked (for both players and NPCs)
	if hitData.HitResult == Enums.HitResult.Blocked then
		if typeof(victim) == "Instance" and victim:IsA("Player") then
			self:_BreakBlock(victim)
		else
			-- NPC block break
			self:_BreakNPCBlock(victim)
		end
	end
	
	-- Apply ragdoll effect
	local victimChar = if typeof(victim) == "Instance" and victim:IsA("Player") then victim.Character else victim
	if victimChar then
		Utility.ApplyRagdoll(victimChar, Config.StrongAttack.RagdollDuration)
	end
end

-- ========================================
-- KNOCKBACK & EFFECTS
-- ========================================

function StrongAttack:_ApplyKnockback(attackData: Types.AttackData, victim: Player | Model, hitResult: string)
	-- Get attacker character (support Players and Test Rigs)
	local attacker = attackData.Attacker
	local attackerChar = if typeof(attacker) == "Instance" and attacker:IsA("Player") then attacker.Character else attacker
	local victimChar = if typeof(victim) == "Instance" and victim:IsA("Player") then victim.Character else victim
	
	if not attackerChar or not victimChar then
		return
	end
	
	-- Calculate knockback direction
	local direction = Utility.GetDirectionTo(attackerChar, victimChar)
	if not direction then
		return
	end
	
	-- Reduced knockback if blocked
	local knockbackForce = attackData.Knockback
	if hitResult == Enums.HitResult.Blocked then
		knockbackForce = knockbackForce * 0.3
	elseif hitResult == Enums.HitResult.PerfectBlock then
		knockbackForce = knockbackForce * 0.1
	end
	
	-- Apply knockback with upward component
	local knockbackDirection = direction + Vector3.new(0, 0.3, 0)
	Utility.ApplyKnockback(victimChar, knockbackDirection.Unit, knockbackForce)
	
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

function StrongAttack:_ApplyStun(victim: Player, duration: number)
	AttackHelper.ApplyStunToPlayer(victim, duration)
end

function StrongAttack:_BreakBlock(victim: Player)
	local ServerScriptService = game:GetService("ServerScriptService")
	local CombatHandler = ServerScriptService:WaitForChild("CombatHandler")
	local PlayerDataManager = require(CombatHandler:WaitForChild("PlayerDataManager"))
	local dataManager = PlayerDataManager.GetInstance()
	
	-- Force end blocking
	dataManager:SetBlocking(victim, false)
	
	-- Apply block break stun
	dataManager:SetStunned(victim, true, Config.Block.BlockBreakStunDuration)
	
	-- Notify client for animation
	local NetworkManager = require(CombatSystem:WaitForChild("Network"):WaitForChild("NetworkManager"))
	local netManager = NetworkManager.GetServerInstance()
	
	netManager:SendToClient(victim, Enums.NetworkEvent.PlayAnimation, {
		AnimationType = "BlockBreak",
	})
	
	Logger:Info("Block broken", {victim = victim.Name})
end

function StrongAttack:_BreakNPCBlock(victim: Model)
	local ServerScriptService = game:GetService("ServerScriptService")
	local Testing = ServerScriptService:WaitForChild("Testing")
	local NPCCombatHelper = require(Testing:WaitForChild("NPCCombatHelper"))
	
	-- Force end blocking
	NPCCombatHelper.StopBlock(victim)
	
	-- NPCs don't have stun system, but we can apply ragdoll for the stun duration
	local stunDuration = Config.Block.BlockBreakStunDuration
	Utility.ApplyRagdoll(victim, stunDuration)
	
	Logger:Info("NPC Block broken", {npc = victim.Name})
end

-- ========================================
-- CLIENT BROADCASTING
-- ========================================

function StrongAttack:_BroadcastAttack(attacker: Player, hitPlayers: {Player})
	AttackHelper.BroadcastAttackEffects(attacker, "StrongAttack", hitPlayers, "HeavyHit", nil)
end

return StrongAttack
