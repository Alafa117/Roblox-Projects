--[[
	Module: CombatLogger
	Type: Unified Logging System
	Location: ReplicatedStorage.CombatCore.Logging.Logger
	Path: src/shared/CombatCore/Logging/Logger.luau
	
	Description:
		Unified logging system for the Combat System.
		Provides structured logging with levels, timestamps, context, and categorized debug.
		Consolidates functionality from Logger and DebugLogger into one cohesive system.
		
		Phase 2 Refactoring:
		Integrated DebugLogger functionality for single logging system.
		Supports both structured logging (Info/Warn/Error) and categorized debug logs.
	
	Features:
		- Structured logging with levels (Debug/Info/Warning/Error/Critical)
		- Categorized debug logging (Client/Server/Mechanic/Validation)
		- Configurable filters and toggles
		- Timestamps and stack traces
		- Context data support
	
	Usage:
		-- Structured logging
		Logger:Debug("Player attacked", {player = player.Name, damage = 10})
		Logger:Error("Invalid state", {state = "Unknown"})
		
		-- Categorized debug (from DebugLogger)
		Logger:ClientAction("Attack", "LightAttack executed")
		Logger:ServerRequest(player.Name, "PerformAction", "Dash")
	
	Author: Professional Roblox Scripter
	Created: December 9, 2025
	Refactored: December 18, 2025 (Phase 2 - Task 3)
--]]

-- Services
local RunService = game:GetService("RunService")

-- Module Imports
local Enums = require(script.Parent.Parent.Data.Enums)
local Types = require(script.Parent.Parent.Data.Types)
local Config = require(script.Parent.Parent.Config.Config)

-- Constants
local IS_SERVER = RunService:IsServer()
local LOG_PREFIX = "[CombatSystem]"

-- Debug flags (from DebugConfig for centralization)
local ENABLE_DEBUG = Config.System.EnableDebugMode
local ENABLE_CLIENT_DEBUG = Config.Debug.EnableClientDebug
local ENABLE_SERVER_DEBUG = Config.Debug.EnableServerDebug
local ENABLE_MECHANIC_DEBUG = Config.Debug.EnableMechanicDebug
local ENABLE_VALIDATION_DEBUG = Config.Debug.EnableValidationDebug

-- Logger Class
local Logger = {}
Logger.__index = Logger

-- Singleton Instance
local LoggerInstance: Logger? = nil

-- ========================================
-- PRIVATE PROPERTIES
-- ========================================

---@class LogEntry
---@field Level number Log level (Debug/Info/Warning/Error/Critical)
---@field Message string Log message
---@field Context table<string, any>? Optional context data
---@field Timestamp number Time of log (os.clock)
---@field Source string "Server" or "Client"
---@field StackTrace string? Stack trace for errors
type LogEntry = {
	Level: number,
	Message: string,
	Context: {[string]: any}?,
	Timestamp: number,
	Source: string,
	StackTrace: string?,
}

---@class Logger
---@field _config LoggerConfig Logger configuration
---@field _enabled boolean Whether logging is enabled
type Logger = {
	_config: Types.LoggerConfig,
	_enabled: boolean,
}

-- ========================================
-- CONSTRUCTOR
-- ========================================

---Creates a new Logger instance
---@param config LoggerConfig? Optional configuration (uses defaults if nil)
---@return Logger Logger instance
function Logger.new(config: Types.LoggerConfig?): Logger
	local self = setmetatable({}, Logger)
	
	self._config = config or {
		MinLevel = Enums.LogLevel.Debug,
		EnableTimestamp = true,
		EnableStackTrace = false,
		OutputToConsole = true,
	}
	
	self._enabled = true
	
	return self
end

-- ========================================
---Gets or creates the singleton Logger instance
---@return Logger Logger instance
-- SINGLETON GETTER
-- ========================================

function Logger.GetInstance(): Logger
	if not LoggerInstance then
		LoggerInstance = Logger.new()
	end
	return LoggerInstance
end

-- ========================================
-- LOGGING METHODS
-- ========================================

---Logs a debug message (lowest priority)
---@param message string The message to log
---@param context table<string, any>? Optional context data
function Logger:Debug(message: string, context: {[string]: any}?)
	self:_Log(Enums.LogLevel.Debug, message, context)
end

---Logs an informational message
---@param message string The message to log
---@param context table<string, any>? Optional context data
function Logger:Info(message: string, context: {[string]: any}?)
	self:_Log(Enums.LogLevel.Info, message, context)
end

---Logs a warning message
---@param message string The message to log
---@param context table<string, any>? Optional context data
function Logger:Warning(message: string, context: {[string]: any}?)
	self:_Log(Enums.LogLevel.Warning, message, context)
end

---Logs a success message (same level as Info but with success formatting)
---@param message string The message to log
---@param context table<string, any>? Optional context data
function Logger:Success(message: string, context: {[string]: any}?)
	self:_Log(Enums.LogLevel.Info, message, context)
end

---Logs an error message
---@param message string The message to log
---@param context table<string, any>? Optional context data
function Logger:Error(message: string, context: {[string]: any}?)
	self:_Log(Enums.LogLevel.Error, message, context)
end

---Logs a critical error message (highest priority)
---@param message string The message to log
---@param context table<string, any>? Optional context data
function Logger:Critical(message: string, context: {[string]: any}?)
	self:_Log(Enums.LogLevel.Critical, message, context)
end

-- ========================================
-- CORE LOGGING LOGIC
-- ========================================

function Logger:_Log(level: number, message: string, context: {[string]: any}?)
	if not self._enabled then
		return
	end
	
	if level < self._config.MinLevel then
		return
	end
	
	local entry: LogEntry = {
		Level = level,
		Message = message,
		Context = context,
		Timestamp = os.clock(),
		Source = IS_SERVER and "Server" or "Client",
		StackTrace = self._config.EnableStackTrace and debug.traceback() or nil,
	}
	
	-- Output to console
	if self._config.OutputToConsole then
		self:_OutputToConsole(entry)
	end
end

-- ========================================
-- OUTPUT FORMATTING
-- ========================================

function Logger:_OutputToConsole(entry: LogEntry)
	local levelStr = self:_GetLevelString(entry.Level)
	local timestamp = self._config.EnableTimestamp and string.format("[%.3f]", entry.Timestamp) or ""
	local contextStr = entry.Context and self:_FormatContext(entry.Context) or ""
	
	local fullMessage = string.format(
		"%s %s [%s] %s: %s%s",
		LOG_PREFIX,
		timestamp,
		entry.Source,
		levelStr,
		entry.Message,
		contextStr
	)
	
	-- Use appropriate output method based on level
	if entry.Level >= Enums.LogLevel.Error then
		warn(fullMessage)
	else
		print(fullMessage)
	end
	
	-- Print stack trace if enabled
	if entry.StackTrace and entry.Level >= Enums.LogLevel.Error then
		print(entry.StackTrace)
	end
end

function Logger:_GetLevelString(level: number): string
	if level == Enums.LogLevel.Debug then
		return "DEBUG"
	elseif level == Enums.LogLevel.Info then
		return "INFO"
	elseif level == Enums.LogLevel.Warning then
		return "WARN"
	elseif level == Enums.LogLevel.Error then
		return "ERROR"
	elseif level == Enums.LogLevel.Critical then
		return "CRITICAL"
	end
	return "UNKNOWN"
end

function Logger:_FormatContext(context: {[string]: any}): string
	local parts = {}
	for key, value in pairs(context) do
		table.insert(parts, string.format("%s=%s", tostring(key), tostring(value)))
	end
	return #parts > 0 and " | " .. table.concat(parts, ", ") or ""
end

-- ========================================
-- CATEGORIZED DEBUG LOGGING (from DebugLogger)
-- ========================================

function Logger:_ShouldPrintDebug(category: string): boolean
	if not ENABLE_DEBUG then return false end
	
	if category == "CLIENT" and not ENABLE_CLIENT_DEBUG then return false end
	if category == "SERVER" and not ENABLE_SERVER_DEBUG then return false end
	if category == "MECHANIC" and not ENABLE_MECHANIC_DEBUG then return false end
	if category == "VALIDATION" and not ENABLE_VALIDATION_DEBUG then return false end
	
	return true
end

-- Client debug methods
function Logger:ClientAction(actionName: string, details: string?)
	if not self:_ShouldPrintDebug("CLIENT") then return end
	if details then
		print(string.format("[CLIENT] %s - %s", actionName, details))
	else
		print(string.format("[CLIENT] %s", actionName))
	end
end

function Logger:ClientValidationFailed(actionType: string, reason: string)
	if not self:_ShouldPrintDebug("VALIDATION") then return end
	print(string.format("[CLIENT] Validation failed: %s - %s", actionType, reason))
end

-- Server debug methods
function Logger:ServerRequest(playerName: string, eventType: string, actionType: string?)
	if not self:_ShouldPrintDebug("SERVER") then return end
	if actionType then
		print(string.format("[SERVER] Request from %s: %s (Action: %s)", playerName, eventType, actionType))
	else
		print(string.format("[SERVER] Request from %s: %s", playerName, eventType))
	end
end

function Logger:ServerValidationFailed(playerName: string, action: string, reason: string)
	if not self:_ShouldPrintDebug("VALIDATION") then return end
	print(string.format("[SERVER] Validation failed: %s (%s) - %s", playerName, action, reason))
end

function Logger:ServerMechanicExecution(mechanicName: string, playerName: string, status: string)
	if not self:_ShouldPrintDebug("SERVER") then return end
	print(string.format("[SERVER] %s for %s: %s", mechanicName, playerName, status))
end

-- Mechanic debug methods
function Logger:MechanicExecute(mechanicName: string, playerName: string, extraData: string?)
	if not self:_ShouldPrintDebug("MECHANIC") then return end
	if extraData then
		print(string.format("[%s] Execute: %s (%s)", mechanicName, playerName, extraData))
	else
		print(string.format("[%s] Execute: %s", mechanicName, playerName))
	end
end

function Logger:MechanicInvalidCharacter(mechanicName: string, playerName: string)
	if not self:_ShouldPrintDebug("MECHANIC") then return end
	print(string.format("[%s] ERROR: Invalid character for %s", mechanicName, playerName))
end

function Logger:MechanicHitDetection(mechanicName: string, hitCount: number)
	if not self:_ShouldPrintDebug("MECHANIC") then return end
	print(string.format("[%s] Hit detection: %d targets found", mechanicName, hitCount))
end

function Logger:MechanicDamageApplied(mechanicName: string, victimName: string, damage: number?)
	if not self:_ShouldPrintDebug("MECHANIC") then return end
	if damage then
		print(string.format("[%s] Damage applied: %s (%.1f dmg)", mechanicName, victimName, damage))
	else
		print(string.format("[%s] Damage applied: %s", mechanicName, victimName))
	end
end

function Logger:MechanicVFXBroadcast(mechanicName: string)
	if not self:_ShouldPrintDebug("MECHANIC") then return end
	print(string.format("[%s] Broadcasting VFX", mechanicName))
end

return Logger
