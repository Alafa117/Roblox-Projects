--[[
	Module: AttackHelper
	Type: Helper Module (Shared)
	Location: ReplicatedStorage.CombatCore.Mechanics.AttackHelper
	Path: src/shared/CombatCore/Mechanics/AttackHelper.luau
	
	Description:
		Helper functions for attack mechanics (LightAttack, StrongAttack).
		Centralizes common attack logic: stun application, target validation, broadcasting.
		Eliminates code duplication between attack mechanics.
	
	Dependencies:
		- ReplicatedStorage.CombatCore.Core (Enums, Logger, Utility)
		- ReplicatedStorage.CombatCore.Network (NetworkManager)
		- ServerScriptService.CombatHandler (PlayerDataManager)
	
	Author: Professional Roblox Scripter
	Created: December 13, 2025
--]]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Module Imports
local CombatSystem = ReplicatedStorage:WaitForChild("CombatCore")
local Core = CombatSystem:WaitForChild("Core")

local Enums = require(Core.Enums)
local Utility = require(Core.Utility)

-- Attack Helper Module
local AttackHelper = {}

-- ========================================
-- TARGET VALIDATION
-- ========================================

function AttackHelper.IsValidAttackTarget(attacker: Player, victim: Player | Model): boolean
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
-- STUN APPLICATION
-- ========================================

function AttackHelper.ApplyStunToPlayer(victim: Player, duration: number)
	local CombatHandler = ServerScriptService:WaitForChild("CombatHandler")
	local PlayerDataManager = require(CombatHandler:WaitForChild("PlayerDataManager"))
	local dataManager = PlayerDataManager.GetInstance()
	
	dataManager:SetStunned(victim, true, duration)
end

-- ========================================
-- CLIENT BROADCASTING
-- ========================================

function AttackHelper.BroadcastAttackEffects(
	attacker: Player,
	animationType: string,
	hitPlayers: {Player},
	vfxType: string,
	comboCount: number?
)
	local NetworkManager = require(CombatSystem:WaitForChild("Network"):WaitForChild("NetworkManager"))
	local netManager = NetworkManager.GetServerInstance()
	
	-- Broadcast animation to all clients
	local animData = {
		Player = attacker,
		AnimationType = animationType,
	}
	
	if comboCount then
		animData.ComboCount = comboCount
	end
	
	netManager:SendToAllClients(Enums.NetworkEvent.PlayAnimation, animData)
	
	-- Send hit effects for each victim
	for _, victim in ipairs(hitPlayers) do
		local victimChar = if typeof(victim) == "Instance" and victim:IsA("Player") then victim.Character else victim
		local victimName = if typeof(victim) == "Instance" and victim:IsA("Player") then victim.Name else victimChar.Name
		local rootPart = Utility.GetRootPart(victimChar)
		
		if rootPart then
			netManager:SendToAllClients(Enums.NetworkEvent.PlayVFX, {
				VFXType = vfxType,
				Position = rootPart.Position,
				Attacker = attacker.Name,
				Victim = victimName,
			})
		end
	end
end

return AttackHelper
