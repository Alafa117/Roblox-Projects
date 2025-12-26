--[[
	Module: CombatController
	Type: Client Main Controller
	Location: StarterPlayer.StarterPlayerScripts.CombatFramework.Core.CombatController
	Path: src/client/CombatFramework/Core/CombatController.luau
	
	Description:
		Main client-side controller for the Combat System.
		Manages input handling, server communication, local state, and visual feedback.
		Implements client-side prediction for responsive combat feel.
		Coordinates between all submodules (Input, State, Animation, Movement, Visual, Character).
	
	Dependencies:
		- ReplicatedStorage.CombatCore (Enums, Logger, PhysicsHelper)
		- CombatFramework submodules (CharacterManager, StateManager, InputHandler, etc.)
	
	Author: Professional Roblox Scripter
	Created: December 10, 2025
	Updated: December 23, 2025 - Reorganized into modular folder structure
--]]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Module Imports
local RS = ReplicatedStorage
local CombatSystem = RS:WaitForChild("CombatCore")

local Enums = require(CombatSystem.Data.Enums)
local Logger = require(CombatSystem.Logging.Logger).GetInstance()
local PhysicsHelper = require(CombatSystem.Helpers.PhysicsHelper)

local CharacterManager = require(script.Parent.Parent.Character.CharacterManager)
local CooldownManager = require(script.Parent.Parent.State.CooldownManager)
local ComboManager = require(script.Parent.Parent.State.ComboManager)
local AnimationController = require(script.Parent.Parent.Animation.AnimationController)
local ActionHandler = require(script.Parent.ActionHandler)
local InputHandler = require(script.Parent.Parent.Input.InputHandler)
local InputBuffering = require(script.Parent.Parent.Input.InputBuffering)
local StateManager = require(script.Parent.Parent.State.StateManager)
local MovementController = require(script.Parent.Parent.Movement.MovementController)
local VisualEffectsController = require(script.Parent.Parent.Visual.VisualEffectsController)

-- Valid states for each action type
-- M1, M2, Block can CANCEL Dash/Slide
-- Dash/Slide can only execute from Idle (no canceling)
-- Stunned state BLOCKS all actions (stun must expire to Idle first)
local VALID_ACTION_STATES = {
	[Enums.ActionType.M1] = {
		[Enums.CombatState.Idle] = true,
		[Enums.CombatState.LightAttacking] = true, -- M1 combo chains only
		[Enums.CombatState.Dashing] = true,   -- Can cancel Dash
		[Enums.CombatState.Sliding] = true,   -- Can cancel Slide
		-- StrongAttacking NOT allowed (M2 blocks M1)
		-- Stunned NOT allowed (must expire to Idle first)
	},
	[Enums.ActionType.M2] = {
		[Enums.CombatState.Idle] = true,
		[Enums.CombatState.Dashing] = true,   -- Can cancel Dash
		[Enums.CombatState.Sliding] = true,   -- Can cancel Slide
		-- LightAttacking NOT allowed (M1 blocks M2)
		-- StrongAttacking NOT allowed (M2 blocks M2)
		-- Stunned NOT allowed (must expire to Idle first)
	},
	[Enums.ActionType.Q] = {
		[Enums.CombatState.Idle] = true,
		-- Cannot cancel any action
		-- Stunned NOT allowed
	},
	[Enums.ActionType.C] = {
		[Enums.CombatState.Idle] = true,
		-- Cannot cancel any action
		-- Stunned NOT allowed
	},
	[Enums.ActionType.F] = {
		[Enums.CombatState.Idle] = true,
		[Enums.CombatState.Blocking] = true,  -- Can hold/re-block
		[Enums.CombatState.Dashing] = true,   -- Can cancel Dash
		[Enums.CombatState.Sliding] = true,   -- Can cancel Slide
		-- Stunned NOT allowed
	},
}

-- Combat Controller Class
local CombatController = {}
CombatController.__index = CombatController

-- ========================================
-- TYPES
-- ========================================

type CombatController = {
	_characterManager: any,
	_cooldownManager: any,
	_comboManager: any,
	_inputHandler: any,
	_inputBuffering: any,
	_stateManager: any,
	_movementController: any,
	_visualEffects: any,
	_animationController: any,
	_actionHandler: any,
	_networkManager: any?,
	
	_currentState: string,
	
	_connections: {RBXScriptConnection},
	_isInitialized: boolean,
	_enabled: boolean,
}

-- ========================================
-- CONSTRUCTOR
-- ========================================

function CombatController.new(): CombatController
	local self = setmetatable({}, CombatController)
	
	-- Core Components
	self._characterManager = CharacterManager.new()
	self._cooldownManager = CooldownManager.new()
	self._comboManager = ComboManager.new()
	self._inputHandler = InputHandler.new()
	self._inputBuffering = InputBuffering.new()
	self._stateManager = StateManager.new(self)
	self._movementController = MovementController.new()
	self._visualEffects = VisualEffectsController.new()
	self._animationController = AnimationController.new()
	self._actionHandler = ActionHandler.new(self)
	self._networkManager = nil
	
	-- State
	self._currentState = Enums.CombatState.Idle
	
	-- Event connections tracking
	self._connections = {}
	
	-- Flags
	self._isInitialized = false
	self._enabled = false
	
	Logger:Info("CombatController created")
	
	return self
end

-- ========================================
-- INITIALIZATION
-- ========================================

function CombatController:Initialize()
	if self._isInitialized then return end
	
	-- Character manager
	self._characterManager:Initialize(
		function(character) self:_OnCharacterAdded(character) end,
		function() self:_OnCharacterDied() end
	)
	self._characterManager:WaitForCharacter()
	
	-- Network and ActionHandler
	self:_InitializeNetworkManager()
	self._actionHandler:Initialize({
		stateManager = self._stateManager,
		cooldownManager = self._cooldownManager,
		animationController = self._animationController,
		movementController = self._movementController,
		visualEffects = self._visualEffects,
		networkManager = self._networkManager,
		inputBuffering = self._inputBuffering,
		comboManager = self._comboManager,
	})
	
	-- Input and update loop
	self:_SetupInputCallbacks()
	self._inputHandler:Initialize()
	self:_StartUpdateLoop()
	
	self._isInitialized = true
	self._enabled = true
end

-- ========================================
-- CHARACTER SETUP
-- ========================================

function CombatController:_OnCharacterAdded(character: Model)
	-- Clean up previous state
	if self._movementController then
		self._movementController:StopMovement()
	end
	if self._visualEffects then
		self._visualEffects:ClearAllEffects()
	end
	if self._stateManager then
		self._stateManager:CancelAllTimers()
	end
	
	-- Reset state
	self:_ResetState()
	
	-- Load animations for character
	self._animationController:LoadAnimations(character)
	
	Logger:Info("CombatController ready for character", {character = character.Name})
end

function CombatController:_OnCharacterDied()
	-- Disable inputs
	self._inputHandler:BlockAllInputs(true)
	
	-- Death overrides all states - set directly
	self._currentState = Enums.CombatState.Dead
	
	Logger:Info("Character died")
end

-- ========================================
-- NETWORK MANAGER SETUP
-- ========================================

function CombatController:_InitializeNetworkManager()
	local NetworkManager = require(CombatSystem:WaitForChild("Network"):WaitForChild("NetworkManager"))
	self._networkManager = NetworkManager.GetClientInstance()
	
	-- Register callbacks
	self._networkManager:RegisterCallback(Enums.NetworkEvent.StateChanged, function(data)
		self:_OnServerStateChanged(data)
	end)
	self._networkManager:RegisterCallback(Enums.NetworkEvent.ActionResult, function(data)
		self:_OnActionResult(data)
	end)
	self._networkManager:RegisterCallback(Enums.NetworkEvent.TakeDamage, function(data)
		self:_OnTakeDamage(data)
	end)
	self._networkManager:RegisterCallback(Enums.NetworkEvent.ApplyKnockback, function(data)
		self:_OnApplyKnockback(data)
	end)
end

function CombatController:_SetupInputCallbacks()
	-- M1/M2 attacks
	self._inputHandler:RegisterCallback(Enums.ActionType.M1, function(_, state)
		if state == Enum.UserInputState.Begin then
			self._actionHandler:HandleLightAttack()
		end
	end)
	self._inputHandler:RegisterCallback(Enums.ActionType.M2, function(_, state)
		if state == Enum.UserInputState.Begin then
			self._actionHandler:HandleStrongAttack()
		end
	end)
	
	-- Movement (Q/C) with direction
	self._inputHandler:RegisterCallback(Enums.ActionType.Q, function(_, state, _, direction)
		if state == Enum.UserInputState.Begin then
			self._actionHandler:HandleDash(direction)
		end
	end)
	self._inputHandler:RegisterCallback(Enums.ActionType.C, function(_, state, _, direction)
		if state == Enum.UserInputState.Begin then
			self._actionHandler:HandleSlide(direction)
		end
	end)
	
	-- Block (F) with Begin/End
	self._inputHandler:RegisterCallback(Enums.ActionType.F, function(_, state)
		if state == Enum.UserInputState.Begin then
			self._actionHandler:HandleBlockStart()
		elseif state == Enum.UserInputState.End then
			self._actionHandler:HandleBlockEnd()
		end
	end)
end

-- ========================================
-- ACCESSOR METHODS (for ActionHandler)
-- ========================================

function CombatController:CanPerformAction(actionType: string): boolean
	return self:_CanPerformAction(actionType)
end

-- ========================================
-- SERVER CALLBACKS
-- ========================================

function CombatController:_OnServerStateChanged(stateData)
	local newState = type(stateData) == "table" and stateData.State or stateData
	if type(newState) == "string" then
		self._currentState = newState
	end
end

function CombatController:_OnActionResult(result: {[string]: any})
	if not result.Success then
		self._stateManager:SetState(Enums.CombatState.Idle, "action_rejected")
	end
end

function CombatController:_OnTakeDamage(_damageData: {[string]: any})
	local character = self._characterManager:GetCharacter()
	if character then
		self._visualEffects:PlayHitEffect(character)
	end
end

function CombatController:_OnApplyKnockback(knockbackData: {[string]: any})
	local character = self._characterManager:GetCharacter()
	if character then
		PhysicsHelper.ApplyKnockback(character, knockbackData.Direction, knockbackData.Force)
	end
end

-- ========================================
-- VALIDATION
-- ========================================

function CombatController:_CanPerformAction(actionType: string): boolean
	-- Basic checks
	if not self._enabled or not self._characterManager:IsCharacterValid() then
		return false
	end
	
	-- State validation
	if type(self._currentState) ~= "string" then
		self._currentState = Enums.CombatState.Idle
	end
	
	-- Block if dead (but NOT stunned - stun expires automatically)
	if self._currentState == Enums.CombatState.Dead then
		return false
	end
	
	-- Check if action allowed in current state
	local validStates = VALID_ACTION_STATES[actionType]
	if validStates and not validStates[self._currentState] then
		return false
	end
	
	-- Check cooldown
	return self._cooldownManager:IsReady(actionType)
end

-- ========================================
-- UPDATE LOOP
-- ========================================

function CombatController:_StartUpdateLoop()
	table.insert(self._connections, RunService.Heartbeat:Connect(function()
		if not self._enabled then return end
		
		-- Update combo window first (reset if expired)
		self._comboManager:UpdateComboWindow()
		
		-- REMOVED: Auto-execution of buffered inputs (December 26, 2025)
		-- This was causing infinite loop where inputs executed every frame
		-- ignoring cooldowns, especially after hit 6 finisher
		-- Input buffering should only happen during combo chains, not as auto-retry
	end))
end

-- ========================================
-- STATE MANAGEMENT
-- ========================================

function CombatController:_ResetState()
	self._stateManager:SetState(Enums.CombatState.Idle, "reset")
	self._comboManager:ResetCombo()
	self._cooldownManager:Reset()
	self._inputHandler:BlockAllInputs(false)
	self._inputBuffering:ClearBuffer()
end

-- ========================================
-- PUBLIC API
-- ========================================

function CombatController:GetCurrentState(): string
	return self._currentState
end

function CombatController:IsEnabled(): boolean
	return self._enabled
end

function CombatController:SetEnabled(enabled: boolean)
	self._enabled = enabled
	self._inputHandler:BlockAllInputs(not enabled)
end

-- ========================================
-- CLEANUP
-- ========================================

function CombatController:Destroy()
	self._enabled = false
	
	-- Disconnect connections
	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end
	
	-- Destroy all managers
	for _, manager in pairs({
		self._characterManager,
		self._cooldownManager,
		self._comboManager,
		self._inputHandler,
		self._inputBuffering,
		self._stateManager,
		self._movementController,
		self._visualEffects,
		self._animationController
	}) do
		if manager and manager.Destroy then
			manager:Destroy()
		end
	end
end

return CombatController
