--[[
	Module: NetworkManager
	Type: Network Factory/Facade
	Location: ReplicatedStorage.CombatCore.Network.NetworkManager
	Path: src/shared/CombatCore/Network/NetworkManager.luau
	
	Description:
		Factory/Facade for network communication in the Combat System.
		Automatically returns the appropriate network instance based on context:
		- NetworkServer on server
		- NetworkClient on client
		
		This simplifies usage and maintains backward compatibility while
		improving architecture through separation of concerns.
	
	Phase 4 Refactoring:
		- Reduced from 405 lines to ~50 lines (-87%)
		- Delegates to NetworkServer.luau (server-side, ~200 lines)
		- Delegates to NetworkClient.luau (client-side, ~150 lines)
		- Maintains backward compatibility with existing code
		- Follows Factory pattern for automatic instance selection
	
	Dependencies:
		- ReplicatedStorage.CombatCore.Network.NetworkServer
		- ReplicatedStorage.CombatCore.Network.NetworkClient
	
	Author: Professional Roblox Scripter
	Created: December 11, 2025
	Refactored: December 19, 2025 (Phase 4 - Task 1)
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
