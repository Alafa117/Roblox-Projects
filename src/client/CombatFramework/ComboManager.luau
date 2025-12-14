--[[
	Module: ComboManager
	Type: Client Utility Module
	Location: StarterPlayer.StarterPlayerScripts.CombatFramework.ComboManager
	Path: src/client/CombatFramework/ComboManager.luau
	
	Description:
		Manages combat combo system including count tracking, timing, and window validation.
		Decouples combo logic from CombatController for better separation of concerns.
		Handles combo chains, resets, and automatic expiration.
	
	Features:
		- Combo count tracking (1 to MaxComboCount)
		- Combo window timing validation
		- Automatic combo reset after window expires
		- Optimized for M1 attack chains
	
	Dependencies:
		- ReplicatedStorage.CombatCore.Core (Config, Logger)
	
	Author: Professional Roblox Scripter
	Created: December 13, 2025
--]]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Module Imports
local CombatSystem = ReplicatedStorage:WaitForChild("CombatCore")
local Core = CombatSystem:WaitForChild("Core")

local Config = require(Core.Config)

-- Combo Manager Class
local ComboManager = {}
ComboManager.__index = ComboManager

-- ========================================
-- TYPES
-- ========================================

export type ComboManager = {
	_comboCount: number,
	_lastAttackTime: number,
	
	GetComboCount: (self: ComboManager) -> number,
	GetLastAttackTime: (self: ComboManager) -> number,
	UpdateCombo: (self: ComboManager) -> number,
	ResetCombo: (self: ComboManager) -> (),
	IsInComboWindow: (self: ComboManager) -> boolean,
	ShouldApplyCooldown: (self: ComboManager, newComboCount: number) -> boolean,
	Destroy: (self: ComboManager) -> (),
}

-- ========================================
-- CONSTRUCTOR
-- ========================================

function ComboManager.new(): ComboManager
	local self = setmetatable({}, ComboManager)
	
	self._comboCount = 0
	self._lastAttackTime = 0
	
	return self
end

-- ========================================
-- COMBO MANAGEMENT
-- ========================================

-- Get current combo count
function ComboManager:GetComboCount(): number
	return self._comboCount
end

-- Get last attack timestamp
function ComboManager:GetLastAttackTime(): number
	return self._lastAttackTime
end

-- Update combo count based on timing
-- Returns (new combo count, was in combo window)
function ComboManager:UpdateCombo(): (number, boolean)
	local now = os.clock()
	local timeSinceLastAttack = now - self._lastAttackTime
	local wasInWindow = timeSinceLastAttack <= Config.LightAttack.ComboWindow
	
	-- Check if within combo window
	if wasInWindow then
		-- Increment combo (capped at max)
		self._comboCount = math.min(self._comboCount + 1, Config.LightAttack.MaxComboCount)
	else
		-- Reset to first hit
		self._comboCount = 1
	end
	
	-- Update timestamp
	self._lastAttackTime = now
	
	return self._comboCount, wasInWindow
end

-- Reset combo to 0
function ComboManager:ResetCombo()
	self._comboCount = 0
	self._lastAttackTime = 0
end

-- Check if currently in combo window
function ComboManager:IsInComboWindow(): boolean
	if self._comboCount == 0 then
		return false
	end
	
	local timeSinceLastAttack = os.clock() - self._lastAttackTime
	return timeSinceLastAttack <= Config.LightAttack.ComboWindow
end

-- Determine if cooldown should be applied based on combo state
-- Called after UpdateCombo() with wasInWindow from that call
function ComboManager:ShouldApplyCooldown(newComboCount: number, wasInWindow: boolean): boolean
	-- Apply cooldown if:
	-- 1. Starting new combo (was not in window)
	-- 2. Finishing combo (reached max count)
	local isLastHit = newComboCount >= Config.LightAttack.MaxComboCount
	
	return not wasInWindow or isLastHit
end

-- Update combo window check (for heartbeat loop)
-- Returns true if combo was reset
function ComboManager:UpdateComboWindow(): boolean
	if self._comboCount > 0 then
		local timeSinceLastAttack = os.clock() - self._lastAttackTime
		if timeSinceLastAttack > Config.LightAttack.ComboWindow then
			self._comboCount = 0
			return true
		end
	end
	return false
end

-- ========================================
-- CLEANUP
-- ========================================

function ComboManager:Destroy()
	self:ResetCombo()
end

return ComboManager
