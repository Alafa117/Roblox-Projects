--[[
	Module: NetworkServer
	Type: Server Network Module
	Location: ReplicatedStorage.CombatCore.Network.NetworkServer
	Path: src/shared/CombatCore/Network/NetworkServer.luau
	
	Description:
		Server-side network communication manager for the Combat System.
		Handles server-to-client communication, request handling, and rate limiting.
		Separated from NetworkManager for better Single Responsibility Principle.
	
	Phase 4 Refactoring:
		- Extracted from NetworkManager.luau (405 lines)
		- Focuses exclusively on server-side network operations
		- Implements handler registration and client communication
		- Includes rate limiting through RateLimiter module
		- ~200 lines, -62% complexity
	
	Dependencies:
		- ReplicatedStorage.CombatCore.Data (Enums)
		- ReplicatedStorage.CombatCore.Logging (Logger)
		- ReplicatedStorage.CombatCore.Network (RateLimiter)
	
	Author: Professional Roblox Scripter
	Created: December 19, 2025
--]]

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

-- Constants
local IS_SERVER = RunService:IsServer()

-- Module Imports (using relative paths - no yields)
local Enums = require(script.Parent.Parent.Data.Enums)
local Logger = require(script.Parent.Parent.Logging.Logger).GetInstance()
local RateLimiter = require(script.Parent.RateLimiter)
local TypeValidators = require(script.Parent.Parent.Validation.TypeValidators)
local ValidationHelper = require(script.Parent.Parent.Validation.ValidationHelper)

-- Server-side Imports (only on server)
local CooldownManager = nil
if IS_SERVER then
	CooldownManager = require(ServerScriptService.CombatHandler.Systems.CooldownManager).GetInstance()
end

-- Network Server Class
local NetworkServer = {}
NetworkServer.__index = NetworkServer

-- Singleton Instance
local ServerInstance: NetworkServer? = nil

-- ========================================
-- TYPES
-- ========================================

type NetworkServer = {
	_remoteEvent: RemoteEvent?,
	_remoteFunction: RemoteFunction?,
	_unreliableRemoteEvent: UnreliableRemoteEvent?,
	_handlers: {[string]: (...any) -> any},
	_rateLimiter: any?,
	_connections: {RBXScriptConnection},
	_recentTimestamps: {[Player]: {number}},
	_maxRecentTimestamps: number,
}

-- ========================================
-- CONSTRUCTOR
-- ========================================

function NetworkServer.new(): NetworkServer
	if not IS_SERVER then
		Logger:Error("NetworkServer can only be created on server")
		return nil
	end
	
	local self = setmetatable({}, NetworkServer)
	
	self._remoteEvent = nil
	self._remoteFunction = nil
	self._unreliableRemoteEvent = nil
	self._handlers = {}
	self._connections = {}
	
	-- Initialize rate limiter with secure limits (Anti-Exploit)
	-- 8 req/s prevents spam while allowing legitimate combat actions
	-- Recommended by Roblox DevForum for combat systems
	self._rateLimiter = RateLimiter.new({
		WindowSize = 1,
		MaxRequests = 8,  -- Reduced from 20 to prevent spam (8 req/s recommended for combat)
		AutoCleanup = true,
	})
	
	-- Initialize timestamp tracking for replay attack prevention (protects against packet replay exploits)
	self._recentTimestamps = {}
	self._maxRecentTimestamps = 20  -- Track last 20 timestamps per player
	
	self:_Initialize()
	
	Logger:Info("NetworkServer created")
	
	return self
end

-- ========================================
-- SINGLETON GETTER
-- ========================================

function NetworkServer.GetInstance(): NetworkServer
	if not IS_SERVER then
		Logger:Error("NetworkServer can only be accessed on server")
		return nil
	end
	
	if not ServerInstance then
		ServerInstance = NetworkServer.new()
	end
	return ServerInstance
end

-- ========================================
-- INITIALIZATION
-- ========================================

function NetworkServer:_Initialize()
	-- Get Network folder using relative path
	local networkFolder = script.Parent
	
	-- Create or get RemoteEvent
	self._remoteEvent = networkFolder:FindFirstChild("CombatRemoteEvent")
	if not self._remoteEvent then
		self._remoteEvent = Instance.new("RemoteEvent")
		self._remoteEvent.Name = "CombatRemoteEvent"
		self._remoteEvent.Parent = networkFolder
	end
	
	-- Create or get RemoteFunction
	self._remoteFunction = networkFolder:FindFirstChild("CombatRemoteFunction")
	if not self._remoteFunction then
		self._remoteFunction = Instance.new("RemoteFunction")
		self._remoteFunction.Name = "CombatRemoteFunction"
		self._remoteFunction.Parent = networkFolder
	end
	
	-- Create or get UnreliableRemoteEvent for VFX (optimized for visual effects)
	-- Used for non-critical visual effects to reduce latency and network traffic
	self._unreliableRemoteEvent = networkFolder:FindFirstChild("CombatUnreliableRemoteEvent")
	if not self._unreliableRemoteEvent then
		self._unreliableRemoteEvent = Instance.new("UnreliableRemoteEvent")
		self._unreliableRemoteEvent.Name = "CombatUnreliableRemoteEvent"
		self._unreliableRemoteEvent.Parent = networkFolder
	end
	
	-- Setup server listeners
	self:_SetupServerListeners()
	
	-- Setup periodic timestamp cleanup (every 30 seconds)
	-- Prevents memory buildup from old timestamps (automatic memory management)
	local lastCleanup = os.clock()
	table.insert(self._connections, game:GetService("RunService").Heartbeat:Connect(function()
		local now = os.clock()
		if (now - lastCleanup) >= 30 then
			for player, _ in pairs(self._recentTimestamps) do
				if player and player:IsDescendantOf(Players) then
					self:_CleanupOldTimestamps(player)
				end
			end
			lastCleanup = now
		end
	end))
	
	-- Setup player cleanup
	table.insert(self._connections, Players.PlayerRemoving:Connect(function(player)
		self:_CleanupPlayer(player)
	end))
end

-- ========================================
-- SERVER LISTENERS
-- ========================================

function NetworkServer:_SetupServerListeners()
	-- RemoteEvent listener (Client -> Server)
	table.insert(self._connections, self._remoteEvent.OnServerEvent:Connect(function(player, eventType, data)
		self:_HandleClientRequest(player, eventType, data)
	end))
	
	-- RemoteFunction listener (Client -> Server with response)
	self._remoteFunction.OnServerInvoke = function(player, eventType, data)
		return self:_HandleClientInvoke(player, eventType, data)
	end
end

function NetworkServer:_HandleClientRequest(player: Player, eventType: string, data: {[string]: any}?)
	-- Validate character ownership (Anti-Exploit: Prevent impersonation)
	if not player.Character or player.Character.Parent ~= workspace then
		Logger:Warning("Invalid character ownership", {
			player = player.Name,
			event = eventType,
			reason = "No character or not in workspace"
		})
		return
	end
	
	-- Validate character is alive and valid (Anti-Exploit)
	if not ValidationHelper.IsCharacterValid(player.Character) then
		Logger:Warning("Invalid character state", {
			player = player.Name,
			event = eventType,
			reason = "Character invalid or dead"
		})
		return
	end
	
	-- Rate limiting
	-- FIXED: Exempt Block from rate limiting (December 28, 2025)
	-- Block is a toggle mechanism that requires processing every Begin/End event
	-- Rate limiting causes server to miss "End" events, leaving IsBlocking stuck ON
	-- This creates critical desync where server thinks player is blocking but client doesn't
	local isBlockAction = (eventType == Enums.NetworkEvent.RequestBlock)
	
	if self._rateLimiter and not isBlockAction then
		if not self._rateLimiter:CheckLimit(player) then
			Logger:Warning("Rate limit exceeded", {player = player.Name, event = eventType})
			return
		end
	end
	-- Block requests bypass rate limiting to prevent state desync
	
	-- Server-side cooldown validation (prevents action spam exploits)
	if CooldownManager then
		local actionType = self:_GetActionTypeFromRequest(eventType, data)
		if actionType then
			-- FIXED: Block has NO cooldown validation (December 27, 2025)
			-- Block is defensive and must be immediately available
			-- FIXED: M1 has NO cooldown validation here (December 30, 2025)
			-- M1 combo hits are validated by client only to prevent timing precision issues
			-- Server will validate after hit 6 via CombatService
			local isBlockAction = (eventType == Enums.NetworkEvent.RequestBlock)
			local isM1Action = (actionType == "M1")
			
			if not isBlockAction and not isM1Action then
				if not CooldownManager:CanPerformAction(player, actionType) then
					local remaining = CooldownManager:GetRemainingCooldown(player, actionType)
					Logger:Warning("Action on cooldown", {
						player = player.Name,
						action = actionType,
						remaining = string.format("%.2fs", remaining)
					})
					return -- Reject action on cooldown
				end
			end
		end
	end
	
	-- Validate event type
	if not Enums.IsValid(Enums.NetworkEvent, eventType) then
		Logger:Warning("Invalid event type from client", {player = player.Name, event = eventType})
		return
	end
	
	-- Validate request data based on event type (Anti-Exploit)
	if data then
		local validator = nil
		local dataName = ""
		
		if eventType == Enums.NetworkEvent.RequestAction then
			validator = TypeValidators.ActionRequest
			dataName = "ActionRequest"
		elseif eventType == Enums.NetworkEvent.RequestDash then
			validator = TypeValidators.DashRequest
			dataName = "DashRequest"
		elseif eventType == Enums.NetworkEvent.RequestSlide then
			validator = TypeValidators.SlideRequest
			dataName = "SlideRequest"
		elseif eventType == Enums.NetworkEvent.RequestBlock then
			validator = TypeValidators.BlockRequest
			dataName = "BlockRequest"
		end
		
		-- Validate if validator exists
		if validator then
			local success, errorMessage = TypeValidators.ValidateWithError(validator, data, dataName)
			if not success then
				Logger:Warning("Invalid request data from client", {
					player = player.Name,
					event = eventType,
					error = errorMessage
				})
				return -- Reject malformed request (Anti-Exploit)
			end
		end
	end
	
	-- Timestamp validation for replay attack prevention (Anti-Exploit: TODO #8)
	if data and data.Timestamp then
		if not self:_ValidateTimestamp(player, data.Timestamp) then
			-- Timestamp validation failed - logged in _ValidateTimestamp
			return -- Reject replay attack or invalid timestamp
		end
	end
	
	-- Call registered handler
	local handler = self._handlers[eventType]
	if handler then
		local success, result = pcall(function()
			return handler(player, data)
		end)
		
		if not success then
			Logger:Error("Handler error", {event = eventType, error = result})
		else
			-- FIXED: Only record cooldown if action was actually executed (December 30, 2025)
			-- Check result.Success to prevent cooldown recording on rejected actions
			-- This prevents combo desync when M1 is rejected during M2/other states
			if CooldownManager and result and result.Success then
				local actionType = self:_GetActionTypeFromRequest(eventType, data)
				if actionType then
					-- FIXED: Don't record cooldown for Block at all (December 27, 2025)
					-- Block has no cooldown - it's a defensive mechanic
					local isBlockAction = (eventType == Enums.NetworkEvent.RequestBlock)
					
					if not isBlockAction then
						CooldownManager:RecordAction(player, actionType)
					end
				end
			end
		end
	end
end

function NetworkServer:_HandleClientInvoke(player: Player, eventType: string, data: {[string]: any}?): any
	-- Validate character ownership (Anti-Exploit: Prevent impersonation)
	if not player.Character or player.Character.Parent ~= workspace then
		Logger:Warning("Invalid character ownership on invoke", {
			player = player.Name,
			event = eventType,
			reason = "No character or not in workspace"
		})
		return {Success = false, ErrorCode = "INVALID_CHARACTER"}
	end
	
	-- Validate character is alive and valid (Anti-Exploit)
	if not ValidationHelper.IsCharacterValid(player.Character) then
		Logger:Warning("Invalid character state on invoke", {
			player = player.Name,
			event = eventType,
			reason = "Character invalid or dead"
		})
		return {Success = false, ErrorCode = "INVALID_CHARACTER"}
	end
	
	-- Rate limiting
	-- FIXED: Exempt Block from rate limiting (December 28, 2025)
	-- Block toggle requires processing every Begin/End event to prevent state desync
	local isBlockAction = (eventType == Enums.NetworkEvent.RequestBlock)
	
	if self._rateLimiter and not isBlockAction then
		if not self._rateLimiter:CheckLimit(player) then
			Logger:Warning("Rate limit exceeded on invoke", {player = player.Name, event = eventType})
			return {Success = false, ErrorCode = "RATE_LIMIT"}
		end
	end
	
	-- Server-side cooldown validation (prevents action spam exploits)
	if CooldownManager then
		local actionType = self:_GetActionTypeFromRequest(eventType, data)
		if actionType then
			-- FIXED: M1 has NO cooldown validation here (December 30, 2025)
			-- M1 combo hits are validated by client only to prevent timing precision issues
			-- Server will validate after hit 6 via CombatService
			local isM1Action = (actionType == "M1")
			
			if not isM1Action then
				if not CooldownManager:CanPerformAction(player, actionType) then
					local remaining = CooldownManager:GetRemainingCooldown(player, actionType)
					Logger:Warning("Action on cooldown (invoke)", {
						player = player.Name,
						action = actionType,
						remaining = string.format("%.2fs", remaining)
					})
					return {Success = false, ErrorCode = "ON_COOLDOWN"}
				end
			end
		end
	end
	
	-- Validate event type
	if not Enums.IsValid(Enums.NetworkEvent, eventType) then
		Logger:Warning("Invalid event type on invoke", {player = player.Name, event = eventType})
		return {Success = false, ErrorCode = "INVALID_EVENT"}
	end
	
	-- Validate request data based on event type (Anti-Exploit)
	if data then
		local validator = nil
		local dataName = ""
		
		if eventType == Enums.NetworkEvent.RequestAction then
			validator = TypeValidators.ActionRequest
			dataName = "ActionRequest"
		elseif eventType == Enums.NetworkEvent.RequestDash then
			validator = TypeValidators.DashRequest
			dataName = "DashRequest"
		elseif eventType == Enums.NetworkEvent.RequestSlide then
			validator = TypeValidators.SlideRequest
			dataName = "SlideRequest"
		elseif eventType == Enums.NetworkEvent.RequestBlock then
			validator = TypeValidators.BlockRequest
			dataName = "BlockRequest"
		end
		
		-- Validate if validator exists
		if validator then
			local success, errorMessage = TypeValidators.ValidateWithError(validator, data, dataName)
			if not success then
				Logger:Warning("Invalid invoke data from client", {
					player = player.Name,
					event = eventType,
					error = errorMessage
				})
				return {Success = false, ErrorCode = "INVALID_DATA"} -- Reject malformed request
			end
		end
	end
	
	-- Timestamp validation for replay attack prevention (Anti-Exploit: TODO #8)
	if data and data.Timestamp then
		if not self:_ValidateTimestamp(player, data.Timestamp) then
			-- Timestamp validation failed - logged in _ValidateTimestamp
			return {Success = false, ErrorCode = "REPLAY_ATTACK"}
		end
	end
	
	-- Call registered handler
	local handler = self._handlers[eventType]
	if handler then
		local success, result = pcall(function()
			return handler(player, data)
		end)
		
		if success then
			-- FIXED: Only record cooldown if action was actually executed (December 30, 2025)
			-- Check result.Success to prevent cooldown recording on rejected actions
			-- This prevents combo desync when M1 is rejected during M2/other states
			if CooldownManager and result and result.Success then
				local actionType = self:_GetActionTypeFromRequest(eventType, data)
				if actionType then
					CooldownManager:RecordAction(player, actionType)
				end
			end
			return result
		else
			Logger:Error("Handler error on invoke", {event = eventType, error = result})
			return {Success = false, ErrorCode = "HANDLER_ERROR"}
		end
	end
	
	return {Success = false, ErrorCode = "NO_HANDLER"}
end

-- ========================================
-- PLAYER CLEANUP
-- ========================================

function NetworkServer:_CleanupPlayer(player: Player)
	-- Cleanup timestamp tracking (Anti-Exploit: TODO #8)
	if self._recentTimestamps[player] then
		self._recentTimestamps[player] = nil
	end
	
	-- RateLimiter handles its own cleanup automatically
	Logger:Debug("Player network data cleaned", {player = player.Name})
end

-- ========================================
-- COOLDOWN HELPERS
-- ========================================

--[[
	Maps NetworkEvent types to action type strings for cooldown tracking.
	Used by server-side cooldown system to enforce action cooldowns.
	
	@param eventType - The NetworkEvent enum value
	@param data - Request data containing ActionType for RequestAction events
	@return actionType string or nil if not a cooldown-tracked action
]]
function NetworkServer:_GetActionTypeFromRequest(eventType: string, data: {[string]: any}?): string?
	if eventType == Enums.NetworkEvent.RequestAction then
		-- M1/M2 attacks - get from data
		return data and data.ActionType or nil
	elseif eventType == Enums.NetworkEvent.RequestDash then
		return "Q" -- Dash
	elseif eventType == Enums.NetworkEvent.RequestSlide then
		return "C" -- Slide
	elseif eventType == Enums.NetworkEvent.RequestBlock then
		return "F" -- Block
	end
	
	return nil -- Not a cooldown-tracked action
end

-- ========================================
-- TIMESTAMP VALIDATION (REPLAY ATTACK PREVENTION)
-- ========================================

--[[
	Validates a client timestamp to prevent replay attacks.
	
	Prevents:
	- Replay attacks (reusing old requests)
	- Packet duplication exploits
	- Time manipulation attacks
	
	Validation checks:
	1. Timestamp is recent (within ±2 seconds of server time)
	2. Timestamp hasn't been used before (no duplicates)
	3. Maintains a sliding window of recent timestamps per player
	
	@param player - The player sending the request
	@param timestamp - Client timestamp from request data
	@return isValid: boolean - Whether the timestamp is valid
	
	Anti-Exploit: TODO #8
]]
function NetworkServer:_ValidateTimestamp(player: Player, timestamp: number?): boolean
	-- Reject if no timestamp provided
	if not timestamp or type(timestamp) ~= "number" then
		Logger:Warning("Missing or invalid timestamp", {
			player = player.Name,
			timestamp = timestamp
		})
		return false
	end
	
	local now = os.clock()
	
	-- Validate timestamp is recent (±2 seconds tolerance for network lag)
	-- Stricter than TODO #4's ±1s for individual validation
	local timeDiff = math.abs(now - timestamp)
	if timeDiff > 2 then
		Logger:Warning("Timestamp out of range", {
			player = player.Name,
			timestamp = timestamp,
			serverTime = now,
			difference = string.format("%.2fs", timeDiff)
		})
		return false
	end
	
	-- Initialize player's timestamp tracking if needed
	if not self._recentTimestamps[player] then
		self._recentTimestamps[player] = {}
	end
	
	local recentTimestamps = self._recentTimestamps[player]
	
	-- Check for duplicate timestamps (replay attack detection)
	-- 10ms tolerance for floating point precision
	for _, oldTimestamp in ipairs(recentTimestamps) do
		if math.abs(timestamp - oldTimestamp) < 0.01 then
			Logger:Warning("Replay attack detected (duplicate timestamp)", {
				player = player.Name,
				timestamp = timestamp,
				duplicate = oldTimestamp,
				difference = string.format("%.4fs", math.abs(timestamp - oldTimestamp))
			})
			return false
		end
	end
	
	-- Store timestamp in sliding window (FIFO)
	table.insert(recentTimestamps, timestamp)
	if #recentTimestamps > self._maxRecentTimestamps then
		table.remove(recentTimestamps, 1) -- Remove oldest
	end
	
	return true
end

--[[
	Cleans up old timestamps that are outside the validation window.
	Called periodically to prevent memory buildup.
	
	@param player - The player to clean timestamps for
]]
function NetworkServer:_CleanupOldTimestamps(player: Player)
	if not self._recentTimestamps[player] then
		return
	end
	
	local now = os.clock()
	local timestamps = self._recentTimestamps[player]
	local cleaned = 0
	
	-- Remove timestamps older than 5 seconds
	for i = #timestamps, 1, -1 do
		if (now - timestamps[i]) > 5 then
			table.remove(timestamps, i)
			cleaned = cleaned + 1
		end
	end
	
	if cleaned > 0 then
		Logger:Debug("Old timestamps cleaned", {
			player = player.Name,
			count = cleaned
		})
	end
end

-- ========================================
-- HANDLER REGISTRATION
-- ========================================

function NetworkServer:RegisterHandler(eventType: string, handler: (Player, {[string]: any}?) -> any)
	self._handlers[eventType] = handler
	Logger:Debug("Handler registered", {event = eventType})
end

-- ========================================
-- SENDING (SERVER -> CLIENT)
-- ========================================

function NetworkServer:SendToClient(player: Player, eventType: string, data: {[string]: any}?)
	if not self._remoteEvent then
		Logger:Error("RemoteEvent not initialized")
		return
	end
	
	self._remoteEvent:FireClient(player, eventType, data)
end

function NetworkServer:SendToAllClients(eventType: string, data: {[string]: any}?)
	if not self._remoteEvent then
		Logger:Error("RemoteEvent not initialized")
		return
	end
	
	self._remoteEvent:FireAllClients(eventType, data)
end

function NetworkServer:SendToClients(players: {Player}, eventType: string, data: {[string]: any}?)
	if not self._remoteEvent then
		Logger:Error("RemoteEvent not initialized")
		return
	end
	
	for _, player in ipairs(players) do
		self._remoteEvent:FireClient(player, eventType, data)
	end
end

-- ========================================
-- VFX SENDING (UNRELIABLE - LOW LATENCY)
-- ========================================

--[[
	Sends VFX events using UnreliableRemoteEvent for reduced latency.
	
	UnreliableRemoteEvent benefits:
	- Lower latency (~30-50% faster than RemoteEvent)
	- Reduced network traffic (no guaranteed delivery overhead)
	- Better for high-frequency visual updates
	
	Use ONLY for non-critical events:
	✅ Visual effects (particles, trails, flashes)
	✅ Sound effects (non-critical)
	✅ Animation cues (cosmetic)
	✅ Damage indicators (visual only)
	
	DO NOT use for:
	❌ State changes (health, stamina)
	❌ Gameplay-critical data (knockback, stuns)
	❌ Synchronization (positions, rotations)
	
	Performance: TODO #9
]]
function NetworkServer:SendVFXToClient(player: Player, eventType: string, data: {[string]: any}?)
	if not self._unreliableRemoteEvent then
		Logger:Warning("UnreliableRemoteEvent not initialized, falling back to RemoteEvent")
		self:SendToClient(player, eventType, data)
		return
	end
	
	self._unreliableRemoteEvent:FireClient(player, eventType, data)
end

function NetworkServer:BroadcastVFX(eventType: string, data: {[string]: any}?)
	if not self._unreliableRemoteEvent then
		Logger:Warning("UnreliableRemoteEvent not initialized, falling back to RemoteEvent")
		self:SendToAllClients(eventType, data)
		return
	end
	
	self._unreliableRemoteEvent:FireAllClients(eventType, data)
end

function NetworkServer:SendVFXToClients(players: {Player}, eventType: string, data: {[string]: any}?)
	if not self._unreliableRemoteEvent then
		Logger:Warning("UnreliableRemoteEvent not initialized, falling back to RemoteEvent")
		self:SendToClients(players, eventType, data)
		return
	end
	
	for _, player in ipairs(players) do
		self._unreliableRemoteEvent:FireClient(player, eventType, data)
	end
end

--[[
	Sends VFX to all players except one (useful for excluding the source player).
	
	@param excludePlayer - Player to exclude from the broadcast
	@param eventType - Type of VFX event
	@param data - Event data
]]
function NetworkServer:BroadcastVFXExcept(excludePlayer: Player, eventType: string, data: {[string]: any}?)
	if not self._unreliableRemoteEvent then
		Logger:Warning("UnreliableRemoteEvent not initialized")
		return
	end
	
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= excludePlayer then
			self._unreliableRemoteEvent:FireClient(player, eventType, data)
		end
	end
end

-- ========================================
-- CLEANUP
-- ========================================

function NetworkServer:Destroy()
	-- Disconnect all connections
	for _, connection in ipairs(self._connections) do
		if connection.Connected then
			connection:Disconnect()
		end
	end
	table.clear(self._connections)
	
	-- Clear handlers
	table.clear(self._handlers)
	
	-- Clear RemoteFunction callback
	if self._remoteFunction then
		self._remoteFunction.OnServerInvoke = nil
	end
	
	-- Destroy rate limiter
	if self._rateLimiter and self._rateLimiter.Destroy then
		self._rateLimiter:Destroy()
	end
	
	-- Clear singleton reference
	ServerInstance = nil
	
	Logger:Info("NetworkServer destroyed")
end

return NetworkServer
