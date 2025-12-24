--[[
	Module: AttackHelper
	Type: Server Helper Module
	Location: ServerScriptService.CombatHandler.Helpers.AttackHelper
	Path: src/server/CombatHandler/Helpers/AttackHelper.luau
	
	Description:
		Server-side helper functions for attack mechanics (LightAttack, StrongAttack).
		Centralizes common attack logic: stun application, target validation, broadcasting.
		Eliminates code duplication between attack mechanics.
		
		Moved from shared/ to server/ for proper encapsulation (uses ServerScriptService).
	
	Dependencies:
		- ReplicatedStorage.CombatCore.Core (Enums, SpatialHelper, ValidationHelper)
		- ReplicatedStorage.CombatCore.Network (NetworkManager)
		- ServerScriptService.CombatHandler (PlayerDataManager)
	
	Performance:
		- Cached NetworkManager reference to avoid repeated lookups
		- Direct ValidationHelper usage instead of Utility wrapper
	
	Author: Professional Roblox Scripter
	Created: December 13, 2025
	Moved: December 14, 2025 - Relocated to server/CombatHandler/Helpers
--]]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Module Imports
local CombatSystem = ReplicatedStorage:WaitForChild("CombatCore")

local Enums = require(CombatSystem.Data.Enums)
local ValidationHelper = require(CombatSystem.Validation.ValidationHelper)

-- Cache PlayerDataManager (optimization)
local CombatHandler = ServerScriptService:WaitForChild("CombatHandler")
local PlayerDataManager = require(CombatHandler.Core:WaitForChild("PlayerDataManager"))
local dataManager = PlayerDataManager.GetInstance()

-- Cache NetworkManager (optimization)
local NetworkManager = require(CombatSystem:WaitForChild("Network"):WaitForChild("NetworkManager"))
local netManager = NetworkManager.GetServerInstance()

-- Attack Helper Module
local AttackHelper = {}

-- ========================================
-- TARGET VALIDATION
-- ========================================

-- Validates if a victim is a valid attack target
-- @param attacker: Player or NPC Model performing the attack
-- @param victim: Player or NPC Model receiving the attack
-- @return boolean: true if target is valid
function AttackHelper.IsValidAttackTarget(attacker: Player | Model, victim: Player | Model): boolean
	-- Get victim character (Player.Character or Model for NPCs)
	local victimChar = if typeof(victim) == "Instance" and victim:IsA("Player") 
		then victim.Character 
		else victim
	
	-- Get attacker character (support Players and NPCs)
	local attackerChar = if typeof(attacker) == "Instance" and attacker:IsA("Player") 
		then attacker.Character 
		else attacker
	
	-- Can't hit yourself
	if attackerChar == victimChar then
		return false
	end
	
	-- Validate character structure
	if not ValidationHelper.IsCharacterValid(victimChar) then
		return false
	end
	
	-- Check if victim is alive
	local humanoid, _ = ValidationHelper.GetCharacterComponents(victimChar)
	if not humanoid or humanoid.Health <= 0 then
		return false
	end
	
	return true
end

-- ========================================
-- STATUS EFFECTS
-- ========================================

-- Applies stun effect to a player
-- Note: NPCs don't use PlayerDataManager, handle separately in mechanics
-- @param victim: Player to stun
-- @param duration: Stun duration in seconds
function AttackHelper.ApplyStunToPlayer(victim: Player, duration: number)
	if typeof(victim) ~= "Instance" or not victim:IsA("Player") then
		return -- Only players have data manager
	end
	
	dataManager:SetStunned(victim, true, duration)
end

-- ========================================
-- CLIENT BROADCASTING
-- ========================================

-- Broadcasts attack effects to all clients
-- Handles both animation and VFX synchronization
-- @param attacker: Player performing the attack
-- @param animationType: Animation identifier from Enums
-- @param hitPlayers: Array of Players/NPCs that were hit
-- @param vfxType: Visual effect identifier
-- @param comboCount: Optional combo count for combo-based attacks
function AttackHelper.BroadcastAttackEffects(
	attacker: Player | Model,
	animationType: string,
	hitPlayers: {Player | Model},
	vfxType: string,
	comboCount: number?
)
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
		local victimChar = if typeof(victim) == "Instance" and victim:IsA("Player") 
			then victim.Character 
			else victim
		
		local victimName = if typeof(victim) == "Instance" and victim:IsA("Player") 
			then victim.Name 
			else victimChar.Name
		
		local _, rootPart = ValidationHelper.GetCharacterComponents(victimChar)
		
		if rootPart then
			netManager:SendToAllClients(Enums.NetworkEvent.PlayVFX, {
				VFXType = vfxType,
				Position = rootPart.Position,
				Attacker = if typeof(attacker) == "Instance" and attacker:IsA("Player") 
					then attacker.Name 
					else attacker.Name,
				Victim = victimName,
			})
		end
	end
end

return AttackHelper
