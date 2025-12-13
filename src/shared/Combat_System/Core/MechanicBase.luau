--[[
	Module: MechanicBase
	Type: Base Class Module
	Location: ReplicatedStorage.Combat_System.Core.MechanicBase
	Path: src/shared/Combat_System/Core/MechanicBase.luau
	
	Description:
		Base class for all combat mechanics (LightAttack, StrongAttack, Dash, Slide, Block).
		Provides common functionality like character validation, hit detection base,
		and VFX broadcasting to eliminate code duplication.
	
	Author: Professional Roblox Scripter
	Created: December 11, 2025
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Module Imports
local RS = ReplicatedStorage
local CombatSystem = RS:WaitForChild("Combat_System")
local Core = CombatSystem:WaitForChild("Core")

local Enums = require(Core.Enums)
local Logger = require(Core.Logger).GetInstance()
local Utility = require(Core.Utility)
local DebugLogger = require(Core.DebugLogger)

-- MechanicBase Class
local MechanicBase = {}
MechanicBase.__index = MechanicBase

-- ========================================
-- CONSTRUCTOR
-- ========================================

function MechanicBase.new(mechanicName: string, mechanicConfig: any)
	local self = setmetatable({}, MechanicBase)
	
	self.Name = mechanicName
	self.Config = mechanicConfig
	self._networkManager = nil
	
	return self
end

-- ========================================
-- SHARED VALIDATION
-- ========================================

function MechanicBase:ValidateCharacter(player: Player): (boolean, Model?, Humanoid?, BasePart?)
	local character = player.Character
	if not character then
		DebugLogger.MechanicInvalidCharacter(self.Name, player.Name)
		return false, nil, nil, nil
	end
	
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = Utility.GetRootPart(character)
	
	if not humanoid or not rootPart then
		DebugLogger.MechanicInvalidCharacter(self.Name, player.Name)
		return false, character, nil, nil
	end
	
	if humanoid.Health <= 0 then
		DebugLogger.MechanicInvalidCharacter(self.Name, player.Name)
		return false, character, humanoid, rootPart
	end
	
	return true, character, humanoid, rootPart
end

-- ========================================
-- SHARED HIT DETECTION
-- ========================================

function MechanicBase:DetectHitsInRadius(origin: Vector3, range: number, _hitboxSize: Vector3?, attacker: Player?): {Player | Model}
	-- Use Utility's detection but add debug logging
	local hits = Utility.GetPlayersInRadius(origin, range, attacker)
	
	DebugLogger.MechanicHitDetection(self.Name, #hits)
	
	return hits
end

-- ========================================
-- SHARED VFX BROADCASTING
-- ========================================

function MechanicBase:BroadcastVFX(player: Player, targets: {Player | Model}, vfxType: string?)
	DebugLogger.MechanicVFXBroadcast(self.Name)
	
	if not self._networkManager then
		return
	end
	
	-- Broadcast animation
	self._networkManager:SendToAllClients(Enums.NetworkEvent.PlayAnimation, {
		Player = player,
		AnimationType = vfxType or self.Name,
	})
	
	-- Broadcast VFX
	self._networkManager:SendToAllClients(Enums.NetworkEvent.PlayVFX, {
		Player = player,
		Targets = targets,
		VFXType = vfxType or self.Name,
	})
end

-- ========================================
-- SHARED DAMAGE APPLICATION
-- ========================================

function MechanicBase:ApplyDamageToTarget(
	combatService: any,
	attacker: Player,
	victim: Player | Model,
	damage: number,
	knockback: number?,
	stunDuration: number?
): boolean
	local victimName = if typeof(victim) == "Instance" and victim:IsA("Player") 
		then victim.Name 
		else victim.Name
	
	DebugLogger.MechanicDamageApplied(self.Name, victimName, damage)
	
	local result = combatService:ApplyDamage(
		attacker,
		victim,
		damage,
		knockback,
		stunDuration
	)
	
	return result.Success
end

-- ========================================
-- NETWORK MANAGER INJECTION
-- ========================================

function MechanicBase:SetNetworkManager(networkManager: any)
	self._networkManager = networkManager
end

-- ========================================
-- EXECUTE (To be overridden by subclasses)
-- ========================================

function MechanicBase:Execute(_player: Player, _data: {[string]: any})
	error(string.format("%s:Execute() must be implemented by subclass", self.Name))
end

-- ========================================
-- HELPER: Log Execution
-- ========================================

function MechanicBase:LogExecution(player: Player, extraData: string?)
	DebugLogger.MechanicExecute(self.Name, player.Name, extraData)
	Logger:Debug(self.Name .. " executed", {
		player = player.Name,
		data = extraData
	})
end

return MechanicBase
