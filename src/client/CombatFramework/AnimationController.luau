--[[
	Module: AnimationController
	Type: Client Animation Controller
	Location: ReplicatedFirst.CombatFramework.AnimationController
	Path: src/client/CombatFramework/AnimationController.luau
	
	Description:
		Client-side wrapper for AnimationManager from shared modules.
		Manages animation initialization, loading, and playback for combat actions.
		Provides simplified interface for playing attack, dash, and slide animations.
	
	Features:
		- Animation manager initialization and lifecycle
		- Character-specific animation loading
		- Attack animation playback (M1 combos, M2)
		- Movement animation playback (Dash, Slide)
		- Null-safety checks for animations
	
	Usage:
		local animController = AnimationController.new(character)
		animController:PlayLightAttack(comboCount)
		animController:PlayStrongAttack()
		animController:PlayDash(direction)
		animController:PlaySlide()
		animController:LoadAnimations(character)
	
	Author: Professional Roblox Scripter
	Created: December 13, 2025
--]]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Module Imports
local CombatSystem = ReplicatedStorage:WaitForChild("CombatCore")
local Core = CombatSystem:WaitForChild("Core")
local AnimationsFolder = CombatSystem:WaitForChild("Animations")

local Logger = require(Core.Logger).GetInstance()
local Enums = require(Core.Enums)

-- Shared AnimationManager
local AnimationManager = require(AnimationsFolder:WaitForChild("AnimationManager"))

-- ========================================
-- ANIMATION CONTROLLER CLASS
-- ========================================

local AnimationController = {}
AnimationController.__index = AnimationController

-- ========================================
-- TYPES
-- ========================================

export type AnimationController = {
	_animationManager: any?,
	
	LoadAnimations: (self: AnimationController, character: Model) -> (),
	PlayLightAttack: (self: AnimationController, comboCount: number) -> (),
	PlayStrongAttack: (self: AnimationController) -> (),
	PlayDash: (self: AnimationController, direction: string) -> (),
	PlaySlide: (self: AnimationController) -> (),
	Destroy: (self: AnimationController) -> (),
}

-- ========================================
-- CONSTRUCTOR
-- ========================================

function AnimationController.new(character: Model?): AnimationController
	local self = setmetatable({}, AnimationController)
	
	-- Initialize shared AnimationManager
	if character then
		self._animationManager = AnimationManager.new(character)
	else
		self._animationManager = nil
		Logger:Warning("AnimationController created without character - animations will not play until LoadAnimations is called")
	end
	
	return self
end

-- ========================================
-- ANIMATION LOADING
-- ========================================

-- Load animations for a character (used on spawn/respawn)
function AnimationController:LoadAnimations(character: Model)
	if not character then
		Logger:Warning("Cannot load animations - character is nil")
		return
	end
	
	-- Create new AnimationManager if needed
	if not self._animationManager then
		self._animationManager = AnimationManager.new(character)
	else
		-- Reload animations for new character
		self._animationManager:LoadAnimations(character)
	end
end

-- ========================================
-- VALIDATION
-- ========================================

-- Validate AnimationManager is initialized
function AnimationController:_ValidateManager(actionName: string): boolean
	if not self._animationManager then
		Logger:Warning(`Cannot play {actionName} animation - AnimationManager not initialized`)
		return false
	end
	return true
end

-- ========================================
-- ANIMATION PLAYBACK
-- ========================================

-- Play light attack animation (M1) with combo support
function AnimationController:PlayLightAttack(comboCount: number)
	if not self:_ValidateManager("light attack") then return end
	
	self._animationManager:PlayAttackAnimation(Enums.AttackType.LightAttack, comboCount)
end

-- Play strong attack animation (M2)
function AnimationController:PlayStrongAttack()
	if not self:_ValidateManager("strong attack") then return end
	
	self._animationManager:PlayAttackAnimation(Enums.AttackType.StrongAttack)
end

-- Play dash animation
function AnimationController:PlayDash(direction: string)
	if not self:_ValidateManager("dash") then return end
	
	self._animationManager:PlayDashAnimation(direction)
end

-- Play slide animation
function AnimationController:PlaySlide()
	if not self:_ValidateManager("slide") then return end
	
	self._animationManager:PlaySlideAnimation()
end

-- ========================================
-- CLEANUP
-- ========================================

function AnimationController:Destroy()
	if self._animationManager then
		self._animationManager:Destroy()
		self._animationManager = nil
	end
end

return AnimationController
