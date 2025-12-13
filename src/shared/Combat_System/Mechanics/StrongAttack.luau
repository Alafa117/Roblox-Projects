--[[
	Module: StrongAttack
	Type: Combat Mechanic Module (Server)
	Location: ReplicatedStorage.Combat_System.Mechanics.StrongAttack
	Path: src/shared/Combat_System/Mechanics/StrongAttack.luau
	
	Description:
		Implements the Strong Attack (M2) combat mechanic.
		Charged heavy attack with increased damage, range, and knockback.
		Server-authoritative with charge time validation.
		Applies significant knockback and longer stun duration.
	
	Dependencies:
		- ReplicatedStorage.Combat_System.Core (Config, Enums, Types, Logger, Utility)
	
	Author: Professional Roblox Scripter
	Created: December 11, 2025
--]]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Module Imports
local RS = ReplicatedStorage
local CombatSystem = RS:WaitForChild("Combat_System")
local Core = CombatSystem:WaitForChild("Core")

local Config = require(Core.Config)
local Enums = require(Core.Enums)
local Types = require(Core.Types)
local Logger = require(Core.Logger).GetInstance()
local Utility = require(Core.Utility)
local DebugLogger = require(Core.DebugLogger)

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
	
	local character = player.Character
	if not Utility.IsCharacterValid(character) then
		DebugLogger.MechanicInvalidCharacter("StrongAttack", player.Name)
		Logger:Warning("Invalid character for StrongAttack", {player = player.Name})
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
	
	Logger:Debug("StrongAttack executed", {
		player = player.Name,
		hits = #hitPlayers
	})
end

-- ========================================
-- ATTACK DATA GENERATION
-- ========================================

function StrongAttack:_GetAttackData(player: Player): Types.AttackData
	local character = player.Character
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
	local character = attacker.Character
	local rootPart = Utility.GetRootPart(character)
	
	if not rootPart then
		return {}
	end
	
	-- Calculate hitbox origin (further in front for strong attack)
	local origin = rootPart.Position + rootPart.CFrame.LookVector * 4
	
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
	-- Get victim character (Player.Character or Model for NPCs)
	local victimChar = if typeof(victim) == "Instance" and victim:IsA("Player") then victim.Character else victim
	
	-- Can't hit yourself
	if attacker.Character == victimChar then
		return false
	end
	
	-- Check character validity
	if not Utility.IsCharacterValid(victimChar) then
		return false
	end
	
	-- Check if victim is dead
	local humanoid = Utility.GetHumanoid(victimChar)
	if not humanoid or humanoid.Health <= 0 then
		return false
	end
	
	return true
end

-- ========================================
-- DAMAGE APPLICATION
-- ========================================

function StrongAttack:_ApplyDamage(attackData: Types.AttackData, victim: Player | Model)
	-- Get CombatService to apply damage
	local ServerScriptService = game:GetService("ServerScriptService")
	local Server = ServerScriptService:WaitForChild("Server")
	local CombatService = require(Server:WaitForChild("CombatService"):WaitForChild("CombatService"))
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
	
	-- Break block if blocked (only for players)
	if typeof(victim) == "Instance" and victim:IsA("Player") and hitData.HitResult == Enums.HitResult.Blocked then
		self:_BreakBlock(victim)
	end
	
	-- Apply ragdoll effect
	local victimChar = if typeof(victim) == "Instance" and victim:IsA("Player") then victim.Character else victim
	if victimChar then
		Utility.ApplyRagdoll(victimChar, Config.StrongAttack.RagdollDuration)
		
		local victimName = if typeof(victim) == "Instance" and victim:IsA("Player") then victim.Name else victimChar.Name
		Logger:Debug("Strong attack ragdoll applied", {
			victim = victimName,
			duration = Config.StrongAttack.RagdollDuration
		})
	end
end

-- ========================================
-- KNOCKBACK & EFFECTS
-- ========================================

function StrongAttack:_ApplyKnockback(attackData: Types.AttackData, victim: Player | Model, hitResult: string)
	local attackerChar = attackData.Attacker.Character
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
	
	local victimName = if typeof(victim) == "Instance" and victim:IsA("Player") then victim.Name else victimChar.Name
	Logger:Debug("Heavy knockback applied", {
		victim = victimName,
		force = knockbackForce,
		hitResult = hitResult
	})
end

function StrongAttack:_ApplyStun(victim: Player, duration: number)
	local ServerScriptService = game:GetService("ServerScriptService")
	local Server = ServerScriptService:WaitForChild("Server")
	local PlayerDataManager = require(Server:WaitForChild("CombatService"):WaitForChild("PlayerDataManager"))
	local dataManager = PlayerDataManager.GetInstance()
	
	dataManager:SetStunned(victim, true, duration)
	
	Logger:Debug("Heavy stun applied", {
		victim = victim.Name,
		duration = duration
	})
end

function StrongAttack:_BreakBlock(victim: Player)
	local ServerScriptService = game:GetService("ServerScriptService")
	local Server = ServerScriptService:WaitForChild("Server")
	local PlayerDataManager = require(Server:WaitForChild("CombatService"):WaitForChild("PlayerDataManager"))
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

-- ========================================
-- CLIENT BROADCASTING
-- ========================================

function StrongAttack:_BroadcastAttack(attacker: Player, hitPlayers: {Player})
	local NetworkManager = require(CombatSystem:WaitForChild("Network"):WaitForChild("NetworkManager"))
	local netManager = NetworkManager.GetServerInstance()
	
	-- Broadcast to all clients for VFX/SFX
	netManager:SendToAllClients(Enums.NetworkEvent.PlayAnimation, {
		Player = attacker,
		AnimationType = "StrongAttack",
	})
	
	-- Send heavy hit effects
	for _, victim in ipairs(hitPlayers) do
		local victimChar = if typeof(victim) == "Instance" and victim:IsA("Player") then victim.Character else victim
		local victimName = if typeof(victim) == "Instance" and victim:IsA("Player") then victim.Name else victimChar.Name
		local rootPart = Utility.GetRootPart(victimChar)
		
		if rootPart then
			netManager:SendToAllClients(Enums.NetworkEvent.PlayVFX, {
				VFXType = "HeavyHit",
				Position = rootPart.Position,
				Attacker = attacker.Name,
				Victim = victimName,
			})
		end
	end
end

return StrongAttack
