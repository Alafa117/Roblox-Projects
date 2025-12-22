--[[
	Module: StrongAttack
	Type: Combat Mechanic Module (Server)
	Location: ServerScriptService.CombatHandler.Mechanics.StrongAttack
	Path: src/server/CombatHandler/Mechanics/StrongAttack.luau
	
	Description:
		Implements the Strong Attack (M2) combat mechanic.
		Charged heavy attack with increased damage, range, and knockback.
		Server-authoritative with charge time validation.
		Applies significant knockback and longer stun duration.
	
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

-- Server-side modules
local CombatHandler = ServerScriptService:WaitForChild("CombatHandler")
local ServerMechanics = CombatHandler:WaitForChild("Mechanics")
local BaseAttack = require(ServerMechanics.BaseAttack)
local AttackHelper = require(CombatHandler.Helpers.AttackHelper)
local RagdollManager = require(CombatHandler.Physics.RagdollManager).GetInstance()

-- Movement mechanics for cancellation
local Dash = require(CombatSystem.Movement.Dash)
local Slide = require(CombatSystem.Movement.Slide)

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
	Logger:MechanicExecute("StrongAttack", player.Name)
	
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
	Logger:MechanicHitDetection("StrongAttack", #hitPlayers)
	
	-- Apply damage to hit players
	for _, victim in ipairs(hitPlayers) do
		local victimName = if typeof(victim) == "Instance" and victim:IsA("Player") then victim.Name else victim.Name
		Logger:MechanicDamageApplied("StrongAttack", victimName, attackData.Damage)
		self:_ApplyDamage(attackData, victim)
	end
	
	-- Broadcast to clients for VFX (Phase 2: uses base class)
	Logger:MechanicVFXBroadcast("StrongAttack")
	self:_BroadcastAttackToClients(player, "StrongAttack", hitPlayers, "HeavyHit", nil)
end

-- ========================================
-- ATTACK DATA GENERATION
-- ========================================

function StrongAttack:_GetAttackData(player: Player): Types.AttackData
	-- Get character (support both Players and Test Rigs/NPCs)
	local character = if typeof(player) == "Instance" and player:IsA("Player") then player.Character else player
	local humanoid, _rootPart = ValidationHelper.GetCharacterComponents(character)
	
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
	
	-- ✅ Validate AttackData structure
	TypeValidators.Assert(
		TypeValidators.AttackData,
		attackData,
		"StrongAttack AttackData"
	)
	
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
		RagdollManager:ApplyRagdoll(victimChar, Config.StrongAttack.RagdollDuration)
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
	RagdollManager:ApplyRagdoll(victim, stunDuration)
	
	Logger:Info("NPC Block broken", {npc = victim.Name})
end

return StrongAttack
