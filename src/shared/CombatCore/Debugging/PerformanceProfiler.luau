--[[
	Module: PerformanceProfiler
	Type: Profiling Utility Module
	Location: ReplicatedStorage.CombatCore.Debugging.PerformanceProfiler
	Path: src/shared/CombatCore/Debugging/PerformanceProfiler.luau
	
	Description:
		Performance profiling utility for the Combat System.
		Measures execution time of functions and identifies bottlenecks.
		Provides detailed performance reports with averages, min/max times.
		
		Use this during development to optimize critical paths.
		Can be disabled in production builds.
	
	Usage:
		local Profiler = require(CombatCore.Debugging.PerformanceProfiler)
		
		-- Start profiling a function
		Profiler:Start("LightAttack:Execute")
		-- ... function code ...
		Profiler:Stop("LightAttack:Execute")
		
		-- Get results
		local report = Profiler:GetReport()
		print(report)
	
	Author: Professional Roblox Scripter
	Created: December 20, 2025
--]]

local PerformanceProfiler = {}
PerformanceProfiler.__index = PerformanceProfiler

-- Singleton instance
local ProfilerInstance: PerformanceProfiler? = nil

-- ========================================
-- TYPES
-- ========================================

---@class ProfileData
---@field FunctionName string The name of the profiled function
---@field Calls number Number of times the function was called
---@field TotalTime number Total execution time in milliseconds
---@field MinTime number Minimum execution time in milliseconds
---@field MaxTime number Maximum execution time in milliseconds
---@field AverageTime number Average execution time in milliseconds
type ProfileData = {
	FunctionName: string,
	Calls: number,
	TotalTime: number,
	MinTime: number,
	MaxTime: number,
	AverageTime: number,
}

---@class ActiveProfile
---@field FunctionName string The name of the function being profiled
---@field StartTime number The start time (os.clock())
type ActiveProfile = {
	FunctionName: string,
	StartTime: number,
}

---@class PerformanceProfiler
---@field _profiles table<string, ProfileData> Profile data for each function
---@field _activeProfiles table<string, ActiveProfile> Currently active profiles
---@field _enabled boolean Whether profiling is enabled
type PerformanceProfiler = {
	_profiles: {[string]: ProfileData},
	_activeProfiles: {[string]: ActiveProfile},
	_enabled: boolean,
}

-- ========================================
-- CONSTRUCTOR
-- ========================================

---Creates a new PerformanceProfiler instance
---@return PerformanceProfiler PerformanceProfiler instance
function PerformanceProfiler.new(): PerformanceProfiler
	local self = setmetatable({}, PerformanceProfiler)
	
	self._profiles = {}
	self._activeProfiles = {}
	self._enabled = true
	
	return self
end

-- ========================================
-- SINGLETON
-- ========================================

---Gets or creates the singleton PerformanceProfiler instance
---@return PerformanceProfiler PerformanceProfiler instance
function PerformanceProfiler.GetInstance(): PerformanceProfiler
	if not ProfilerInstance then
		ProfilerInstance = PerformanceProfiler.new()
	end
	return ProfilerInstance
end

-- ========================================
-- PROFILING METHODS
-- ========================================

---Starts profiling a function
---@param functionName string Unique name for the function being profiled
function PerformanceProfiler:Start(functionName: string)
	if not self._enabled then
		return
	end
	
	self._activeProfiles[functionName] = {
		FunctionName = functionName,
		StartTime = os.clock(),
	}
end

---Stops profiling a function and records the result
---@param functionName string Name of the function to stop profiling
function PerformanceProfiler:Stop(functionName: string)
	if not self._enabled then
		return
	end
	
	local activeProfile = self._activeProfiles[functionName]
	if not activeProfile then
		warn("[PerformanceProfiler] No active profile found for:", functionName)
		return
	end
	
	local endTime = os.clock()
	local elapsedTime = endTime - activeProfile.StartTime
	
	-- Get or create profile data
	local profile = self._profiles[functionName]
	if not profile then
		profile = {
			FunctionName = functionName,
			Calls = 0,
			TotalTime = 0,
			MinTime = math.huge,
			MaxTime = 0,
			AverageTime = 0,
		}
		self._profiles[functionName] = profile
	end
	
	-- Update statistics
	profile.Calls += 1
	profile.TotalTime += elapsedTime
	profile.MinTime = math.min(profile.MinTime, elapsedTime)
	profile.MaxTime = math.max(profile.MaxTime, elapsedTime)
	profile.AverageTime = profile.TotalTime / profile.Calls
	
	-- Clear active profile
	self._activeProfiles[functionName] = nil
end

---Profiles a function call automatically
---@param functionName string Name for profiling
---@param func function Function to profile
---@return any ... Function return values
function PerformanceProfiler:Profile(functionName: string, func: (...any) -> ...any, ...: any): ...any
	self:Start(functionName)
	local results = {func(...)}
	self:Stop(functionName)
	return table.unpack(results)
end

-- ========================================
-- REPORTING
-- ========================================

---Gets performance data for a specific function
---@param functionName string Name of the function
---@return ProfileData? profile Profile data (nil if not found)
function PerformanceProfiler:GetProfile(functionName: string): ProfileData?
	return self._profiles[functionName]
end

---Gets all performance profiles
---@return table<string, ProfileData> profiles All profiles
function PerformanceProfiler:GetAllProfiles(): {[string]: ProfileData}
	return self._profiles
end

---Generates a formatted performance report
---@return string report Formatted report text
function PerformanceProfiler:GetReport(): string
	local lines = {
		"===========================================",
		"   PERFORMANCE PROFILING REPORT",
		"===========================================",
		"",
	}
	
	-- Sort profiles by total time (descending)
	local sortedProfiles = {}
	for _, profile in pairs(self._profiles) do
		table.insert(sortedProfiles, profile)
	end
	
	table.sort(sortedProfiles, function(a, b)
		return a.TotalTime > b.TotalTime
	end)
	
	-- Add profile data
	for i, profile in ipairs(sortedProfiles) do
		table.insert(lines, string.format(
			"%d. %s",
			i,
			profile.FunctionName
		))
		table.insert(lines, string.format(
			"   Calls:   %d",
			profile.Calls
		))
		table.insert(lines, string.format(
			"   Total:   %.4f ms (%.2f%%)",
			profile.TotalTime * 1000,
			self:_GetPercentage(profile.TotalTime)
		))
		table.insert(lines, string.format(
			"   Avg:     %.4f ms",
			profile.AverageTime * 1000
		))
		table.insert(lines, string.format(
			"   Min:     %.4f ms",
			profile.MinTime * 1000
		))
		table.insert(lines, string.format(
			"   Max:     %.4f ms",
			profile.MaxTime * 1000
		))
		table.insert(lines, "")
	end
	
	-- Summary
	local totalTime = self:_GetTotalTime()
	table.insert(lines, "===========================================")
	table.insert(lines, string.format("TOTAL TIME: %.4f ms", totalTime * 1000))
	table.insert(lines, string.format("TOTAL CALLS: %d", self:_GetTotalCalls()))
	table.insert(lines, "===========================================")
	
	return table.concat(lines, "\n")
end

---Gets performance report as structured data
---@return table report Structured report data
function PerformanceProfiler:GetReportData(): {
	profiles: {ProfileData},
	totalTime: number,
	totalCalls: number,
}
	local sortedProfiles = {}
	for _, profile in pairs(self._profiles) do
		table.insert(sortedProfiles, profile)
	end
	
	table.sort(sortedProfiles, function(a, b)
		return a.TotalTime > b.TotalTime
	end)
	
	return {
		profiles = sortedProfiles,
		totalTime = self:_GetTotalTime(),
		totalCalls = self:_GetTotalCalls(),
	}
end

-- ========================================
-- UTILITIES
-- ========================================

---Resets all profiling data
function PerformanceProfiler:Reset()
	self._profiles = {}
	self._activeProfiles = {}
end

---Enables or disables profiling
---@param enabled boolean Whether profiling is enabled
function PerformanceProfiler:SetEnabled(enabled: boolean)
	self._enabled = enabled
end

---Checks if profiling is enabled
---@return boolean enabled Whether profiling is enabled
function PerformanceProfiler:IsEnabled(): boolean
	return self._enabled
end

-- ========================================
-- PRIVATE METHODS
-- ========================================

function PerformanceProfiler:_GetTotalTime(): number
	local total = 0
	for _, profile in pairs(self._profiles) do
		total += profile.TotalTime
	end
	return total
end

function PerformanceProfiler:_GetTotalCalls(): number
	local total = 0
	for _, profile in pairs(self._profiles) do
		total += profile.Calls
	end
	return total
end

function PerformanceProfiler:_GetPercentage(time: number): number
	local total = self:_GetTotalTime()
	if total == 0 then
		return 0
	end
	return (time / total) * 100
end

-- ========================================
-- CONVENIENCE FUNCTIONS
-- ========================================

---Wraps a module with automatic profiling for all functions
---@param moduleName string Name of the module
---@param module table The module table
---@return table wrappedModule Module with profiled functions
function PerformanceProfiler:WrapModule(moduleName: string, module: {[string]: any}): {[string]: any}
	local wrapped = {}
	
	for key, value in pairs(module) do
		if type(value) == "function" then
			wrapped[key] = function(...)
				local functionName = string.format("%s:%s", moduleName, key)
				return self:Profile(functionName, value, ...)
			end
		else
			wrapped[key] = value
		end
	end
	
	return wrapped
end

return PerformanceProfiler
