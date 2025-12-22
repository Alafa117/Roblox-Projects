--[[
	Module: AnimationManager
	Type: Shared Animation Manager (Facade)
	Location: ReplicatedStorage.CombatCore.Animations.AnimationManager
	Path: src/shared/CombatCore/Animations/AnimationManager.luau
	
	Description:
		Facade that coordinates animation subsystems for characters.
		Delegates to specialized modules for separation of concerns:
		- AnimationCache: Stores and manages loaded animation tracks
		- AnimationLoader: Handles loading animations from Config
		- AnimationPlayer: Controls playback, transitions, and timing
		
		Maintains backward compatibility with existing API.
		Optimized for R6 avatars with proper lifecycle management.
	
	Phase 2 Refactoring:
		Extracted into 3 specialized modules for better maintainability.
		AnimationManager now acts as coordinator/facade.
	
	Dependencies:
		- ReplicatedStorage.CombatCore.Core.Logger
		- ReplicatedStorage.CombatCore.Animations (Cache, Loader, Player)
	
	Author: Professional Roblox Scripter
	Created: December 11, 2025
	Refactored: December 18, 2025 (Phase 2 - Task 1)
--]]

-- Module Imports
local Logger = require(script.Parent.Parent.Logging.Logger).GetInstance()
local AnimationCache = require(script.Parent.AnimationCache)
local AnimationLoader = require(script.Parent.AnimationLoader)
local AnimationPlayer = require(script.Parent.AnimationPlayer)

-- Animation Manager Class
local AnimationManager = {}
AnimationManager.__index = AnimationManager

-- ========================================
-- TYPES
-- ========================================

type AnimationManager = {
	Character: Model,
	Humanoid: Humanoid?,
	Animator: Animator?,
	
	_cache: typeof(AnimationCache.new()),
	_loader: typeof(AnimationLoader.new()),
	_player: typeof(AnimationPlayer.new()),
	_isInitialized: boolean,
}

-- ========================================
-- CONSTRUCTOR
-- ========================================

function AnimationManager.new(character: Model?): AnimationManager
	local self = setmetatable({}, AnimationManager)
	
	self.Character = character
	self.Humanoid = nil
	self.Animator = nil
	
	-- Initialize subsystems
	self._cache = AnimationCache.new()
	self._loader = AnimationLoader.new(nil, self._cache)
	self._player = AnimationPlayer.new(self._cache)
	self._isInitialized = false
	
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
	
	-- Set animator in loader and load all animations
	self._loader:SetAnimator(self.Animator)
	self._loader:LoadAllAnimations()
	
	self._isInitialized = true
	
	Logger:Info("Animations loaded", {character = character.Name, count = self._cache:GetSize()})
end

-- ========================================
-- PUBLIC API - Delegates to Subsystems
-- ========================================

-- Play attack animation (delegates to player)
function AnimationManager:PlayAttackAnimation(attackType: string, comboCount: number?)
	self._player:PlayAttackAnimation(attackType, comboCount)
end

-- Play block animation (delegates to player)
function AnimationManager:PlayBlockAnimation(isBlocking: boolean)
	self._player:PlayBlockAnimation(isBlocking)
end

-- Play dash animation (delegates to player)
function AnimationManager:PlayDashAnimation(direction: string)
	self._player:PlayDashAnimation(direction)
end

-- Play slide animation (delegates to player)
function AnimationManager:PlaySlideAnimation()
	self._player:PlaySlideAnimation()
end

-- Play hit animation (delegates to player)
function AnimationManager:PlayHitAnimation(isHeavy: boolean?, isBlocked: boolean?)
	self._player:PlayHitAnimation(isHeavy, isBlocked)
end

-- ========================================
-- UTILITIES
-- ========================================

-- Get current playing track
function AnimationManager:GetCurrentTrack(): AnimationTrack?
	return self._player:GetCurrentTrack()
end

-- Check if animation is playing
function AnimationManager:IsPlaying(key: string): boolean
	return self._player:IsPlaying(key)
end

-- Get animation track from cache
function AnimationManager:GetAnimationTrack(key: string): AnimationTrack?
	return self._cache:GetTrack(key)
end

-- ========================================
-- CLEANUP
-- ========================================

function AnimationManager:Destroy()
	-- Cleanup subsystems
	self._player:Destroy()
	self._cache:Destroy()
	
	-- Clear references
	self.Character = nil
	self.Humanoid = nil
	self.Animator = nil
	self._isInitialized = false
	
	Logger:Info("AnimationManager destroyed")
end

return AnimationManager
