--[[
	Module: DebugLogger
	Type: Debug Utility Module
	Location: ReplicatedStorage.CombatCore.Core.DebugLogger
	Path: src/shared/CombatCore/Core/DebugLogger.luau
	
	Description:
		Centralized debug output manager to eliminate duplicate print statements.
		Provides consistent formatting and can be easily disabled for production.
		All debug prints go through this module for better control and filtering.
	
	Author: Professional Roblox Scripter
	Created: December 11, 2025
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Module Imports
local RS = ReplicatedStorage
local CombatSystem = RS:WaitForChild("CombatCore")
local Core = CombatSystem:WaitForChild("Core")
local Config = require(Core.Config)

-- DebugLogger Module
local DebugLogger = {}

-- Control flags
local ENABLE_DEBUG = Config.System.EnableDebugMode
local ENABLE_CLIENT_DEBUG = true
local ENABLE_SERVER_DEBUG = true
local ENABLE_MECHANIC_DEBUG = true
local ENABLE_VALIDATION_DEBUG = true

-- ========================================
-- INTERNAL HELPERS
-- ========================================

local function shouldPrint(category: string): boolean
	if not ENABLE_DEBUG then return false end
	
	if category == "CLIENT" and not ENABLE_CLIENT_DEBUG then return false end
	if category == "SERVER" and not ENABLE_SERVER_DEBUG then return false end
	if category == "MECHANIC" and not ENABLE_MECHANIC_DEBUG then return false end
	if category == "VALIDATION" and not ENABLE_VALIDATION_DEBUG then return false end
	
	return true
end

-- ========================================
-- CLIENT DEBUG OUTPUTS
-- ========================================

function DebugLogger.ClientAction(actionName: string, details: string?)
	if not shouldPrint("CLIENT") then return end
	if details then
		print(string.format("[CLIENT] %s - %s", actionName, details))
	else
		print(string.format("[CLIENT] %s", actionName))
	end
end

function DebugLogger.ClientValidationFailed(actionType: string, reason: string)
	if not shouldPrint("VALIDATION") then return end
	print(string.format("[CLIENT] Validation failed: %s - %s", actionType, reason))
end

-- ========================================
-- SERVER DEBUG OUTPUTS
-- ========================================

function DebugLogger.ServerRequest(playerName: string, eventType: string, actionType: string?)
	if not shouldPrint("SERVER") then return end
	if actionType then
		print(string.format("[SERVER] Request from %s: %s (Action: %s)", playerName, eventType, actionType))
	else
		print(string.format("[SERVER] Request from %s: %s", playerName, eventType))
	end
end

function DebugLogger.ServerValidationFailed(playerName: string, action: string, reason: string)
	if not shouldPrint("VALIDATION") then return end
	print(string.format("[SERVER] Validation failed: %s (%s) - %s", playerName, action, reason))
end

function DebugLogger.ServerMechanicExecution(mechanicName: string, playerName: string, status: string)
	if not shouldPrint("SERVER") then return end
	print(string.format("[SERVER] %s for %s: %s", mechanicName, playerName, status))
end

-- ========================================
-- MECHANIC DEBUG OUTPUTS
-- ========================================

function DebugLogger.MechanicExecute(mechanicName: string, playerName: string, extraData: string?)
	if not shouldPrint("MECHANIC") then return end
	if extraData then
		print(string.format("[%s] Execute: %s (%s)", mechanicName, playerName, extraData))
	else
		print(string.format("[%s] Execute: %s", mechanicName, playerName))
	end
end

function DebugLogger.MechanicInvalidCharacter(mechanicName: string, playerName: string)
	if not shouldPrint("MECHANIC") then return end
	print(string.format("[%s] ERROR: Invalid character for %s", mechanicName, playerName))
end

function DebugLogger.MechanicHitDetection(mechanicName: string, hitCount: number)
	if not shouldPrint("MECHANIC") then return end
	print(string.format("[%s] Hit detection: %d targets found", mechanicName, hitCount))
end

function DebugLogger.MechanicDamageApplied(mechanicName: string, victimName: string, damage: number?)
	if not shouldPrint("MECHANIC") then return end
	if damage then
		print(string.format("[%s] Damage applied: %s (%.1f dmg)", mechanicName, victimName, damage))
	else
		print(string.format("[%s] Damage applied: %s", mechanicName, victimName))
	end
end

function DebugLogger.MechanicVFXBroadcast(mechanicName: string)
	if not shouldPrint("MECHANIC") then return end
	print(string.format("[%s] Broadcasting VFX", mechanicName))
end

return DebugLogger
