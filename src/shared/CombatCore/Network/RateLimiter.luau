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
		- ReplicatedStorage.CombatCore.Logging.Logger
	
	Author: Professional Roblox Scripter
	Created: December 14, 2025
--]]

-- Services
local Players = game:GetService("Players")

-- Module Imports (using relative paths - no yields)
local Logger = require(script.Parent.Parent.Logging.Logger).GetInstance()

-- Rate Limiter Module
local RateLimiter = {}

-- ========================================
-- TYPES
-- ========================================

type RateLimitData = {
	RequestCount: number,
	WindowStart: number,
	Violations: number,
	LastViolationTime: number?,
}

type RateLimiterConfig = {
	WindowSize: number,      -- Seconds per window
	MaxRequests: number,     -- Max requests per window
	AutoCleanup: boolean,    -- Cleanup on player leave
	MaxViolations: number?,  -- Max violations before kick (nil = no kick)
	ViolationDecayTime: number?, -- Time before violation count decays (seconds)
	KickMessage: string?,    -- Custom kick message
}

type RateLimiter = {
	_config: RateLimiterConfig,
	_rateLimits: {[Player]: RateLimitData},
	_cleanupConnection: RBXScriptConnection?,
	_whitelistedPlayers: {[Player]: boolean},
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
		MaxViolations = 10,  -- Kick after 10 violations (Anti-Exploit: TODO #10)
		ViolationDecayTime = 60, -- Decay violations after 60s
		KickMessage = "Rate limit exceeded. Possible exploit detected.",
	}
	
	self._rateLimits = {}
	self._cleanupConnection = nil
	self._whitelistedPlayers = {} -- Admins/testers exempt from kick
	
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
	-- Check if player is whitelisted (admins/testers)
	if self._whitelistedPlayers[player] then
		return true
	end
	
	local now = os.clock()
	local limitData = self._rateLimits[player]
	
	-- First request from this player
	if not limitData then
		self._rateLimits[player] = {
			RequestCount = 1,
			WindowStart = now,
			Violations = 0,
			LastViolationTime = nil,
		}
		return true
	end
	
	-- Decay violations over time (Anti-Exploit: TODO #10)
	if self._config.ViolationDecayTime and limitData.LastViolationTime then
		local timeSinceLastViolation = now - limitData.LastViolationTime
		if timeSinceLastViolation >= self._config.ViolationDecayTime then
			-- Decay one violation per decay period
			local decayCount = math.floor(timeSinceLastViolation / self._config.ViolationDecayTime)
			limitData.Violations = math.max(0, limitData.Violations - decayCount)
			
			if limitData.Violations == 0 then
				limitData.LastViolationTime = nil
			end
		end
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
		-- Increment violation count (Anti-Exploit: TODO #10)
		limitData.Violations = limitData.Violations + 1
		limitData.LastViolationTime = now
		
		Logger:Warning("Rate limit exceeded", {
			player = player.Name,
			requests = limitData.RequestCount,
			window = self._config.WindowSize,
			violations = limitData.Violations,
		})
		
		-- Check for auto-kick threshold (Anti-Exploit: TODO #10)
		if self._config.MaxViolations and limitData.Violations >= self._config.MaxViolations then
			self:_KickPlayer(player, limitData.Violations)
		elseif self._config.MaxViolations then
			-- Progressive warnings
			local remainingViolations = self._config.MaxViolations - limitData.Violations
			if remainingViolations <= 3 then
				Logger:Warning("Player near kick threshold", {
					player = player.Name,
					violations = limitData.Violations,
					remaining = remainingViolations,
				})
			end
		end
		
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
	self._whitelistedPlayers[player] = nil
	Logger:Debug("Rate limit data cleaned", {player = player.Name})
end

-- ========================================
-- VIOLATION MANAGEMENT (AUTO-KICK SYSTEM)
-- ========================================

--[[
	Kicks a player for excessive rate limit violations.
	Logs critical event and removes player from server.
	
	@param player - Player to kick
	@param violationCount - Total violations before kick
	
	Anti-Exploit: TODO #10
]]
function RateLimiter:_KickPlayer(player: Player, violationCount: number)
	Logger:Critical("Auto-kicking player for rate limit violations", {
		player = player.Name,
		userId = player.UserId,
		violations = violationCount,
		maxAllowed = self._config.MaxViolations,
	})
	
	-- Kick with custom message
	local kickMessage = self._config.KickMessage or "Rate limit exceeded. Possible exploit detected."
	player:Kick(kickMessage)
end

--[[
	Gets violation count for a player.
	
	@param player - Player to check
	@return number - Current violation count (0 if none)
]]
function RateLimiter:GetViolations(player: Player): number
	local limitData = self._rateLimits[player]
	if not limitData then
		return 0
	end
	return limitData.Violations
end

--[[
	Resets violation count for a player (admin function).
	
	@param player - Player to reset violations for
]]
function RateLimiter:ResetViolations(player: Player)
	local limitData = self._rateLimits[player]
	if limitData then
		limitData.Violations = 0
		limitData.LastViolationTime = nil
		Logger:Info("Violations reset", {player = player.Name})
	end
end

--[[
	Adds a player to the whitelist (exempt from rate limit kicks).
	Useful for admins, testers, and VIP players.
	
	@param player - Player to whitelist
]]
function RateLimiter:WhitelistPlayer(player: Player)
	self._whitelistedPlayers[player] = true
	Logger:Info("Player whitelisted", {player = player.Name})
end

--[[
	Removes a player from the whitelist.
	
	@param player - Player to remove from whitelist
]]
function RateLimiter:RemoveFromWhitelist(player: Player)
	self._whitelistedPlayers[player] = nil
	Logger:Info("Player removed from whitelist", {player = player.Name})
end

--[[
	Checks if a player is whitelisted.
	
	@param player - Player to check
	@return boolean - True if whitelisted
]]
function RateLimiter:IsWhitelisted(player: Player): boolean
	return self._whitelistedPlayers[player] == true
end

--[[
	Gets statistics about all tracked players.
	
	@return stats - {TrackedPlayers, TotalViolations, PlayersNearKick}
]]
function RateLimiter:GetStats(): {TrackedPlayers: number, TotalViolations: number, PlayersNearKick: number}
	local trackedPlayers = 0
	local totalViolations = 0
	local playersNearKick = 0
	
	for player, data in pairs(self._rateLimits) do
		trackedPlayers = trackedPlayers + 1
		totalViolations = totalViolations + data.Violations
		
		if self._config.MaxViolations and data.Violations >= (self._config.MaxViolations - 2) then
			playersNearKick = playersNearKick + 1
		end
	end
	
	return {
		TrackedPlayers = trackedPlayers,
		TotalViolations = totalViolations,
		PlayersNearKick = playersNearKick,
		WhitelistedPlayers = 0, -- Count whitelisted
	}
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
	MaxViolations: number?,
	ViolationDecayTime: number?,
	KickMessage: string?,
})
	if newConfig.WindowSize then
		self._config.WindowSize = newConfig.WindowSize
	end
	if newConfig.MaxRequests then
		self._config.MaxRequests = newConfig.MaxRequests
	end
	if newConfig.MaxViolations ~= nil then
		self._config.MaxViolations = newConfig.MaxViolations
	end
	if newConfig.ViolationDecayTime then
		self._config.ViolationDecayTime = newConfig.ViolationDecayTime
	end
	if newConfig.KickMessage then
		self._config.KickMessage = newConfig.KickMessage
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
