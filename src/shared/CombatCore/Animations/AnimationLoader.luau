--[[
	Module: AnimationLoader
	Type: Animation Loading System
	Location: ReplicatedStorage.CombatCore.Animations.AnimationLoader
	Path: src/shared/CombatCore/Animations/AnimationLoader.luau
	
	Description:
		Handles loading all combat animations into memory.
		Creates Animation instances from Config IDs and loads tracks via Animator.
		Stores loaded tracks in AnimationCache for efficient reuse.
		
		Separated from AnimationManager for single responsibility.
		Phase 2 Refactoring - Extracted from AnimationManager.
	
	Responsibilities:
		- Load animation tracks from Animator
		- Validate animation IDs
		- Handle loading errors gracefully
		- Organize animations by type (attacks, blocks, movement, hits)
	
	Dependencies:
		- ReplicatedStorage.CombatCore.Core (Config, Enums, Logger)
		- ReplicatedStorage.CombatCore.Animations.AnimationCache
	
	Author: Professional Roblox Scripter
	Created: December 18, 2025 (Phase 2 - Task 1)
--]]

-- Services
-- Module Imports
local Config = require(script.Parent.Parent.Config.Config)
local Enums = require(script.Parent.Parent.Data.Enums)
local Logger = require(script.Parent.Parent.Logging.Logger).GetInstance()
local AnimationCache = require(script.Parent.AnimationCache)

-- Animation Loader Module
local AnimationLoader = {}
AnimationLoader.__index = AnimationLoader

-- ========================================
-- TYPES
-- ========================================

type AnimationLoader = {
	_animator: Animator?,
	_cache: typeof(AnimationCache.new()),
}

-- ========================================
-- CONSTRUCTOR
-- ========================================

function AnimationLoader.new(animator: Animator?, cache: typeof(AnimationCache.new())): AnimationLoader
	local self = setmetatable({}, AnimationLoader)
	
	self._animator = animator
	self._cache = cache
	
	return self
end

-- ========================================
-- BULK LOADING
-- ========================================

-- Load all combat animations at once
function AnimationLoader:LoadAllAnimations()
	if not self._animator then
		Logger:Error("No Animator available for loading animations")
		return
	end
	
	self:LoadLightAttackAnimations()
	self:LoadStrongAttackAnimations()
	self:LoadBlockAnimations()
	self:LoadDashAnimations()
	self:LoadSlideAnimations()
	self:LoadHitAnimations()
	
	Logger:Info("All animations loaded", {count = self._cache:GetSize()})
end

-- ========================================
-- TYPE-SPECIFIC LOADING
-- ========================================

function AnimationLoader:LoadLightAttackAnimations()
	for comboIndex, animationId in pairs(Config.Animations.LightAttack) do
		local key = string.format("LightAttack_%d", comboIndex)
		self:LoadAnimation(key, animationId, Enums.AnimationPriority.Action)
	end
end

function AnimationLoader:LoadStrongAttackAnimations()
	-- StrongAttack is instant (no charge animation needed)
	self:LoadAnimation("StrongAttack_Release", Config.Animations.StrongAttack.Release, Enums.AnimationPriority.Action2)
end

function AnimationLoader:LoadBlockAnimations()
	self:LoadAnimation("Block_Start", Config.Animations.Block.Start, Enums.AnimationPriority.Action)
	self:LoadAnimation("Block_Hold", Config.Animations.Block.Hold, Enums.AnimationPriority.Action)
	self:LoadAnimation("Block_End", Config.Animations.Block.End, Enums.AnimationPriority.Action)
	self:LoadAnimation("Block_Break", Config.Animations.Block.Break, Enums.AnimationPriority.Action)
end

function AnimationLoader:LoadDashAnimations()
	for direction, animationId in pairs(Config.Animations.Dash) do
		local key = string.format("Dash_%s", direction)
		self:LoadAnimation(key, animationId, Enums.AnimationPriority.Action3)
	end
end

function AnimationLoader:LoadSlideAnimations()
	self:LoadAnimation("Slide_Start", Config.Animations.Slide.Start, Enums.AnimationPriority.Action3)
end

function AnimationLoader:LoadHitAnimations()
	self:LoadAnimation("Hit_Light", Config.Animations.Hit.Light, Enums.AnimationPriority.Action)
	self:LoadAnimation("Hit_Heavy", Config.Animations.Hit.Heavy, Enums.AnimationPriority.Action)
	self:LoadAnimation("Hit_Blocked", Config.Animations.Hit.Blocked, Enums.AnimationPriority.Action)
end

-- ========================================
-- CORE LOADING
-- ========================================

function AnimationLoader:LoadAnimation(key: string, animationId: string, priority: Enum.AnimationPriority): AnimationTrack?
	if not self._animator then
		Logger:Warning("No Animator available")
		return nil
	end
	
	-- Skip if animation ID is invalid (placeholder)
	if animationId == "rbxassetid://0" or animationId == "" then
		Logger:Debug("Skipping placeholder animation", {key = key})
		return nil
	end
	
	-- Check if already loaded in cache
	if self._cache:Has(key) then
		Logger:Debug("Animation already cached", {key = key})
		return self._cache:GetTrack(key)
	end
	
	-- Create animation instance
	local animation = Instance.new("Animation")
	animation.AnimationId = animationId
	
	-- Load animation track
	local success, result = pcall(function()
		return self._animator:LoadAnimation(animation)
	end)
	
	if not success then
		Logger:Error("Failed to load animation", {key = key, error = result})
		return nil
	end
	
	local track: AnimationTrack = result
	track.Priority = priority
	
	-- Store in cache
	self._cache:Store(key, track, animationId, priority)
	
	Logger:Debug("Animation loaded", {key = key, id = animationId})
	
	return track
end

-- ========================================
-- UTILITIES
-- ========================================

-- Set animator (useful if character respawns)
function AnimationLoader:SetAnimator(animator: Animator?)
	self._animator = animator
end

-- Get current animator
function AnimationLoader:GetAnimator(): Animator?
	return self._animator
end

return AnimationLoader
