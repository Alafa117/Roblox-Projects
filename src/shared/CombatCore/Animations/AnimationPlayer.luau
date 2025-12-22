--[[
	Module: AnimationPlayer
	Type: Animation Playback Controller
	Location: ReplicatedStorage.CombatCore.Animations.AnimationPlayer
	Path: src/shared/CombatCore/Animations/AnimationPlayer.luau
	
	Description:
		Controls animation playback with proper blending and transitions.
		Manages play/stop operations, looping, fade times, and state tracking.
		Handles animation priority and ensures smooth transitions between animations.
		
		Separated from AnimationManager for single responsibility.
		Phase 2 Refactoring - Extracted from AnimationManager.
	
	Responsibilities:
		- Play/stop animations with fade control
		- Manage current track state
		- Handle animation transitions
		- Connect to animation events (Ended)
		- Manage special sequences (block transitions)
	
	Dependencies:
		- ReplicatedStorage.CombatCore.Core (Enums, Logger)
		- ReplicatedStorage.CombatCore.Animations.AnimationCache
	
	Author: Professional Roblox Scripter
	Created: December 18, 2025 (Phase 2 - Task 1)
--]]

-- Module Imports
local Enums = require(script.Parent.Parent.Data.Enums)
local Logger = require(script.Parent.Parent.Logging.Logger).GetInstance()
local AnimationCache = require(script.Parent.AnimationCache)

-- Animation Player Module
local AnimationPlayer = {}
AnimationPlayer.__index = AnimationPlayer

-- ========================================
-- TYPES
-- ========================================

type AnimationPlayer = {
	_cache: typeof(AnimationCache.new()),
	_connections: {RBXScriptConnection},
	_activeThreads: {thread},
	_blockTransitionThread: thread?,
}

-- ========================================
-- CONSTRUCTOR
-- ========================================

function AnimationPlayer.new(cache: typeof(AnimationCache.new())): AnimationPlayer
	local self = setmetatable({}, AnimationPlayer)
	
	self._cache = cache
	self._connections = {}
	self._activeThreads = {}
	self._blockTransitionThread = nil
	
	return self
end

-- ========================================
-- HIGH-LEVEL PLAYBACK
-- ========================================

-- Play attack animation (Light or Strong)
function AnimationPlayer:PlayAttackAnimation(attackType: string, comboCount: number?)
	local key
	
	if attackType == Enums.AttackType.LightAttack then
		comboCount = comboCount or 1
		key = string.format("LightAttack_%d", comboCount)
	elseif attackType == Enums.AttackType.StrongAttack then
		key = "StrongAttack_Release"
	end
	
	if not key then
		Logger:Warning("Invalid attack type", {type = attackType})
		return
	end
	
	self:PlayAnimation(key)
end

-- Play block animation with state transitions
function AnimationPlayer:PlayBlockAnimation(isBlocking: boolean)
	-- Cancel any pending block transition
	if self._blockTransitionThread then
		task.cancel(self._blockTransitionThread)
		self._blockTransitionThread = nil
	end
	
	if isBlocking then
		self:PlayAnimation("Block_Start", false, 0.1)
		
		-- Transition to hold after start animation
		self._blockTransitionThread = task.delay(0.3, function()
			local startTrack = self._cache:GetTrack("Block_Start")
			if startTrack and startTrack.IsPlaying then
				self:PlayAnimation("Block_Hold", true, 0.2)
			end
			self._blockTransitionThread = nil
		end)
		table.insert(self._activeThreads, self._blockTransitionThread)
	else
		-- Stop hold and play end
		self:StopAnimation("Block_Hold")
		self:PlayAnimation("Block_End", false, 0.1)
	end
end

-- Play dash animation with direction
function AnimationPlayer:PlayDashAnimation(direction: string)
	local key = string.format("Dash_%s", direction)
	self:PlayAnimation(key)
end

-- Play slide animation
function AnimationPlayer:PlaySlideAnimation()
	self:PlayAnimation("Slide_Start")
end

-- Play hit reaction animation
function AnimationPlayer:PlayHitAnimation(isHeavy: boolean?, isBlocked: boolean?)
	local key
	
	if isBlocked then
		key = "Hit_Blocked"
	elseif isHeavy then
		key = "Hit_Heavy"
	else
		key = "Hit_Light"
	end
	
	self:PlayAnimation(key, false, 0.05)
end

-- ========================================
-- CORE PLAYBACK METHODS
-- ========================================

function AnimationPlayer:PlayAnimation(key: string, loop: boolean?, fadeTime: number?): AnimationTrack?
	local animInfo = self._cache:Get(key)
	
	if not animInfo then
		Logger:Debug("Animation not in cache", {key = key})
		return nil
	end
	
	local track = animInfo.Track
	
	-- Stop current track if different
	local currentTrack = self._cache:GetCurrentTrack()
	if currentTrack and currentTrack ~= track then
		currentTrack:Stop(fadeTime or 0.2)
	end
	
	-- Play animation
	track.Looped = loop or false
	track:Play(fadeTime or 0.1)
	
	self._cache:SetPlaying(key, true)
	self._cache:SetCurrentTrack(track)
	
	-- Handle animation ended (for non-looping)
	if not loop then
		local connection = track.Ended:Connect(function()
			self._cache:SetPlaying(key, false)
			if self._cache:GetCurrentTrack() == track then
				self._cache:SetCurrentTrack(nil)
			end
		end)
		
		self._cache:SetEndedConnection(key, connection)
		table.insert(self._connections, connection)
	end
	
	Logger:Debug("Animation playing", {key = key, loop = loop})
	
	return track
end

function AnimationPlayer:StopAnimation(key: string, fadeTime: number?)
	if not self._cache:IsPlaying(key) then
		return
	end
	
	local track = self._cache:GetTrack(key)
	if track then
		track:Stop(fadeTime or 0.2)
	end
	
	self._cache:SetPlaying(key, false)
	
	if self._cache:GetCurrentTrack() == track then
		self._cache:SetCurrentTrack(nil)
	end
	
	Logger:Debug("Animation stopped", {key = key})
end

function AnimationPlayer:StopAllAnimations(fadeTime: number?)
	for _, key in ipairs(self._cache:GetKeys()) do
		if self._cache:IsPlaying(key) then
			self:StopAnimation(key, fadeTime)
		end
	end
end

-- Get currently playing track
function AnimationPlayer:GetCurrentTrack(): AnimationTrack?
	return self._cache:GetCurrentTrack()
end

-- Check if specific animation is playing
function AnimationPlayer:IsPlaying(key: string): boolean
	return self._cache:IsPlaying(key)
end

-- ========================================
-- CLEANUP
-- ========================================

function AnimationPlayer:Cleanup()
	-- Cancel block transition thread
	if self._blockTransitionThread then
		task.cancel(self._blockTransitionThread)
		self._blockTransitionThread = nil
	end
	
	-- Disconnect all connections
	for _, connection in ipairs(self._connections) do
		if connection.Connected then
			connection:Disconnect()
		end
	end
	table.clear(self._connections)
	
	-- Cancel all active threads
	for _, thread in ipairs(self._activeThreads) do
		task.cancel(thread)
	end
	table.clear(self._activeThreads)
	
	Logger:Debug("AnimationPlayer cleanup complete")
end

function AnimationPlayer:Destroy()
	self:Cleanup()
	Logger:Info("AnimationPlayer destroyed")
end

return AnimationPlayer
