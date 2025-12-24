--[[
	Module: CooldownManager
	Type: Server-Side Cooldown Tracker
	Location: ServerScriptService.CombatHandler.Systems.CooldownManager
	Path: src/server/CombatHandler/Systems/CooldownManager.luau
	
	Description:
		Server-authoritative cooldown tracking system for combat actions.
		Prevents cooldown bypass exploits by tracking all cooldowns server-side.
		Does not trust client timestamps - all validation happens on server.
		
		Phase 4 Enhancement (Server-Authoritative Cooldowns):
		- Server-side cooldown tracking (no client trust)
		- Automatic cleanup on player disconnect
		- Per-action cooldown management
		- Anti-exploit protection against cooldown manipulation
	
	Usage:
		local CooldownManager = require(CombatHandler.Systems.CooldownManager)
	
Reorganized: December 23, 2025 - Moved to Systems/ subfolder
		
		-- Check if action is ready
		if CooldownManager:CanPerformAction(player, "M1") then
			-- Execute action...
			CooldownManager:RecordAction(player, "M1")
		end
		
		-- Get remaining cooldown
		local remaining = CooldownManager:GetRemainingCooldown(player, "M2")
	
	Dependencies:
		- ReplicatedStorage.CombatCore.Config (for cooldown values)
		- ReplicatedStorage.CombatCore.Logging (Logger)
	
	Author: Professional Roblox Scripter
	Created: December 21, 2025 (Phase 4 - Server-Authoritative Cooldowns)
--]]

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Module Imports
local Config = require(ReplicatedStorage.CombatCore.Config.Config)
local Logger = require(ReplicatedStorage.CombatCore.Logging.Logger).GetInstance()

-- Cooldown Manager Module
local CooldownManager = {}
CooldownManager.__index = CooldownManager

-- Singleton Instance
local ManagerInstance: CooldownManager? = nil

-- ========================================
-- TYPES
-- ========================================

type PlayerCooldowns = {
	M1: number,      -- Light Attack
	M2: number,      -- Strong Attack
	Q: number,       -- Dash
	C: number,       -- Slide
	F: number,       -- Block
}

type CooldownManager = {
	_cooldowns: {[Player]: PlayerCooldowns},
	_connections: {RBXScriptConnection},
}

-- ========================================
-- COOLDOWN CONFIGURATION
-- ========================================

-- Cooldown values per action type (in seconds)
local COOLDOWN_VALUES = {
	M1 = Config.LightAttack.Cooldown,      -- 0.6s
	M2 = Config.StrongAttack.Cooldown,     -- 3.0s
	Q = Config.Dash.Cooldown,              -- 2.0s
	C = Config.Slide.Cooldown,             -- 1.5s
	F = 0.3,                               -- Block toggle (300ms anti-spam)
}

-- ========================================
-- CONSTRUCTOR
-- ========================================

function CooldownManager.new(): CooldownManager
	local self = setmetatable({}, CooldownManager)
	
	self._cooldowns = {}
	self._connections = {}
	
	-- Setup automatic cleanup on player disconnect
	table.insert(self._connections, Players.PlayerRemoving:Connect(function(player)
		self:_CleanupPlayer(player)
	end))
	
	Logger:Info("CooldownManager initialized (server-side cooldown tracking)")
	
	return self
end

-- ========================================
-- SINGLETON GETTER
-- ========================================

function CooldownManager.GetInstance(): CooldownManager
	if not ManagerInstance then
		ManagerInstance = CooldownManager.new()
	end
	return ManagerInstance
end

-- ========================================
-- COOLDOWN VALIDATION
-- ========================================

---Checks if a player can perform an action (cooldown expired)
---@param player Player The player to check
---@param actionType string Action type ("M1", "M2", "Q", "C", "F")
---@return boolean canPerform True if action is off cooldown
function CooldownManager:CanPerformAction(player: Player, actionType: string): boolean
	-- Validate action type
	if not COOLDOWN_VALUES[actionType] then
		Logger:Warning("Invalid action type for cooldown check", {
			player = player.Name,
			actionType = actionType
		})
		return false
	end
	
	-- Initialize cooldowns for new player
	if not self._cooldowns[player] then
		self:_InitializePlayer(player)
		return true -- First action always allowed
	end
	
	local cooldowns = self._cooldowns[player]
	local lastUse = cooldowns[actionType] or 0
	local cooldownTime = COOLDOWN_VALUES[actionType]
	local now = os.clock()
	
	-- Check if cooldown has expired
	local isReady = (now - lastUse) >= cooldownTime
	
	if not isReady then
		local remaining = cooldownTime - (now - lastUse)
		Logger:Debug("Cooldown not ready", {
			player = player.Name,
			action = actionType,
			remaining = string.format("%.2fs", remaining)
		})
	end
	
	return isReady
end

---Records an action as performed (starts cooldown)
---@param player Player The player performing the action
---@param actionType string Action type ("M1", "M2", "Q", "C", "F")
function CooldownManager:RecordAction(player: Player, actionType: string)
	-- Validate action type
	if not COOLDOWN_VALUES[actionType] then
		Logger:Warning("Invalid action type for cooldown recording", {
			player = player.Name,
			actionType = actionType
		})
		return
	end
	
	-- Initialize if needed
	if not self._cooldowns[player] then
		self:_InitializePlayer(player)
	end
	
	-- Record timestamp
	self._cooldowns[player][actionType] = os.clock()
	
	Logger:Debug("Cooldown recorded", {
		player = player.Name,
		action = actionType,
		cooldown = string.format("%.2fs", COOLDOWN_VALUES[actionType])
	})
end

---Gets remaining cooldown time for an action
---@param player Player The player to check
---@param actionType string Action type ("M1", "M2", "Q", "C", "F")
---@return number remaining Remaining cooldown in seconds (0 if ready)
function CooldownManager:GetRemainingCooldown(player: Player, actionType: string): number
	-- Validate action type
	if not COOLDOWN_VALUES[actionType] then
		return 0
	end
	
	-- No cooldowns if player not tracked
	if not self._cooldowns[player] then
		return 0
	end
	
	local cooldowns = self._cooldowns[player]
	local lastUse = cooldowns[actionType] or 0
	local cooldownTime = COOLDOWN_VALUES[actionType]
	local now = os.clock()
	
	local remaining = cooldownTime - (now - lastUse)
	return math.max(0, remaining)
end

---Resets cooldown for a specific action (admin/testing use)
---@param player Player The player to reset cooldown for
---@param actionType string Action type to reset
function CooldownManager:ResetCooldown(player: Player, actionType: string)
	if not self._cooldowns[player] then
		return
	end
	
	if COOLDOWN_VALUES[actionType] then
		self._cooldowns[player][actionType] = 0
		Logger:Info("Cooldown reset", {
			player = player.Name,
			action = actionType
		})
	end
end

---Resets all cooldowns for a player (admin/testing use)
---@param player Player The player to reset cooldowns for
function CooldownManager:ResetAllCooldowns(player: Player)
	if not self._cooldowns[player] then
		return
	end
	
	for actionType, _ in pairs(COOLDOWN_VALUES) do
		self._cooldowns[player][actionType] = 0
	end
	
	Logger:Info("All cooldowns reset", {player = player.Name})
end

-- ========================================
-- PLAYER MANAGEMENT
-- ========================================

---Initializes cooldown tracking for a new player
---@param player Player The player to initialize
function CooldownManager:_InitializePlayer(player: Player)
	self._cooldowns[player] = {
		M1 = 0,
		M2 = 0,
		Q = 0,
		C = 0,
		F = 0,
	}
	
	Logger:Debug("Cooldowns initialized for player", {player = player.Name})
end

---Cleans up cooldown data when player leaves
---@param player Player The player leaving
function CooldownManager:_CleanupPlayer(player: Player)
	if self._cooldowns[player] then
		self._cooldowns[player] = nil
		Logger:Debug("Cooldowns cleaned up for player", {player = player.Name})
	end
end

-- ========================================
-- UTILITIES
-- ========================================

---Gets all active cooldowns for a player (debugging)
---@param player Player The player to check
---@return table cooldowns Table of {actionType = remainingTime}
function CooldownManager:GetAllCooldowns(player: Player): {[string]: number}
	if not self._cooldowns[player] then
		return {}
	end
	
	local activeCooldowns = {}
	for actionType, _ in pairs(COOLDOWN_VALUES) do
		local remaining = self:GetRemainingCooldown(player, actionType)
		if remaining > 0 then
			activeCooldowns[actionType] = remaining
		end
	end
	
	return activeCooldowns
end

---Gets total number of tracked players
---@return number count Number of players being tracked
function CooldownManager:GetTrackedPlayerCount(): number
	local count = 0
	for _ in pairs(self._cooldowns) do
		count += 1
	end
	return count
end

-- ========================================
-- CLEANUP
-- ========================================

function CooldownManager:Destroy()
	-- Disconnect all connections
	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end
	
	-- Clear all data
	table.clear(self._cooldowns)
	table.clear(self._connections)
	
	Logger:Info("CooldownManager destroyed")
end

return CooldownManager
