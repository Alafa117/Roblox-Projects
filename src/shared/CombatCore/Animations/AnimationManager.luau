--[[
	Module: AnimationManager
	Type: Shared Animation Manager
	Location: ReplicatedStorage.CombatCore.Animations.AnimationManager
	Path: src/shared/CombatCore/Animations/AnimationManager.luau
	
	Description:
		Manages all combat animations for characters.
		Loads, caches, and plays animations with proper priority and blending.
		Supports combo animations, directional animations, and state-based transitions.
		Optimized for R6 avatars with track management and cleanup.
	
	Dependencies:
		- ReplicatedStorage.CombatCore.Core (Config, Enums, Logger)
	
	Author: Professional Roblox Scripter
	Created: December 11, 2025
--]]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Module Imports
local RS = ReplicatedStorage
local CombatSystem = RS:WaitForChild("CombatCore")
local Core = CombatSystem:WaitForChild("Core")

local Config = require(Core.Config)
local Enums = require(Core.Enums)
local Logger = require(Core.Logger).GetInstance()

-- Animation Manager Class
local AnimationManager = {}
AnimationManager.__index = AnimationManager

-- ========================================
-- TYPES
-- ========================================

type AnimationTrackInfo = {
	Track: AnimationTrack,
	AnimationId: string,
	Priority: Enum.AnimationPriority,
	IsPlaying: boolean,
	EndedConnection: RBXScriptConnection?,
}

type AnimationManager = {
	Character: Model,
	Humanoid: Humanoid?,
	Animator: Animator?,
	
	_loadedAnimations: {[string]: AnimationTrackInfo},
	_currentTrack: AnimationTrack?,
	_isInitialized: boolean,
	_connections: {RBXScriptConnection},
	_activeThreads: {thread},
	_blockTransitionThread: thread?,
}

-- ========================================
-- CONSTRUCTOR
-- ========================================

function AnimationManager.new(character: Model?): AnimationManager
	local self = setmetatable({}, AnimationManager)
	
	self.Character = character
	self.Humanoid = nil
	self.Animator = nil
	
	self._loadedAnimations = {}
	self._currentTrack = nil
	self._isInitialized = false
	self._connections = {}
	self._activeThreads = {}
	self._blockTransitionThread = nil
	
	if character then
		self:LoadAnimations(character)
	end
	
	Logger:Debug("AnimationManager created")
	
	return self
end

-- ========================================
-- INITIALIZATION
-- ========================================

function AnimationManager:LoadAnimations(character: Model)
	self.Character = character
	self.Humanoid = character:FindFirstChildOfClass("Humanoid")
	
	if not self.Humanoid then
		Logger:Error("No Humanoid found in character")
		return
	end
	
	-- Get or create Animator
	self.Animator = self.Humanoid:FindFirstChildOfClass("Animator")
	if not self.Animator then
		self.Animator = Instance.new("Animator")
		self.Animator.Parent = self.Humanoid
	end
	
	-- Pre-load all combat animations
	self:_LoadLightAttackAnimations()
	self:_LoadStrongAttackAnimations()
	self:_LoadBlockAnimations()
	self:_LoadDashAnimations()
	self:_LoadSlideAnimations()
	self:_LoadHitAnimations()
	
	self._isInitialized = true
	
	Logger:Info("Animations loaded", {character = character.Name})
end

-- ========================================
-- ANIMATION LOADING
-- ========================================

function AnimationManager:_LoadLightAttackAnimations()
	for comboIndex, animationId in pairs(Config.Animations.LightAttack) do
		local key = string.format("LightAttack_%d", comboIndex)
		self:_LoadAnimation(key, animationId, Enums.AnimationPriority.Action)
	end
end

function AnimationManager:_LoadStrongAttackAnimations()
	-- StrongAttack is instant (no charge animation needed)
	self:_LoadAnimation("StrongAttack_Release", Config.Animations.StrongAttack.Release, Enums.AnimationPriority.Action2)
end

function AnimationManager:_LoadBlockAnimations()
	self:_LoadAnimation("Block_Start", Config.Animations.Block.Start, Enums.AnimationPriority.Action)
	self:_LoadAnimation("Block_Hold", Config.Animations.Block.Hold, Enums.AnimationPriority.Action)
	self:_LoadAnimation("Block_End", Config.Animations.Block.End, Enums.AnimationPriority.Action)
	self:_LoadAnimation("Block_Break", Config.Animations.Block.Break, Enums.AnimationPriority.Action)
end

function AnimationManager:_LoadDashAnimations()
	for direction, animationId in pairs(Config.Animations.Dash) do
		local key = string.format("Dash_%s", direction)
		self:_LoadAnimation(key, animationId, Enums.AnimationPriority.Action3)
	end
end

function AnimationManager:_LoadSlideAnimations()
	self:_LoadAnimation("Slide_Start", Config.Animations.Slide.Start, Enums.AnimationPriority.Action3)
end

function AnimationManager:_LoadHitAnimations()
	self:_LoadAnimation("Hit_Light", Config.Animations.Hit.Light, Enums.AnimationPriority.Action)
	self:_LoadAnimation("Hit_Heavy", Config.Animations.Hit.Heavy, Enums.AnimationPriority.Action)
	self:_LoadAnimation("Hit_Blocked", Config.Animations.Hit.Blocked, Enums.AnimationPriority.Action)
end

-- ========================================
-- CORE ANIMATION LOADING
-- ========================================

function AnimationManager:_LoadAnimation(key: string, animationId: string, priority: Enum.AnimationPriority): AnimationTrack?
	if not self.Animator then
		Logger:Warning("No Animator available")
		return nil
	end
	
	-- Skip if animation ID is invalid (placeholder)
	if animationId == "rbxassetid://0" or animationId == "" then
		Logger:Debug("Skipping placeholder animation", {key = key})
		return nil
	end
	
	-- Check if already loaded
	if self._loadedAnimations[key] then
		Logger:Debug("Animation already loaded", {key = key})
		return self._loadedAnimations[key].Track
	end
	
	-- Create animation instance
	local animation = Instance.new("Animation")
	animation.AnimationId = animationId
	
	-- Load animation track
	local success, result = pcall(function()
		return self.Animator:LoadAnimation(animation)
	end)
	
	if not success then
		Logger:Error("Failed to load animation", {key = key, error = result})
		return nil
	end
	
	local track: AnimationTrack = result
	track.Priority = priority
	
	-- Store track info
	self._loadedAnimations[key] = {
		Track = track,
		AnimationId = animationId,
		Priority = priority,
		IsPlaying = false,
		EndedConnection = nil,
	}
	
	Logger:Debug("Animation loaded", {key = key, id = animationId})
	
	return track
end

-- ========================================
-- ANIMATION PLAYBACK
-- ========================================

function AnimationManager:PlayAttackAnimation(attackType: string, comboCount: number?)
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
	
	self:_PlayAnimation(key)
end

function AnimationManager:PlayBlockAnimation(isBlocking: boolean)
	-- Cancel any pending block transition
	if self._blockTransitionThread then
		task.cancel(self._blockTransitionThread)
		self._blockTransitionThread = nil
	end
	
	if isBlocking then
		self:_PlayAnimation("Block_Start", false, 0.1)
		
		-- Transition to hold after start animation
		self._blockTransitionThread = task.delay(0.3, function()
			local startTrack = self:_GetAnimationTrack("Block_Start")
			if startTrack and startTrack.IsPlaying then
				self:_PlayAnimation("Block_Hold", true, 0.2)
			end
			self._blockTransitionThread = nil
		end)
		table.insert(self._activeThreads, self._blockTransitionThread)
	else
		-- Stop hold and play end
		self:_StopAnimation("Block_Hold")
		self:_PlayAnimation("Block_End", false, 0.1)
	end
end

function AnimationManager:PlayDashAnimation(direction: string)
	local key = string.format("Dash_%s", direction)
	self:_PlayAnimation(key)
end

function AnimationManager:PlaySlideAnimation()
	self:_PlayAnimation("Slide_Start")
end

function AnimationManager:PlayHitAnimation(isHeavy: boolean?, isBlocked: boolean?)
	local key
	
	if isBlocked then
		key = "Hit_Blocked"
	elseif isHeavy then
		key = "Hit_Heavy"
	else
		key = "Hit_Light"
	end
	
	self:_PlayAnimation(key, false, 0.05)
end

-- ========================================
-- CORE PLAYBACK METHODS
-- ========================================

function AnimationManager:_PlayAnimation(key: string, loop: boolean?, fadeTime: number?): AnimationTrack?
	local animInfo = self._loadedAnimations[key]
	
	if not animInfo then
		Logger:Debug("Animation not loaded", {key = key})
		return nil
	end
	
	local track = animInfo.Track
	
	-- Stop current track if different
	if self._currentTrack and self._currentTrack ~= track then
		self._currentTrack:Stop(fadeTime or 0.2)
	end
	
	-- Play animation
	track.Looped = loop or false
	track:Play(fadeTime or 0.1)
	
	animInfo.IsPlaying = true
	self._currentTrack = track
	
	-- Handle animation ended
	if not loop then
		-- Disconnect previous connection if exists
		if animInfo.EndedConnection then
			animInfo.EndedConnection:Disconnect()
		end
		
		-- Create new connection
		animInfo.EndedConnection = track.Ended:Connect(function()
			animInfo.IsPlaying = false
			if self._currentTrack == track then
				self._currentTrack = nil
			end
		end)
		table.insert(self._connections, animInfo.EndedConnection)
	end
	
	Logger:Debug("Animation playing", {key = key, loop = loop})
	
	return track
end

function AnimationManager:_StopAnimation(key: string, fadeTime: number?)
	local animInfo = self._loadedAnimations[key]
	
	if not animInfo or not animInfo.IsPlaying then
		return
	end
	
	animInfo.Track:Stop(fadeTime or 0.2)
	animInfo.IsPlaying = false
	
	if self._currentTrack == animInfo.Track then
		self._currentTrack = nil
	end
	
	Logger:Debug("Animation stopped", {key = key})
end

function AnimationManager:_GetAnimationTrack(key: string): AnimationTrack?
	local animInfo = self._loadedAnimations[key]
	return animInfo and animInfo.Track
end

-- ========================================
-- CLEANUP
-- ========================================

function AnimationManager:Destroy()
	-- Cancel block transition thread if exists
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
	
	-- Stop and destroy all tracks (with their individual connections)
	for _key, animInfo in pairs(self._loadedAnimations) do
		if animInfo.EndedConnection then
			animInfo.EndedConnection:Disconnect()
		end
		if animInfo.Track then
			animInfo.Track:Destroy()
		end
	end
	
	-- Clear references
	table.clear(self._loadedAnimations)
	self._currentTrack = nil
	self.Character = nil
	self.Humanoid = nil
	self.Animator = nil
	self._isInitialized = false
	
	Logger:Info("AnimationManager destroyed")
end

return AnimationManager
