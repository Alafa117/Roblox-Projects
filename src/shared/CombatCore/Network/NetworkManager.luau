--[[
	Module: NetworkManager
	Type: Shared Network Manager
	Location: ReplicatedStorage.CombatCore.Network.NetworkManager
	Path: src/shared/CombatCore/Network/NetworkManager.luau
	
	Description:
		Centralized network communication manager for the Combat System.
		Handles all client-server communication with RemoteEvents and RemoteFunctions.
		Implements rate limiting, packet validation, and callback registration.
		Provides separate client and server instances for proper encapsulation.
	
	Dependencies:
		- ReplicatedStorage.CombatCore.Core (Enums, Types, Logger)
	
	Author: Professional Roblox Scripter
	Created: December 11, 2025
--]]

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Module Imports
local RS = ReplicatedStorage
local CombatSystem = RS:WaitForChild("CombatCore")
local Core = CombatSystem:WaitForChild("Core")

local Enums = require(Core.Enums)
local Logger = require(Core.Logger).GetInstance()

-- Constants
local IS_SERVER = RunService:IsServer()
local IS_CLIENT = RunService:IsClient()
local RATE_LIMIT_WINDOW = 1 -- Seconds
local MAX_REQUESTS_PER_WINDOW = 20

-- Network Manager Class
local NetworkManager = {}
NetworkManager.__index = NetworkManager

-- Singleton Instances
local ServerInstance: NetworkManager? = nil
local ClientInstance: NetworkManager? = nil

-- ========================================
-- TYPES
-- ========================================

type RateLimitData = {
	RequestCount: number,
	WindowStart: number,
}

type NetworkManager = {
	_remoteEvent: RemoteEvent?,
	_remoteFunction: RemoteFunction?,
	_handlers: {[string]: (...any) -> any},
	_callbacks: {[string]: {(...any) -> ()}},
	_rateLimits: {[Player]: RateLimitData}?,
	_isServer: boolean,
	_isClient: boolean,
}

-- ========================================
-- CONSTRUCTOR
-- ========================================

function NetworkManager.new(isServer: boolean): NetworkManager
	local self = setmetatable({}, NetworkManager)
	
	self._remoteEvent = nil
	self._remoteFunction = nil
	self._handlers = {}
	self._callbacks = {}
	self._rateLimits = isServer and {} or nil
	self._isServer = isServer
	self._isClient = not isServer
	
	self:_Initialize()
	
	Logger:Info("NetworkManager created", {side = isServer and "Server" or "Client"})
	
	return self
end

-- ========================================
-- SINGLETON GETTERS
-- ========================================

function NetworkManager.GetServerInstance(): NetworkManager
	if not IS_SERVER then
		Logger:Error("Attempted to get server instance on client")
		return nil
	end
	
	if not ServerInstance then
		ServerInstance = NetworkManager.new(true)
	end
	return ServerInstance
end

function NetworkManager.GetClientInstance(): NetworkManager
	if not IS_CLIENT then
		Logger:Error("Attempted to get client instance on server")
		return nil
	end
	
	if not ClientInstance then
		ClientInstance = NetworkManager.new(false)
	end
	return ClientInstance
end

-- ========================================
-- INITIALIZATION
-- ========================================

function NetworkManager:_Initialize()
	local networkFolder = CombatSystem:WaitForChild("Network")
	
	if self._isServer then
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
		
		-- Setup server listeners
		self:_SetupServerListeners()
		
		-- Setup player cleanup
		Players.PlayerRemoving:Connect(function(player)
			self:_CleanupPlayer(player)
		end)
		
	else
		-- Wait for RemoteEvent and RemoteFunction
		self._remoteEvent = networkFolder:WaitForChild("CombatRemoteEvent")
		self._remoteFunction = networkFolder:WaitForChild("CombatRemoteFunction")
		
		-- Setup client listeners
		self:_SetupClientListeners()
	end
	
	Logger:Debug("NetworkManager initialized")
end

-- ========================================
-- SERVER LISTENERS
-- ========================================

function NetworkManager:_SetupServerListeners()
	-- RemoteEvent listener (Client -> Server)
	self._remoteEvent.OnServerEvent:Connect(function(player, eventType, data)
		self:_HandleClientRequest(player, eventType, data)
	end)
	
	-- RemoteFunction listener (Client -> Server with response)
	self._remoteFunction.OnServerInvoke = function(player, eventType, data)
		return self:_HandleClientInvoke(player, eventType, data)
	end
	
	Logger:Debug("Server listeners setup")
end

function NetworkManager:_HandleClientRequest(player: Player, eventType: string, data: {[string]: any}?)
	-- Rate limiting
	if not self:_CheckRateLimit(player) then
		Logger:Warning("Rate limit exceeded", {player = player.Name, event = eventType})
		return
	end
	
	-- Validate event type
	if not Enums.IsValid(Enums.NetworkEvent, eventType) then
		Logger:Warning("Invalid event type from client", {player = player.Name, event = eventType})
		return
	end
	
	-- Call registered handler
	local handler = self._handlers[eventType]
	if handler then
		local success, result = pcall(function()
			return handler(player, data)
		end)
		
		if not success then
			Logger:Error("Handler error", {event = eventType, error = result})
		end
	else
		Logger:Debug("No handler registered", {event = eventType})
	end
end

function NetworkManager:_HandleClientInvoke(player: Player, eventType: string, data: {[string]: any}?): any
	-- Rate limiting
	if not self:_CheckRateLimit(player) then
		Logger:Warning("Rate limit exceeded on invoke", {player = player.Name, event = eventType})
		return {Success = false, ErrorCode = "RATE_LIMIT"}
	end
	
	-- Validate event type
	if not Enums.IsValid(Enums.NetworkEvent, eventType) then
		Logger:Warning("Invalid event type on invoke", {player = player.Name, event = eventType})
		return {Success = false, ErrorCode = "INVALID_EVENT"}
	end
	
	-- Call registered handler
	local handler = self._handlers[eventType]
	if handler then
		local success, result = pcall(function()
			return handler(player, data)
		end)
		
		if success then
			return result
		else
			Logger:Error("Handler error on invoke", {event = eventType, error = result})
			return {Success = false, ErrorCode = "HANDLER_ERROR"}
		end
	end
	
	return {Success = false, ErrorCode = "NO_HANDLER"}
end

-- ========================================
-- CLIENT LISTENERS
-- ========================================

function NetworkManager:_SetupClientListeners()
	-- RemoteEvent listener (Server -> Client)
	self._remoteEvent.OnClientEvent:Connect(function(eventType, data)
		self:_HandleServerEvent(eventType, data)
	end)
	
	Logger:Debug("Client listeners setup")
end

function NetworkManager:_HandleServerEvent(eventType: string, data: {[string]: any}?)
	-- Validate event type
	if not Enums.IsValid(Enums.NetworkEvent, eventType) then
		Logger:Warning("Invalid event type from server", {event = eventType})
		return
	end
	
	-- Call all registered callbacks
	local callbacks = self._callbacks[eventType]
	if callbacks then
		for _, callback in ipairs(callbacks) do
			task.spawn(function()
				local success, error = pcall(function()
					callback(data)
				end)
				
				if not success then
					Logger:Error("Callback error", {event = eventType, error = error})
				end
			end)
		end
	else
		Logger:Debug("No callbacks registered", {event = eventType})
	end
end

-- ========================================
-- RATE LIMITING (SERVER ONLY)
-- ========================================

function NetworkManager:_CheckRateLimit(player: Player): boolean
	if not self._isServer or not self._rateLimits then
		return true
	end
	
	local now = os.clock()
	local limitData = self._rateLimits[player]
	
	if not limitData then
		self._rateLimits[player] = {
			RequestCount = 1,
			WindowStart = now,
		}
		return true
	end
	
	-- Check if window expired
	if now - limitData.WindowStart >= RATE_LIMIT_WINDOW then
		limitData.RequestCount = 1
		limitData.WindowStart = now
		return true
	end
	
	-- Check if limit exceeded
	if limitData.RequestCount >= MAX_REQUESTS_PER_WINDOW then
		return false
	end
	
	-- Increment counter
	limitData.RequestCount += 1
	return true
end

function NetworkManager:_CleanupPlayer(player: Player)
	if self._rateLimits then
		self._rateLimits[player] = nil
	end
	
	Logger:Debug("Player network data cleaned", {player = player.Name})
end

-- ========================================
-- HANDLER REGISTRATION (SERVER)
-- ========================================

function NetworkManager:RegisterHandler(eventType: string, handler: (Player, {[string]: any}?) -> any)
	if not self._isServer then
		Logger:Warning("Handlers can only be registered on server")
		return
	end
	
	self._handlers[eventType] = handler
	
	Logger:Debug("Handler registered", {event = eventType})
end

-- ========================================
-- CALLBACK REGISTRATION (CLIENT)
-- ========================================

function NetworkManager:RegisterCallback(eventType: string, callback: ({[string]: any}?) -> ())
	if not self._isClient then
		Logger:Warning("Callbacks can only be registered on client")
		return
	end
	
	if not self._callbacks[eventType] then
		self._callbacks[eventType] = {}
	end
	
	table.insert(self._callbacks[eventType], callback)
	
	Logger:Debug("Callback registered", {event = eventType})
end

-- ========================================
-- SENDING (CLIENT -> SERVER)
-- ========================================

function NetworkManager:SendToServer(eventType: string, data: {[string]: any}?)
	if not self._isClient then
		Logger:Warning("SendToServer can only be called on client")
		return
	end
	
	if not self._remoteEvent then
		Logger:Error("RemoteEvent not initialized")
		return
	end
	
	self._remoteEvent:FireServer(eventType, data)
	
	Logger:Debug("Sent to server", {event = eventType})
end

-- ========================================
-- SENDING (SERVER -> CLIENT)
-- ========================================

function NetworkManager:SendToClient(player: Player, eventType: string, data: {[string]: any}?)
	if not self._isServer then
		Logger:Warning("SendToClient can only be called on server")
		return
	end
	
	if not self._remoteEvent then
		Logger:Error("RemoteEvent not initialized")
		return
	end
	
	self._remoteEvent:FireClient(player, eventType, data)
	
	Logger:Debug("Sent to client", {event = eventType, player = player.Name})
end

function NetworkManager:SendToAllClients(eventType: string, data: {[string]: any}?)
	if not self._isServer then
		Logger:Warning("SendToAllClients can only be called on server")
		return
	end
	
	if not self._remoteEvent then
		Logger:Error("RemoteEvent not initialized")
		return
	end
	
	self._remoteEvent:FireAllClients(eventType, data)
	
	Logger:Debug("Sent to all clients", {event = eventType})
end



return NetworkManager
