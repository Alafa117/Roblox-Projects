--[[
	Module: NetworkManager
	Type: Network Factory/Facade (Context-Aware)
	Location: ReplicatedStorage.CombatCore.Network.NetworkManager
	Path: src/shared/CombatCore/Network/NetworkManager.luau
	
	Description:
		Smart factory/facade for network communication in the Combat System.
		Automatically returns the appropriate network instance based on execution context:
		- NetworkServer.GetInstance() on server (handles requests, broadcasts, rate limiting)
		- NetworkClient.GetInstance() on client (sends requests, receives broadcasts)
		
	Features:
		- Automatic context detection (server vs client)
		- Singleton pattern for global access
		- Maintains backward compatibility with legacy code
		- Simplifies network usage across codebase
		- Delegates to specialized NetworkServer/NetworkClient modules
		
	Phase 4 Refactoring:
		- Reduced from 405 lines to ~70 lines (-83% code reduction)
		- Delegates to NetworkServer.luau (server-side, ~726 lines with advanced features)
		- Delegates to NetworkClient.luau (client-side, ~210 lines with prediction)
		- Maintains backward compatibility with existing code
		- Follows Factory pattern for automatic instance selection
	
	Dependencies:
		- ReplicatedStorage.CombatCore.Network.NetworkServer (server-only)
		- ReplicatedStorage.CombatCore.Network.NetworkClient (client-only)
	
	Usage:
		local NetworkManager = require(CombatCore.Network.NetworkManager)
		local network = NetworkManager.GetInstance() -- Auto-detects server/client
		
		-- Server
		network:RegisterHandler(eventType, handler)
		network:SendToClient(player, eventType, data)
		network:BroadcastToAllClients(eventType, data)
		
		-- Client
		network:SendToServer(eventType, data)
		network:RegisterCallback(eventType, callback)
		
	Author: Professional Roblox Scripter
	Created: December 11, 2025
	Refactored: December 19, 2025 (Phase 4 - Task 1)
	Updated: December 23, 2025 - Enhanced documentation with usage examples
--]]

-- Services
local RunService = game:GetService("RunService")

-- Module Imports (using relative paths - no yields)
local NetworkServer = require(script.Parent.NetworkServer)
local NetworkClient = require(script.Parent.NetworkClient)

-- Constants
local IS_SERVER = RunService:IsServer()
local IS_CLIENT = RunService:IsClient()

-- ========================================
-- FACTORY/FACADE
-- ========================================

local NetworkManager = {}

-- Get the appropriate network instance based on context
function NetworkManager.GetServerInstance()
	return NetworkServer.GetInstance()
end

function NetworkManager.GetClientInstance()
	return NetworkClient.GetInstance()
end

-- Auto-detect and return appropriate instance (convenience method)
function NetworkManager.GetInstance()
	if IS_SERVER then
		return NetworkServer.GetInstance()
	elseif IS_CLIENT then
		return NetworkClient.GetInstance()
	else
		error("NetworkManager: Cannot determine context (not server or client)")
	end
end

return NetworkManager
