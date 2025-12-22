--[[
	Module: AnimationCache
	Type: Animation State Storage
	Location: ReplicatedStorage.CombatCore.Animations.AnimationCache
	Path: src/shared/CombatCore/Animations/AnimationCache.luau
	
	Description:
		Manages cached animation tracks and metadata.
		Provides efficient storage and retrieval of loaded animations.
		Handles cleanup and track lifecycle management.
		
		Separated from AnimationManager for single responsibility.
		Phase 2 Refactoring - Extracted from AnimationManager.
	
	Responsibilities:
		- Store loaded animation tracks with metadata
		- Track which animations are currently playing
		- Manage animation track connections
		- Provide efficient track lookup
	
	Dependencies:
		- ReplicatedStorage.CombatCore.Core.Logger
	
	Author: Professional Roblox Scripter
	Created: December 18, 2025 (Phase 2 - Task 1)
--]]

-- Module Imports
local Logger = require(script.Parent.Parent.Logging.Logger).GetInstance()

-- Animation Cache Module
local AnimationCache = {}
AnimationCache.__index = AnimationCache

-- ========================================
-- TYPES
-- ========================================

export type AnimationTrackInfo = {
	Track: AnimationTrack,
	AnimationId: string,
	Priority: Enum.AnimationPriority,
	IsPlaying: boolean,
	EndedConnection: RBXScriptConnection?,
}

type AnimationCache = {
	_cache: {[string]: AnimationTrackInfo},
	_currentTrack: AnimationTrack?,
}

-- ========================================
-- CONSTRUCTOR
-- ========================================

function AnimationCache.new(): AnimationCache
	local self = setmetatable({}, AnimationCache)
	
	self._cache = {}
	self._currentTrack = nil
	
	return self
end

-- ========================================
-- CACHE OPERATIONS
-- ========================================

-- Store animation track with metadata
function AnimationCache:Store(key: string, track: AnimationTrack, animationId: string, priority: Enum.AnimationPriority)
	if self._cache[key] then
		Logger:Warning("Overwriting existing cached animation", {key = key})
		self:Remove(key)
	end
	
	self._cache[key] = {
		Track = track,
		AnimationId = animationId,
		Priority = priority,
		IsPlaying = false,
		EndedConnection = nil,
	}
	
	Logger:Debug("Animation cached", {key = key, id = animationId})
end

-- Retrieve animation track info
function AnimationCache:Get(key: string): AnimationTrackInfo?
	return self._cache[key]
end

-- Get just the track (convenience)
function AnimationCache:GetTrack(key: string): AnimationTrack?
	local info = self._cache[key]
	return info and info.Track
end

-- Check if animation exists in cache
function AnimationCache:Has(key: string): boolean
	return self._cache[key] ~= nil
end

-- Mark animation as playing
function AnimationCache:SetPlaying(key: string, isPlaying: boolean)
	local info = self._cache[key]
	if info then
		info.IsPlaying = isPlaying
	end
end

-- Check if animation is currently playing
function AnimationCache:IsPlaying(key: string): boolean
	local info = self._cache[key]
	return info and info.IsPlaying or false
end

-- Set current active track
function AnimationCache:SetCurrentTrack(track: AnimationTrack?)
	self._currentTrack = track
end

-- Get current active track
function AnimationCache:GetCurrentTrack(): AnimationTrack?
	return self._currentTrack
end

-- Set Ended connection for cleanup
function AnimationCache:SetEndedConnection(key: string, connection: RBXScriptConnection?)
	local info = self._cache[key]
	if info then
		-- Disconnect previous connection if exists
		if info.EndedConnection then
			info.EndedConnection:Disconnect()
		end
		info.EndedConnection = connection
	end
end

-- Remove animation from cache
function AnimationCache:Remove(key: string)
	local info = self._cache[key]
	if not info then
		return
	end
	
	-- Disconnect connection
	if info.EndedConnection then
		info.EndedConnection:Disconnect()
	end
	
	-- Destroy track
	if info.Track then
		info.Track:Destroy()
	end
	
	-- Clear current track reference if it matches
	if self._currentTrack == info.Track then
		self._currentTrack = nil
	end
	
	self._cache[key] = nil
	
	Logger:Debug("Animation removed from cache", {key = key})
end

-- Get all cached animation keys
function AnimationCache:GetKeys(): {string}
	local keys = {}
	local index = 1
	for key in pairs(self._cache) do
		keys[index] = key
		index += 1
	end
	return keys
end

-- Get cache size
function AnimationCache:GetSize(): number
	local count = 0
	for _ in pairs(self._cache) do
		count += 1
	end
	return count
end

-- ========================================
-- CLEANUP
-- ========================================

function AnimationCache:Clear()
	-- Stop and destroy all tracks
	for key, info in pairs(self._cache) do
		if info.EndedConnection then
			info.EndedConnection:Disconnect()
		end
		if info.Track then
			info.Track:Destroy()
		end
	end
	
	table.clear(self._cache)
	self._currentTrack = nil
	
	Logger:Debug("Animation cache cleared")
end

function AnimationCache:Destroy()
	self:Clear()
	Logger:Info("AnimationCache destroyed")
end

return AnimationCache
