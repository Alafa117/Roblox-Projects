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

-- Phase 2: Base class with common attack logic
local BaseAttack = require(Mechanics.BaseAttack)

-- Server-side helper (Phase 1 - Refactored location)
local AttackHelper = require(ServerScriptService.CombatHandler.Helpers.AttackHelper)

-- Movement mechanics for cancellation
local Dash = require(Mechanics.Dash)
local Slide = require(Mechanics.Slide)

-- Strong Attack Module
local StrongAttack = setmetatable({}, BaseAttack)
StrongAttack.__index = StrongAttack

-- ========================================
-- CONSTANTS
-- ========================================

local HITBOX_FORWARD_OFFSET = 4  -- Studs in front of player (further than M1)
local HITBOX_MAX_ANGLE = 150     -- Degrees (wider than M1)

-- ========================================
-- CACHED REFERENCES (Phase 3 optimization)
-- ========================================

-- Lazy-loaded singletons for dependency injection
local _playerDataManager = nil
local _networkManager = nil
local _npcCombatHelper = nil

local function GetPlayerDataManager()
	if not _playerDataManager then
		local CombatHandler = ServerScriptService:WaitForChild("CombatHandler")
		local PlayerDataManager = require(CombatHandler:WaitForChild("PlayerDataManager"))
		_playerDataManager = PlayerDataManager.GetInstance()
	end
	return _playerDataManager
end

local function GetNetworkManager()
	if not _networkManager then
		local NetworkManager = require(CombatSystem:WaitForChild("Network"):WaitForChild("NetworkManager"))
		_networkManager = NetworkManager.GetServerInstance()
	end
	return _networkManager
end

local function GetNPCCombatHelper()
	if not _npcCombatHelper then
		local Testing = ServerScriptService:WaitForChild("Testing")
		_npcCombatHelper = require(Testing:WaitForChild("NPCCombatHelper"))
	end
	return _npcCombatHelper
end

-- ========================================
-- EXECUTE METHOD
-- ========================================

function StrongAttack:Execute(player: Player, _data: {[string]: any})
	DebugLogger.MechanicExecute("StrongAttack", player.Name)
	
	-- Validate execution (Phase 2: uses base class)
	if not self:_ValidateExecution(player, "StrongAttack") then
		return
	end
	
	-- Cancel active movement mechanics (Dash/Slide)
	Dash:CancelDash(player)
	Slide:CancelSlide(player)
	
	-- Get attack parameters (instant attack)
	local attackData = self:_GetAttackData(player)
	
	-- Perform hitbox detection (Phase 2: uses base class)
	local hitPlayers = self:_DetectHits(attackData, HITBOX_FORWARD_OFFSET, HITBOX_MAX_ANGLE)
	DebugLogger.MechanicHitDetection("StrongAttack", #hitPlayers)
	
	-- Apply damage to hit players
	for _, victim in ipairs(hitPlayers) do
		local victimName = if typeof(victim) == "Instance" and victim:IsA("Player") then victim.Name else victim.Name
		DebugLogger.MechanicDamageApplied("StrongAttack", victimName, attackData.Damage)
		self:_ApplyDamage(attackData, victim)
	end
	
	-- Broadcast to clients for VFX (Phase 2: uses base class)
	DebugLogger.MechanicVFXBroadcast("StrongAttack")
	self:_BroadcastAttackToClients(player, "StrongAttack", hitPlayers, "HeavyHit", nil)
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
-- DAMAGE APPLICATION
-- ========================================

function StrongAttack:_ApplyDamage(attackData: Types.AttackData, victim: Player | Model)
	-- Apply damage through base class (Phase 2: cached service reference)
	local hitData = self:_ApplyDamageToVictim(attackData, victim)
	
	if not hitData then
		return
	end
	
	-- Calculate knockback multiplier based on hit result
	local knockbackMultiplier = 1
	if hitData.HitResult == Enums.HitResult.Blocked then
		knockbackMultiplier = 0.3
	elseif hitData.HitResult == Enums.HitResult.PerfectBlock then
		knockbackMultiplier = 0.1
	end
	
	-- Apply heavy knockback with upward component (Phase 2: uses base class)
	self:_ApplyKnockbackToVictim(attackData, victim, knockbackMultiplier, 0.3)
	
	-- Apply longer stun (Phase 2: uses base class)
	self:_ApplyStunToVictim(victim, Config.StrongAttack.StunDuration)
	
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
-- BLOCK BREAKING
-- ========================================

function StrongAttack:_BreakBlock(victim: Player)
	-- Phase 3: Dependency injection via cached getters
	local dataManager = GetPlayerDataManager()
	local netManager = GetNetworkManager()
	
	-- Force end blocking
	dataManager:SetBlocking(victim, false)
	
	-- Apply block break stun
	dataManager:SetStunned(victim, true, Config.Block.BlockBreakStunDuration)
	
	-- Notify client for animation
	netManager:SendToClient(victim, Enums.NetworkEvent.PlayAnimation, {
		AnimationType = "BlockBreak",
	})
	
	Logger:Info("Block broken", {victim = victim.Name})
end

function StrongAttack:_BreakNPCBlock(victim: Model)
	-- Phase 3: Dependency injection via cached getter
	local npcHelper = GetNPCCombatHelper()
	
	-- Force end blocking
	npcHelper.StopBlock(victim)
	
	-- NPCs don't have stun system, but we can apply ragdoll for the stun duration
	local stunDuration = Config.Block.BlockBreakStunDuration
	Utility.ApplyRagdoll(victim, stunDuration)
	
	Logger:Info("NPC Block broken", {npc = victim.Name})
end

return StrongAttack
