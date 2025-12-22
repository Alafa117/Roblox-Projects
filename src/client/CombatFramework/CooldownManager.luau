--[[
	Module: CooldownManager
	Type: Client Utility Module
	Location: ReplicatedFirst.CombatFramework.CooldownManager
	Path: src/client/CombatFramework/CooldownManager.luau
	
	Description:
		Manages action cooldowns for the combat system.
		Tracks cooldown timestamps, validates cooldown readiness,
		and provides cooldown configuration lookup.
	
	Features:
		- Cooldown tracking per action type
		- Cooldown validation with time remaining calculations
		- Configurable cooldown durations from Config
		- Special combo cooldown logic for M1 attacks
	
	Usage:
		local cooldownManager = CooldownManager.new()
		cooldownManager:IsReady(Enums.ActionType.M1) -- Check if action is ready
		cooldownManager:Start(Enums.ActionType.M1) -- Start cooldown
		cooldownManager:GetRemaining(Enums.ActionType.M1) -- Get time remaining
		cooldownManager:Clear(Enums.ActionType.M1) -- Clear cooldown (for combos)
	
	Author: Professional Roblox Scripter
	Created: December 13, 2025
--]]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Module Imports
local CombatSystem = ReplicatedStorage:WaitForChild("CombatCore")
local Core = CombatSystem:WaitForChild("Core")

local Config = require(Core.Config)
local Enums = require(Core.Enums)
local ValidationHelper = require(CombatSystem.Validation.ValidationHelper)

-- ========================================
-- CONFIGURATION
-- ========================================

-- Cooldown configuration lookup table (efficient O(1) access)
local COOLDOWN_CONFIGS = {
	[Enums.ActionType.M1] = function() return Config.LightAttack.Cooldown end,
	[Enums.ActionType.M2] = function() return Config.StrongAttack.Cooldown end,
	[Enums.ActionType.Q] = function() return Config.Dash.Cooldown end,
	[Enums.ActionType.C] = function() return Config.Slide.Cooldown end,
	[Enums.ActionType.F] = function() return Config.Block.Cooldown end,
}

-- ========================================
-- COOLDOWN MANAGER CLASS
-- ========================================

local CooldownManager = {}
CooldownManager.__index = CooldownManager

-- ========================================
-- TYPES
-- ========================================

export type CooldownManager = {
	_cooldowns: {[string]: number},
	
	IsReady: (self: CooldownManager, actionType: string) -> boolean,
	Start: (self: CooldownManager, actionType: string) -> (),
	Clear: (self: CooldownManager, actionType: string) -> (),
	GetRemaining: (self: CooldownManager, actionType: string) -> number,
	GetCooldownDuration: (self: CooldownManager, actionType: string) -> number,
	Reset: (self: CooldownManager) -> (),
	Destroy: (self: CooldownManager) -> (),
}

-- ========================================
-- CONSTRUCTOR
-- ========================================

function CooldownManager.new(): CooldownManager
	local self = setmetatable({}, CooldownManager)
	
	-- Initialize cooldowns for all action types
	self._cooldowns = {}
	for actionType, _ in pairs(Enums.ActionType) do
		self._cooldowns[actionType] = 0
	end
	
	return self
end

-- ========================================
-- COOLDOWN MANAGEMENT
-- ========================================

-- Check if action is ready (cooldown completed)
function CooldownManager:IsReady(actionType: string): boolean
	local cooldownDuration = self:GetCooldownDuration(actionType)
	return ValidationHelper.IsCooldownReady(self._cooldowns[actionType], cooldownDuration)
end

-- Start cooldown for action (set timestamp to now)
function CooldownManager:Start(actionType: string)
	self._cooldowns[actionType] = os.clock()
end

-- Clear cooldown for action (set to 0 for instant reuse)
-- Used for combo attacks (M1) to allow instant next hit
function CooldownManager:Clear(actionType: string)
	self._cooldowns[actionType] = 0
end

-- Get remaining cooldown time in seconds
function CooldownManager:GetRemaining(actionType: string): number
	local cooldownDuration = self:GetCooldownDuration(actionType)
	return ValidationHelper.GetCooldownRemaining(self._cooldowns[actionType], cooldownDuration)
end

-- Get cooldown duration for action from config
function CooldownManager:GetCooldownDuration(actionType: string): number
	local cooldownGetter = COOLDOWN_CONFIGS[actionType]
	return cooldownGetter and cooldownGetter() or 0
end

-- Reset all cooldowns to 0
function CooldownManager:Reset()
	for actionType, _ in pairs(self._cooldowns) do
		self._cooldowns[actionType] = 0
	end
end

-- ========================================
-- CLEANUP
-- ========================================

function CooldownManager:Destroy()
	table.clear(self._cooldowns)
end

return CooldownManager
