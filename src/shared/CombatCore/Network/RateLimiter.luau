--[[
	Module: RateLimiter
	Type: Network Utility Module
	Location: ReplicatedStorage.CombatCore.Network.RateLimiter
	Path: src/shared/CombatCore/Network/RateLimiter.luau
	
	Description:
		Dedicated rate limiting utility for network requests.
		Tracks request counts per player within sliding time windows.
		Prevents spam and abuse by enforcing configurable request limits.
		
		Uses sliding window algorithm for accurate rate limiting with
		automatic cleanup on player removal.
	
	Phase 3 Refactoring:
		- Extracted from NetworkManager.luau
		- Single Responsibility: Only handles rate limiting logic
		- Configurable window size and max requests
		- Memory-efficient with automatic cleanup
	
	Dependencies:
		- game.Players (service)
		- ReplicatedStorage.CombatCore.Core.Logger
	
	Author: Professional Roblox Scripter
	Created: December 14, 2025
--]]

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Module Imports
local Core = ReplicatedStorage:WaitForChild("CombatCore"):WaitForChild("Core")
local Logger = require(Core.Logger).GetInstance()

-- Rate Limiter Module
local RateLimiter = {}

-- ========================================
-- TYPES
-- ========================================

type RateLimitData = {
	RequestCount: number,
	WindowStart: number,
}

type RateLimiterConfig = {
	WindowSize: number,      -- Seconds per window
	MaxRequests: number,     -- Max requests per window
	AutoCleanup: boolean,    -- Cleanup on player leave
}

type RateLimiter = {
	_config: RateLimiterConfig,
	_rateLimits: {[Player]: RateLimitData},
	_cleanupConnection: RBXScriptConnection?,
}

-- ========================================
-- CONSTRUCTOR
-- ========================================

function RateLimiter.new(config: RateLimiterConfig?): RateLimiter
	local self = setmetatable({}, {__index = RateLimiter})
	
	-- Default configuration
	self._config = config or {
		WindowSize = 1,      -- 1 second window
		MaxRequests = 20,    -- 20 requests per second
		AutoCleanup = true,
	}
	
	self._rateLimits = {}
	self._cleanupConnection = nil
	
	-- Auto-cleanup on player leave
	if self._config.AutoCleanup then
		self._cleanupConnection = Players.PlayerRemoving:Connect(function(player)
			self:CleanupPlayer(player)
		end)
	end
	
	Logger:Debug("RateLimiter created", {
		windowSize = self._config.WindowSize,
		maxRequests = self._config.MaxRequests,
	})
	
	return self
end

-- ========================================
-- RATE LIMITING
-- ========================================

-- Checks if a player can make a request (hasn't exceeded limit)
-- @param player: Player to check rate limit for
-- @return boolean: true if allowed, false if rate limit exceeded
function RateLimiter:CheckLimit(player: Player): boolean
	local now = os.clock()
	local limitData = self._rateLimits[player]
	
	-- First request from this player
	if not limitData then
		self._rateLimits[player] = {
			RequestCount = 1,
			WindowStart = now,
		}
		return true
	end
	
	-- Check if current window expired (sliding window)
	local timeSinceWindowStart = now - limitData.WindowStart
	if timeSinceWindowStart >= self._config.WindowSize then
		-- Reset window
		limitData.RequestCount = 1
		limitData.WindowStart = now
		return true
	end
	
	-- Check if limit exceeded in current window
	if limitData.RequestCount >= self._config.MaxRequests then
		Logger:Warning("Rate limit exceeded", {
			player = player.Name,
			requests = limitData.RequestCount,
			window = self._config.WindowSize,
		})
		return false
	end
	
	-- Increment counter and allow
	limitData.RequestCount += 1
	return true
end

-- Gets current request count for a player
-- @param player: Player to get count for
-- @return number: Current request count in window (0 if none)
function RateLimiter:GetRequestCount(player: Player): number
	local limitData = self._rateLimits[player]
	if not limitData then
		return 0
	end
	
	local now = os.clock()
	local timeSinceWindowStart = now - limitData.WindowStart
	
	-- Expired window
	if timeSinceWindowStart >= self._config.WindowSize then
		return 0
	end
	
	return limitData.RequestCount
end

-- Resets rate limit for a specific player
-- @param player: Player to reset
function RateLimiter:ResetPlayer(player: Player)
	self._rateLimits[player] = nil
	Logger:Debug("Rate limit reset", {player = player.Name})
end

-- Cleans up rate limit data for a player
-- @param player: Player to cleanup
function RateLimiter:CleanupPlayer(player: Player)
	self._rateLimits[player] = nil
	Logger:Debug("Rate limit data cleaned", {player = player.Name})
end

-- ========================================
-- CONFIGURATION
-- ========================================

-- Updates rate limiter configuration
-- @param newConfig: Partial config to merge with existing
function RateLimiter:UpdateConfig(newConfig: {
	WindowSize: number?,
	MaxRequests: number?,
	AutoCleanup: boolean?,
})
	if newConfig.WindowSize then
		self._config.WindowSize = newConfig.WindowSize
	end
	if newConfig.MaxRequests then
		self._config.MaxRequests = newConfig.MaxRequests
	end
	if newConfig.AutoCleanup ~= nil then
		self._config.AutoCleanup = newConfig.AutoCleanup
		
		-- Setup or teardown cleanup connection
		if newConfig.AutoCleanup and not self._cleanupConnection then
			self._cleanupConnection = Players.PlayerRemoving:Connect(function(player)
				self:CleanupPlayer(player)
			end)
		elseif not newConfig.AutoCleanup and self._cleanupConnection then
			self._cleanupConnection:Disconnect()
			self._cleanupConnection = nil
		end
	end
	
	Logger:Info("RateLimiter config updated", self._config)
end

-- Gets current configuration
-- @return RateLimiterConfig: Current config (copy)
function RateLimiter:GetConfig(): RateLimiterConfig
	return {
		WindowSize = self._config.WindowSize,
		MaxRequests = self._config.MaxRequests,
		AutoCleanup = self._config.AutoCleanup,
	}
end

-- ========================================
-- CLEANUP
-- ========================================

-- Destroys the rate limiter and cleans up connections
function RateLimiter:Destroy()
	if self._cleanupConnection then
		self._cleanupConnection:Disconnect()
		self._cleanupConnection = nil
	end
	
	self._rateLimits = {}
	
	Logger:Debug("RateLimiter destroyed")
end

return RateLimiter
