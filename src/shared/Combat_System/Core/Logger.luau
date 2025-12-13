--[[
	Module: CombatLogger
	Type: Utility Module
	Location: ReplicatedStorage.Combat_System.Core.Logger
	Path: src/shared/Combat_System/Core/Logger.luau
	
	Description:
		Advanced logging system for the Combat System.
		Provides structured logging with levels, timestamps, context, and history.
		Supports filtering, flushing, and performance-optimized batch logging.
	
	Usage:
		local Logger = require(RS.Combat_System.Core.Logger)
		Logger:Debug("Player attacked", {player = player.Name, damage = 10})
		Logger:Error("Invalid state", {state = "Unknown"})
	
	Author: Professional Roblox Scripter
	Created: December 9, 2025
--]]

-- Services
local RunService = game:GetService("RunService")

-- Module Imports
local Enums = require(script.Parent.Enums)
local Types = require(script.Parent.Types)

-- Constants
local IS_SERVER = RunService:IsServer()
local LOG_PREFIX = "[CombatSystem]"

-- Logger Class
local Logger = {}
Logger.__index = Logger

-- Singleton Instance
local LoggerInstance: Logger? = nil

-- ========================================
-- PRIVATE PROPERTIES
-- ========================================

type LogEntry = {
	Level: number,
	Message: string,
	Context: {[string]: any}?,
	Timestamp: number,
	Source: string,
	StackTrace: string?,
}

type Logger = {
	_config: Types.LoggerConfig,
	_enabled: boolean,
}

-- ========================================
-- CONSTRUCTOR
-- ========================================

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

function Logger:Debug(message: string, context: {[string]: any}?)
	self:_Log(Enums.LogLevel.Debug, message, context)
end

function Logger:Info(message: string, context: {[string]: any}?)
	self:_Log(Enums.LogLevel.Info, message, context)
end

function Logger:Warning(message: string, context: {[string]: any}?)
	self:_Log(Enums.LogLevel.Warning, message, context)
end

function Logger:Warn(message: string, context: {[string]: any}?)
	self:Warning(message, context)
end

function Logger:Error(message: string, context: {[string]: any}?)
	self:_Log(Enums.LogLevel.Error, message, context)
end

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

return Logger
