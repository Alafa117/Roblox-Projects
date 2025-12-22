--[[
	Module: NetworkClient
	Type: Client Network Module
	Location: ReplicatedStorage.CombatCore.Network.NetworkClient
	Path: src/shared/CombatCore/Network/NetworkClient.luau
	
	Description:
		Client-side network communication manager for the Combat System.
		Handles client-to-server communication and server event callbacks.
		Separated from NetworkManager for better Single Responsibility Principle.
	
	Phase 4 Refactoring:
		- Extracted from NetworkManager.luau (405 lines)
		- Focuses exclusively on client-side network operations
		- Implements callback registration and server communication
		- ~150 lines, -62% complexity
	
	Dependencies:
		- ReplicatedStorage.CombatCore.Data (Enums)
		- ReplicatedStorage.CombatCore.Logging (Logger)
	
	Author: Professional Roblox Scripter
	Created: December 19, 2025
--]]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Module Imports (using relative paths - no yields)
local Enums = require(script.Parent.Parent.Data.Enums)
local Logger = require(script.Parent.Parent.Logging.Logger).GetInstance()

-- Constants
local IS_CLIENT = RunService:IsClient()

-- Network Client Class
local NetworkClient = {}
NetworkClient.__index = NetworkClient

-- Singleton Instance
local ClientInstance: NetworkClient? = nil

-- ========================================
-- TYPES
-- ========================================

type NetworkClient = {
	_remoteEvent: RemoteEvent?,
	_remoteFunction: RemoteFunction?,
	_unreliableRemoteEvent: UnreliableRemoteEvent?,
	_callbacks: {[string]: {(...any) -> ()}},
	_connections: {RBXScriptConnection},
}

-- ========================================
-- CONSTRUCTOR
-- ========================================

function NetworkClient.new(): NetworkClient
	if not IS_CLIENT then
		Logger:Error("NetworkClient can only be created on client")
		return nil
	end
	
	local self = setmetatable({}, NetworkClient)
	
	self._remoteEvent = nil
	self._remoteFunction = nil
	self._unreliableRemoteEvent = nil
	self._callbacks = {}
	self._connections = {}
	
	self:_Initialize()
	
	Logger:Info("NetworkClient created")
	
	return self
end

-- ========================================
-- SINGLETON GETTER
-- ========================================

function NetworkClient.GetInstance(): NetworkClient
	if not IS_CLIENT then
		Logger:Error("NetworkClient can only be accessed on client")
		return nil
	end
	
	if not ClientInstance then
		ClientInstance = NetworkClient.new()
	end
	return ClientInstance
end

-- ========================================
-- INITIALIZATION
-- ========================================

function NetworkClient:_Initialize()
	-- Get Network folder using relative path (no yields)
	local networkFolder = script.Parent
	
	-- Get RemoteEvent and RemoteFunction (no yields)
	self._remoteEvent = networkFolder:FindFirstChild("CombatRemoteEvent")
	self._remoteFunction = networkFolder:FindFirstChild("CombatRemoteFunction")
	self._unreliableRemoteEvent = networkFolder:FindFirstChild("CombatUnreliableRemoteEvent")
	
	-- Validate existence
	if not self._remoteEvent or not self._remoteFunction then
		Logger:Error("Remote instances not found in Network folder")
		return
	end
	
	-- Setup client listeners
	self:_SetupClientListeners()
end

-- ========================================
-- CLIENT LISTENERS
-- ========================================

function NetworkClient:_SetupClientListeners()
	-- RemoteEvent listener (Server -> Client)
	table.insert(self._connections, self._remoteEvent.OnClientEvent:Connect(function(eventType, data)
		self:_HandleServerEvent(eventType, data)
	end))
	
	-- UnreliableRemoteEvent listener (Server -> Client, for VFX)
	if self._unreliableRemoteEvent then
		table.insert(self._connections, self._unreliableRemoteEvent.OnClientEvent:Connect(function(eventType, data)
			self:_HandleServerEvent(eventType, data)
		end))
	end
end

function NetworkClient:_HandleServerEvent(eventType: string, data: {[string]: any}?)
	-- Validate event type
	if not Enums.IsValid(Enums.NetworkEvent, eventType) then
		Logger:Warning("Invalid event type from server", {event = eventType})
		return
	end
	
	-- Call all registered callbacks
	local callbacks = self._callbacks[eventType]
	if callbacks then
		for _, callback in ipairs(callbacks) do
			-- Use task.defer() for non-urgent callbacks (better performance)
			-- Distributes callback execution across frames to prevent lag spikes
			task.defer(function()
				local success, error = pcall(function()
					callback(data)
				end)
				
				if not success then
					Logger:Error("Callback error", {event = eventType, error = error})
				end
			end)
		end
	end
end

-- ========================================
-- CALLBACK REGISTRATION
-- ========================================

function NetworkClient:RegisterCallback(eventType: string, callback: ({[string]: any}?) -> ())
	if not self._callbacks[eventType] then
		self._callbacks[eventType] = {}
	end
	
	table.insert(self._callbacks[eventType], callback)
	Logger:Debug("Callback registered", {event = eventType})
end

-- ========================================
-- SENDING (CLIENT -> SERVER)
-- ========================================

function NetworkClient:SendToServer(eventType: string, data: {[string]: any}?)
	if not self._remoteEvent then
		Logger:Error("RemoteEvent not initialized")
		return
	end
	
	self._remoteEvent:FireServer(eventType, data)
end

function NetworkClient:InvokeServer(eventType: string, data: {[string]: any}?): any
	if not self._remoteFunction then
		Logger:Error("RemoteFunction not initialized")
		return {Success = false, ErrorCode = "NO_REMOTE"}
	end
	
	local success, result = pcall(function()
		return self._remoteFunction:InvokeServer(eventType, data)
	end)
	
	if success then
		return result
	else
		Logger:Error("InvokeServer failed", {event = eventType, error = result})
		return {Success = false, ErrorCode = "INVOKE_ERROR"}
	end
end

-- ========================================
-- CLEANUP
-- ========================================

function NetworkClient:Destroy()
	-- Disconnect all connections
	for _, connection in ipairs(self._connections) do
		if connection.Connected then
			connection:Disconnect()
		end
	end
	table.clear(self._connections)
	
	-- Clear callbacks
	table.clear(self._callbacks)
	
	-- Clear singleton reference
	ClientInstance = nil
	
	Logger:Info("NetworkClient destroyed")
end

return NetworkClient
