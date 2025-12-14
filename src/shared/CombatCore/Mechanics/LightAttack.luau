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

-- Movement mechanics for cancellation
local Dash = require(Mechanics.Dash)
local Slide = require(Mechanics.Slide)

-- Light Attack Module
local LightAttack = {}

-- ========================================
-- CONSTANTS
-- ========================================

local IS_SERVER = RunService:IsServer()

-- ========================================
-- EXECUTE METHOD
-- ========================================

function LightAttack:Execute(player: Player, data: {[string]: any})
	DebugLogger.MechanicExecute("LightAttack", player.Name, "Combo: " .. tostring(data.ComboCount or 1))
	
	if not IS_SERVER then
		Logger:Warning("LightAttack can only be executed on server")
		return
	end
	
	-- Cancel active movement mechanics (Dash/Slide)
	Dash:CancelDash(player)
	Slide:CancelSlide(player)
	
	local character = player.Character
	if not Utility.IsCharacterValid(character) then
		DebugLogger.MechanicInvalidCharacter("LightAttack", player.Name)
		Logger:Warning("Invalid character for LightAttack", {player = player.Name})
		return
	end
	
	local comboCount = data.ComboCount or 1
	
	-- Get attack parameters
	local attackData = self:_GetAttackData(player, comboCount)
	
	-- Perform hitbox detection
	local hitPlayers = self:_DetectHits(attackData)
	DebugLogger.MechanicHitDetection("LightAttack", #hitPlayers)
	
	-- Apply damage to hit players
	for _, victim in ipairs(hitPlayers) do
		local victimName = if typeof(victim) == "Instance" and victim:IsA("Player") then victim.Name else victim.Name
		DebugLogger.MechanicDamageApplied("LightAttack", victimName, attackData.Damage)
		self:_ApplyDamage(attackData, victim)
	end
	
	-- Broadcast to clients for VFX
	DebugLogger.MechanicVFXBroadcast("LightAttack")
	self:_BroadcastAttack(player, comboCount, hitPlayers)
	
	Logger:Debug("LightAttack executed", {
		player = player.Name,
		combo = comboCount,
		hits = #hitPlayers
	})
end

-- ========================================
-- ATTACK DATA GENERATION
-- ========================================

function LightAttack:_GetAttackData(player: Player, comboCount: number): Types.AttackData
	local character = player.Character
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
-- HITBOX DETECTION
-- ========================================

function LightAttack:_DetectHits(attackData: Types.AttackData): {Player}
	local attacker = attackData.Attacker
	local character = attacker.Character
	local rootPart = Utility.GetRootPart(character)
	
	if not rootPart then
		return {}
	end
	
	-- Calculate hitbox origin (in front of player)
	local origin = rootPart.Position + rootPart.CFrame.LookVector * 3
	local direction = rootPart.CFrame.LookVector
	
	-- DEBUG: Visualize hitbox
	if Config.Debug.ShowHitboxes then
		HitboxVisualizer.ShowAttack(
			origin,
			direction,
			attackData.HitboxSize,
			attackData.Range,
			"LightAttack"
		)
	end
	
	-- Get players in hitbox
	local hitPlayers = Utility.GetPlayersInRadius(origin, attackData.Range, {character})
	
	-- Filter valid targets
	local validTargets = {}
	for _, victim in ipairs(hitPlayers) do
		if self:_IsValidTarget(attacker, victim) then
			-- Get victim character (either Player.Character or the Model itself for NPCs)
			local victimChar = if typeof(victim) == "Instance" and victim:IsA("Player") then victim.Character else victim
			-- Check if target is in front
			if Utility.IsInFront(character, victimChar, 120) then
				table.insert(validTargets, victim)
			end
		end
	end
	
	return validTargets
end

function LightAttack:_IsValidTarget(attacker: Player, victim: Player | Model): boolean
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

function LightAttack:_ApplyDamage(attackData: Types.AttackData, victim: Player | Model)
	-- Get CombatService to apply damage
	local ServerScriptService = game:GetService("ServerScriptService")
	local CombatHandler = ServerScriptService:WaitForChild("CombatHandler")
	local CombatService = require(CombatHandler:WaitForChild("CombatService"))
	local service = CombatService.GetInstance()
	
	-- Apply damage through service (handles blocking, invulnerability, etc.)
	local hitData = service:ApplyDamage(attackData.Attacker, victim, attackData.Damage)
	
	if not hitData then
		return
	end
	
	-- Apply knockback if not blocked
	if hitData.HitResult ~= Enums.HitResult.Blocked and hitData.HitResult ~= Enums.HitResult.PerfectBlock then
		self:_ApplyKnockback(attackData, victim)
	end
	
	-- Apply stun (only for players)
	if typeof(victim) == "Instance" and victim:IsA("Player") then
		self:_ApplyStun(victim, Config.LightAttack.StunDuration)
	end
	
	-- Apply ragdoll on 6th combo (finisher)
	if attackData.ComboCount == 6 then
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

-- ========================================
-- KNOCKBACK & EFFECTS
-- ========================================

function LightAttack:_ApplyKnockback(attackData: Types.AttackData, victim: Player | Model)
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
	
	-- Apply knockback
	Utility.ApplyKnockback(victimChar, direction, attackData.Knockback)
	
	-- Notify client (only for players)
	if typeof(victim) == "Instance" and victim:IsA("Player") then
		local NetworkManager = require(CombatSystem:WaitForChild("Network"):WaitForChild("NetworkManager"))
		local netManager = NetworkManager.GetServerInstance()
		
		netManager:SendToClient(victim, Enums.NetworkEvent.ApplyKnockback, {
			Direction = direction,
			Force = attackData.Knockback,
		})
	end
	
	local victimName = if typeof(victim) == "Instance" and victim:IsA("Player") then victim.Name else victimChar.Name
	Logger:Debug("Knockback applied", {
		victim = victimName,
		force = attackData.Knockback
	})
end

function LightAttack:_ApplyStun(victim: Player, duration: number)
	local ServerScriptService = game:GetService("ServerScriptService")
	local CombatHandler = ServerScriptService:WaitForChild("CombatHandler")
	local PlayerDataManager = require(CombatHandler:WaitForChild("PlayerDataManager"))
	local dataManager = PlayerDataManager.GetInstance()
	
	dataManager:SetStunned(victim, true, duration)
	
	Logger:Debug("Stun applied", {
		victim = victim.Name,
		duration = duration
	})
end

-- ========================================
-- CLIENT BROADCASTING
-- ========================================

function LightAttack:_BroadcastAttack(attacker: Player, comboCount: number, hitPlayers: {Player})
	local NetworkManager = require(CombatSystem:WaitForChild("Network"):WaitForChild("NetworkManager"))
	local netManager = NetworkManager.GetServerInstance()
	
	-- Broadcast to all clients for VFX/SFX
	netManager:SendToAllClients(Enums.NetworkEvent.PlayAnimation, {
		Player = attacker,
		AnimationType = "LightAttack",
		ComboCount = comboCount,
	})
	
	-- Send hit effects
	for _, victim in ipairs(hitPlayers) do
		local victimChar = if typeof(victim) == "Instance" and victim:IsA("Player") then victim.Character else victim
		local victimName = if typeof(victim) == "Instance" and victim:IsA("Player") then victim.Name else victimChar.Name
		local rootPart = Utility.GetRootPart(victimChar)
		
		if rootPart then
			netManager:SendToAllClients(Enums.NetworkEvent.PlayVFX, {
				VFXType = "HitSpark",
				Position = rootPart.Position,
				Attacker = attacker.Name,
				Victim = victimName,
			})
		end
	end
end

return LightAttack
