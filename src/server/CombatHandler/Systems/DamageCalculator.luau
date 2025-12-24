--[[
	Module: DamageCalculator
	Type: Server Damage Handler
	Location: ServerScriptService.CombatHandler.Systems.DamageCalculator
	Path: src/server/CombatHandler/Systems/DamageCalculator.luau
	
	Description:
		Handles damage calculation, validation, and application.
		Processes blocking mechanics and damage reduction.
		Separated from CombatService for better maintainability.
		Manages health modification and death detection.
	
	Dependencies:
		- ReplicatedStorage.CombatCore.Core (Config, Enums, ValidationHelper)
		- ServerScriptService.CombatHandler.Core.PlayerDataManager
	
	Author: Professional Roblox Scripter
	Created: December 13, 2025
--]]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Module Imports
local RS = ReplicatedStorage
local CombatSystem = RS:WaitForChild("CombatCore")

local Config = require(CombatSystem.Config.Config)
local Enums = require(CombatSystem.Data.Enums)

local PlayerDataManager = require(script.Parent.Parent.Core.PlayerDataManager).GetInstance()

-- Damage Calculator Module
local DamageCalculator = {}

-- ========================================
-- VALIDATION
-- ========================================

function DamageCalculator.ValidateDamageRequest(attacker: Player, victim: Player, actionType: string): (boolean, string?)
	-- Validate players exist
	if not attacker or not victim then
		return false, "Invalid players"
	end
	
	-- Validate characters exist (support Players and Test Rigs/NPCs)
	local attackerChar = if typeof(attacker) == "Instance" and attacker:IsA("Player") then attacker.Character else attacker
	local victimChar = if typeof(victim) == "Instance" and victim:IsA("Player") then victim.Character else victim
	
	if not attackerChar or not victimChar then
		return false, "Missing characters"
	end
	
	-- Validate humanoids
	local attackerHum = attackerChar:FindFirstChild("Humanoid")
	local victimHum = victimChar:FindFirstChild("Humanoid")
	
	if not attackerHum or not victimHum then
		return false, "Missing humanoids"
	end
	
	if attackerHum.Health <= 0 or victimHum.Health <= 0 then
		return false, "Player(s) dead"
	end
	
	-- Validate victim isn't invulnerable
	if PlayerDataManager:IsInvulnerable(victim) then
		return false, "Target invulnerable"
	end
	
	-- Validate proximity
	local attackerRoot = attackerChar:FindFirstChild("HumanoidRootPart")
	local victimRoot = victimChar:FindFirstChild("HumanoidRootPart")
	
	if not attackerRoot or not victimRoot then
		return false, "Missing root parts"
	end
	
	-- Get range from config based on action type
	local maxRange = 15 -- Default
	if actionType == Enums.ActionType.M1 then
		maxRange = Config.LightAttack.Range
	elseif actionType == Enums.ActionType.M2 then
		maxRange = Config.StrongAttack.Range
	end
	
	local distance = (attackerRoot.Position - victimRoot.Position).Magnitude
	if distance > maxRange then
		return false, "Target out of range"
	end
	
	return true
end

-- ========================================
-- DAMAGE CALCULATION
-- ========================================

function DamageCalculator.CalculateDamage(actionType: string, comboCount: number?): number
	local baseDamage = 0
	
	if actionType == Enums.ActionType.M1 then
		baseDamage = Config.LightAttack.Damage
		
		-- Check for finisher multiplier
		if comboCount and comboCount == 6 then
			baseDamage = baseDamage * 1.5
		end
		
	elseif actionType == Enums.ActionType.M2 then
		baseDamage = Config.StrongAttack.Damage
		
	else
		-- Unknown action type
		baseDamage = 10
	end
	
	return baseDamage
end

function DamageCalculator.ApplyBlockReduction(damage: number, isBlocking: boolean): number
	if not isBlocking then
		return damage
	end
	
	-- Blocking reduces damage by DamageReduction percentage
	local reduction = Config.Block.DamageReduction
	return damage * (1 - reduction)
end

-- ========================================
-- DAMAGE APPLICATION
-- ========================================

function DamageCalculator.ApplyDamage(victim: Player, damage: number): boolean
	-- Get character (support Players and Test Rigs/NPCs)
	local character = if typeof(victim) == "Instance" and victim:IsA("Player") then victim.Character else victim
	if not character then
		return false
	end
	
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false
	end
	
	-- Apply damage
	humanoid.Health = math.max(0, humanoid.Health - damage)
	
	return true
end

-- ========================================
-- BLOCKING MECHANICS
-- ========================================

function DamageCalculator.ProcessBlockingDamage(attacker: Player, victim: Player, actionType: string, comboCount: number?): (boolean, number)
	-- Validate damage request
	local isValid, error = DamageCalculator.ValidateDamageRequest(attacker, victim, actionType)
	if not isValid then
		return false, 0
	end
	
	-- Check if victim is blocking
	local isBlocking = PlayerDataManager:IsBlocking(victim)
	
	-- Calculate base damage
	local baseDamage = DamageCalculator.CalculateDamage(actionType, comboCount)
	
	-- Apply block reduction if blocking
	local finalDamage = DamageCalculator.ApplyBlockReduction(baseDamage, isBlocking)
	
	-- Apply damage
	local success = DamageCalculator.ApplyDamage(victim, finalDamage)
	
	return success, finalDamage
end

return DamageCalculator
