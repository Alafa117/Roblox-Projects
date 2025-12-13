--[[
	Module: CombatController
	Type: Client Main Controller
	Location: StarterPlayer.StarterPlayerScripts.CombatFramework.CombatController
	Path: src/client/CombatFramework/CombatController.luau
	
	Description:
		Main client-side controller for the Combat System.
		Manages input handling, server communication, local state, and visual feedback.
		Implements client-side prediction for responsive combat feel.
		Coordinates between InputHandler, AnimationManager, and network layer.
	
	Dependencies:
		- ReplicatedStorage.CombatCore.Core (Config, Enums, Types, Logger, Utility)
		- ReplicatedStorage.CombatCore.Network.NetworkManager
		- CombatController.InputHandler
		- CombatController.InputBuffering
	
	Author: Professional Roblox Scripter
	Created: December 10, 2025
--]]

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Module Imports
local RS = ReplicatedStorage
local CombatSystem = RS:WaitForChild("CombatCore")
local Core = CombatSystem:WaitForChild("Core")

local Config = require(Core.Config)
local Enums = require(Core.Enums)
local Logger = require(Core.Logger).GetInstance()
local Utility = require(Core.Utility)
local DebugLogger = require(Core.DebugLogger)

local InputHandler = require(script.Parent.InputHandler)
local InputBuffering = require(script.Parent.InputBuffering)
local StateManager = require(script.Parent.StateManager)
local MovementController = require(script.Parent.MovementController)
local VisualEffectsController = require(script.Parent.VisualEffectsController)

-- Constants
local LocalPlayer = Players.LocalPlayer

-- Cooldown configuration lookup table (more efficient than if-elseif chain)
local COOLDOWN_CONFIGS = {
	[Enums.ActionType.M1] = function() return Config.LightAttack.Cooldown end,
	[Enums.ActionType.M2] = function() return Config.StrongAttack.Cooldown end,
	[Enums.ActionType.Q] = function() return Config.Dash.Cooldown end,
	[Enums.ActionType.C] = function() return Config.Slide.Cooldown end,
	[Enums.ActionType.F] = function() return Config.Block.Cooldown end,
}

-- Valid states for each action type
local VALID_ACTION_STATES = {
	[Enums.ActionType.M1] = {
		[Enums.CombatState.Idle] = true,
		[Enums.CombatState.Attacking] = true, -- Combo chains
		[Enums.CombatState.Dashing] = true, -- Cancel dash
		[Enums.CombatState.Sliding] = true, -- Cancel slide
	},
	[Enums.ActionType.M2] = {
		[Enums.CombatState.Idle] = true,
		[Enums.CombatState.Dashing] = true, -- Cancel dash
		[Enums.CombatState.Sliding] = true, -- Cancel slide
	},
	[Enums.ActionType.Q] = {
		[Enums.CombatState.Idle] = true,
		[Enums.CombatState.Blocking] = true,
	},
	[Enums.ActionType.C] = {
		[Enums.CombatState.Idle] = true,
		[Enums.CombatState.Blocking] = true,
	},
	[Enums.ActionType.F] = {
		[Enums.CombatState.Idle] = true,
		[Enums.CombatState.Blocking] = true, -- Can re-block
	},
}

-- Combat Controller Class
local CombatController = {}
CombatController.__index = CombatController

-- ========================================
-- TYPES
-- ========================================

type CombatController = {
	_inputHandler: any,
	_inputBuffering: any,
	_stateManager: any,
	_movementController: any,
	_visualEffects: any,
	_networkManager: any?,
	_animationManager: any?,
	
	_currentState: string,
	_comboCount: number,
	_lastAttackTime: number,
	
	_cooldowns: {[string]: number},
	_isInitialized: boolean,
	_enabled: boolean,
	
	Character: Model?,
	Humanoid: Humanoid?,
	HumanoidRootPart: BasePart?,
}

-- ========================================
-- CONSTRUCTOR
-- ========================================

function CombatController.new(): CombatController
	local self = setmetatable({}, CombatController)
	
	-- Core Components
	self._inputHandler = InputHandler.new()
	self._inputBuffering = InputBuffering.new()
	self._stateManager = StateManager.new(self)
	self._movementController = MovementController.new()
	self._visualEffects = VisualEffectsController.new()
	self._networkManager = nil
	self._animationManager = nil
	
	-- State
	self._currentState = Enums.CombatState.Idle
	self._comboCount = 0
	self._lastAttackTime = 0
	
	-- Cooldowns (dynamic initialization from Enums)
	self._cooldowns = {}
	for _, actionType in pairs(Enums.ActionType) do
		self._cooldowns[actionType] = 0
	end
	
	-- Flags
	self._isInitialized = false
	self._enabled = false
	
	-- Character References
	self.Character = nil
	self.Humanoid = nil
	self.HumanoidRootPart = nil
	
	Logger:Info("CombatController created")
	
	return self
end

-- ========================================
-- INITIALIZATION
-- ========================================

function CombatController:Initialize()
	if self._isInitialized then
		Logger:Warning("CombatController already initialized")
		return
	end
	
	-- Wait for character
	self:_WaitForCharacter()
	
	-- Initialize network manager
	self:_InitializeNetworkManager()
	
	-- Initialize animation manager
	self:_InitializeAnimationManager()
	
	-- Setup input callbacks
	self:_SetupInputCallbacks()
	
	-- Initialize input handler
	self._inputHandler:Initialize()
	
	-- Start update loop
	self:_StartUpdateLoop()
	
	self._isInitialized = true
	self._enabled = true
	
	Logger:Info("CombatController initialized successfully")
end

-- ========================================
-- CHARACTER SETUP
-- ========================================

function CombatController:_WaitForCharacter()
	-- Wait for initial character
	if not LocalPlayer.Character then
		LocalPlayer.CharacterAdded:Wait()
	end
	
	self:_OnCharacterAdded(LocalPlayer.Character)
	
	-- Listen for respawns
	LocalPlayer.CharacterAdded:Connect(function(character)
		self:_OnCharacterAdded(character)
	end)
end

function CombatController:_OnCharacterAdded(character: Model)
	-- Wait for humanoid
	local humanoid = character:WaitForChild("Humanoid", 5)
	local rootPart = character:WaitForChild("HumanoidRootPart", 5)
	
	if not humanoid or not rootPart then
		Logger:Error("Failed to get character components")
		return
	end
	
	-- Verify R6
	if not Utility.IsR6Character(character) then
		Logger:Warning("Character is not R6, combat system may not work correctly")
	end
	
	-- Update references
	self.Character = character
	self.Humanoid = humanoid
	self.HumanoidRootPart = rootPart
	
	-- Reset state
	self:_ResetState()
	
	-- Load animations
	if self._animationManager then
		self._animationManager:LoadAnimations(character)
	end
	
	-- Listen for death
	humanoid.Died:Connect(function()
		self:_OnCharacterDied()
	end)
	
	Logger:Info("Character loaded", {character = character.Name})
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
	-- Wait for network manager
	local networkManagerModule = CombatSystem:WaitForChild("Network"):WaitForChild("NetworkManager")
	local NetworkManager = require(networkManagerModule)
	
	self._networkManager = NetworkManager.GetClientInstance()
	
	-- Register server callbacks using table for cleaner code
	local networkCallbacks = {
		[Enums.NetworkEvent.StateChanged] = function(newState)
			self:_OnServerStateChanged(newState)
		end,
		[Enums.NetworkEvent.ActionResult] = function(result)
			self:_OnActionResult(result)
		end,
		[Enums.NetworkEvent.TakeDamage] = function(damageData)
			self:_OnTakeDamage(damageData)
		end,
		[Enums.NetworkEvent.ApplyKnockback] = function(knockbackData)
			self:_OnApplyKnockback(knockbackData)
		end,
	}
	
	for eventType, callback in pairs(networkCallbacks) do
		self._networkManager:RegisterCallback(eventType, callback)
	end
	
	Logger:Debug("NetworkManager initialized")
end

-- ========================================
-- ANIMATION MANAGER SETUP
-- ========================================

function CombatController:_InitializeAnimationManager()
	-- Wait for animation manager
	local animationModule = CombatSystem:WaitForChild("Animations"):WaitForChild("AnimationManager")
	local AnimationManager = require(animationModule)
	
	self._animationManager = AnimationManager.new(self.Character)
	
	Logger:Debug("AnimationManager initialized")
end

-- ========================================
-- INPUT CALLBACKS
-- ========================================

function CombatController:_SetupInputCallbacks()
	-- Register input callbacks using table for cleaner code
	local inputCallbacks = {
		[Enums.ActionType.M1] = function(_actionType, inputState)
			if inputState == Enum.UserInputState.Begin then
				self:_HandleLightAttack()
			end
		end,
		
		[Enums.ActionType.M2] = function(_actionType, inputState)
			if inputState == Enum.UserInputState.Begin then
				self:_HandleStrongAttack()
			end
		end,
		
		[Enums.ActionType.Q] = function(_actionType, inputState, _inputObject, direction)
			DebugLogger.ClientAction("Dash callback", string.format("State: %s, Direction: %s", tostring(inputState), direction))
			if inputState == Enum.UserInputState.Begin then
				self:_HandleDash(direction)
			end
		end,
		
		[Enums.ActionType.C] = function(_actionType, inputState, _inputObject, direction)
			DebugLogger.ClientAction("Slide callback", string.format("State: %s, Direction: %s", tostring(inputState), direction))
			if inputState == Enum.UserInputState.Begin then
				self:_HandleSlide(direction)
			end
		end,
		
		[Enums.ActionType.F] = function(_actionType, inputState)
			if inputState == Enum.UserInputState.Begin then
				self:_HandleBlockStart()
			elseif inputState == Enum.UserInputState.End then
				self:_HandleBlockEnd()
			end
		end,
	}
	
	for actionType, callback in pairs(inputCallbacks) do
		self._inputHandler:RegisterCallback(actionType, callback)
	end
	
	Logger:Debug("Input callbacks registered")
end

-- ========================================
-- ACTION HANDLERS
-- ========================================

-- Helper: Detect and cancel active movement (Dash/Slide) if any
-- Returns movement type being cancelled ("Dash", "Slide", or nil)
function CombatController:_CancelActiveMovement()
	-- Check BOTH state AND MovementController to catch movement mid-execution
	local wasDashing = self._currentState == Enums.CombatState.Dashing
	local wasSliding = self._currentState == Enums.CombatState.Sliding
	local hasActiveMovement = self._movementController:IsMoving()
	
	if hasActiveMovement or wasDashing then
		DebugLogger.ClientAction("Movement", "Cancelled Dash")
		self._movementController:StopMovement()
		self._networkManager:SendToServer(Enums.NetworkEvent.CancelDash, {})
		return "Dash"
	elseif hasActiveMovement or wasSliding then
		DebugLogger.ClientAction("Movement", "Cancelled Slide")
		self._movementController:StopMovement()
		self._networkManager:SendToServer(Enums.NetworkEvent.CancelSlide, {})
		return "Slide"
	end
	
	return nil
end

function CombatController:_HandleLightAttack()
	-- Check if can attack
	if not self:_CanPerformAction(Enums.ActionType.M1) then
		self._inputBuffering:AddInput(Enums.ActionType.M1)
		return
	end
	
	-- IMPORTANT: Detect movement BEFORE changing state
	local wasDashing = self._currentState == Enums.CombatState.Dashing
	local wasSliding = self._currentState == Enums.CombatState.Sliding
	local cancelledMovement = wasDashing or wasSliding
	
	-- Check combo window
	local timeSinceLastAttack = os.clock() - self._lastAttackTime
	if timeSinceLastAttack <= Config.LightAttack.ComboWindow then
		self._comboCount = math.min(self._comboCount + 1, Config.LightAttack.MaxComboCount)
	else
		self._comboCount = 1
	end
	
	-- Update state using StateManager
	self._stateManager:HandleLightAttackState()
	self._lastAttackTime = os.clock()
	-- Cooldown activates IMMEDIATELY (regardless of hit/miss)
	self._cooldowns[Enums.ActionType.M1] = os.clock()
	
	-- Play animation locally (prediction)
	if self._animationManager then
		self._animationManager:PlayAttackAnimation(Enums.AttackType.LightAttack, self._comboCount)
	end
	
	-- Send to server with movement cancellation info
	DebugLogger.ClientAction("M1 Request", string.format("Combo: %d, CancelledMovement: %s", self._comboCount, tostring(cancelledMovement)))
	self._networkManager:SendToServer(Enums.NetworkEvent.RequestAction, {
		ActionType = Enums.ActionType.M1,
		ComboCount = self._comboCount,
		CancelledMovement = cancelledMovement, -- Tell server we were moving
	})
	
	-- Cancel movement AFTER sending attack (server knows we were moving)
	if cancelledMovement then
		self:_CancelActiveMovement()
	end
	
	Logger:Debug("Light attack requested", {combo = self._comboCount, cancelledMovement = cancelledMovement})
end

function CombatController:_HandleStrongAttack()
	DebugLogger.ClientAction("_HandleStrongAttack", "Called")
	-- Check if can attack
	if not self:_CanPerformAction(Enums.ActionType.M2) then
		DebugLogger.ClientValidationFailed("M2", "Cannot perform action")
		return
	end
	
	-- IMPORTANT: Detect movement BEFORE changing state
	local wasDashing = self._currentState == Enums.CombatState.Dashing
	local wasSliding = self._currentState == Enums.CombatState.Sliding
	local cancelledMovement = wasDashing or wasSliding
	
	-- Update state FIRST for instant attack
	self._stateManager:HandleStrongAttackState()
	-- Cooldown activates IMMEDIATELY (regardless of hit/miss)
	self._cooldowns[Enums.ActionType.M2] = os.clock()
	self._comboCount = 0 -- Reset combo
	
	-- Apply M2 visual effect
	self._visualEffects:ApplyStrongAttackEffect()
	
	-- Play animation locally
	if self._animationManager then
		self._animationManager:PlayAttackAnimation(Enums.AttackType.StrongAttack)
	end
	
	-- Send to server with movement cancellation info
	DebugLogger.ClientAction("M2 Request", string.format("Instant attack, CancelledMovement: %s", tostring(cancelledMovement)))
	self._networkManager:SendToServer(Enums.NetworkEvent.RequestAction, {
		ActionType = Enums.ActionType.M2,
		CancelledMovement = cancelledMovement, -- Tell server we were moving
	})
	
	-- Cancel movement AFTER sending attack (server knows we were moving)
	if cancelledMovement then
		self:_CancelActiveMovement()
	end
	
	Logger:Debug("Strong attack requested", {cancelledMovement = cancelledMovement})
end

function CombatController:_HandleDash(direction: string)
	DebugLogger.ClientAction("_HandleDash", string.format("Direction: %s", direction))
	-- Check if can dash
	if not self:_CanPerformAction(Enums.ActionType.Q) then
		DebugLogger.ClientValidationFailed("Dash", "Cannot perform action")
		return
	end
	
	-- Update state using StateManager
	self._stateManager:HandleDashState()
	self._cooldowns[Enums.ActionType.Q] = os.clock()
	
	-- Play animation locally
	if self._animationManager then
		self._animationManager:PlayDashAnimation(direction)
	end
	
	-- Send to server (for validation/authority)
	self._networkManager:SendToServer(Enums.NetworkEvent.RequestDash, {
		Direction = direction,
	})
	
	-- Start client-side dynamic movement
	self._movementController:StartDynamicMovement("Dash", {
		Speed = Config.Dash.Speed,
		Duration = Config.Dash.Duration,
		FrictionMultiplier = Config.Dash.FrictionMultiplier,
	})
	
	Logger:Debug("Dash requested", {direction = direction})
end

function CombatController:_HandleSlide(direction: string)
	DebugLogger.ClientAction("_HandleSlide", string.format("Direction: %s", direction))
	-- Check if can slide
	if not self:_CanPerformAction(Enums.ActionType.C) then
		DebugLogger.ClientValidationFailed("Slide", "Cannot perform action")
		return
	end
	
	-- Update state using StateManager
	self._stateManager:HandleSlideState()
	self._cooldowns[Enums.ActionType.C] = os.clock()
	
	-- Play animation locally
	if self._animationManager then
		self._animationManager:PlaySlideAnimation()
	end
	
	-- Send to server (for validation/authority)
	DebugLogger.ClientAction("Slide Request", "Sent to server")
	self._networkManager:SendToServer(Enums.NetworkEvent.RequestSlide, {
		Direction = direction,
	})
	
	-- Start client-side dynamic movement
	self._movementController:StartDynamicMovement("Slide", {
		Speed = Config.Slide.Speed,
		Duration = Config.Slide.Duration,
		FrictionMultiplier = Config.Slide.FrictionMultiplier,
	})
	
	Logger:Debug("Slide requested")
end

function CombatController:_HandleBlockStart()
	-- Check if can block
	if not self:_CanPerformAction(Enums.ActionType.F) then
		return
	end
	
	-- Update state using StateManager
	self._stateManager:HandleBlockStartState()
	
	-- Play animation locally
	if self._animationManager then
		self._animationManager:PlayBlockAnimation(true)
	end
	
	-- Send to server
	self._networkManager:SendToServer(Enums.NetworkEvent.RequestBlock, {
		IsBlocking = true,
	})
	
	Logger:Debug("Block started")
end

function CombatController:_HandleBlockEnd()
	-- Update state using StateManager
	self._stateManager:HandleBlockEndState()
	self._cooldowns[Enums.ActionType.F] = os.clock()
	
	-- Stop animation
	if self._animationManager then
		self._animationManager:PlayBlockAnimation(false)
	end
	
	-- Send to server
	self._networkManager:SendToServer(Enums.NetworkEvent.RequestBlock, {
		IsBlocking = false,
	})
	
	Logger:Debug("Block ended")
end

-- ========================================
-- SERVER CALLBACKS
-- ========================================

function CombatController:_OnServerStateChanged(stateData)
	-- Extract state from data (server sends {State = string})
	local newState = stateData
	if type(stateData) == "table" then
		newState = stateData.State
	end
	
	-- Validate that newState is a string
	if type(newState) ~= "string" then
		Logger:Error("Server sent invalid state", {
			dataType = type(stateData),
			stateType = type(newState),
			data = tostring(stateData)
		})
		return
	end
	
	-- Server has authority - bypass validation and set directly
	self._currentState = newState
	Logger:Debug("State changed by server", {state = newState})
	
	-- Block inputs based on state
	if newState == Enums.CombatState.Stunned or newState == Enums.CombatState.Dead then
		self._inputHandler:BlockAllInputs(true)
	else
		self._inputHandler:BlockAllInputs(false)
	end
end

function CombatController:_OnActionResult(result: {[string]: any})
	local success = result.Success
	local errorCode = result.ErrorCode
	
	if not success then
		Logger:Warning("Action rejected by server", {error = errorCode})
		
		-- Reset state on failure using StateManager
		self._stateManager:SetState(Enums.CombatState.Idle, "action_rejected")
	end
end

function CombatController:_OnTakeDamage(damageData: {[string]: any})
	-- Play hit animation
	if self._animationManager then
		self._animationManager:PlayHitAnimation()
	end
	
	-- Play VFX/SFX
	-- TODO: Implement visual effects
	
	Logger:Info("Took damage", {damage = damageData.Damage})
end

function CombatController:_OnApplyKnockback(knockbackData: {[string]: any})
	if not self.HumanoidRootPart then
		return
	end
	
	local direction = knockbackData.Direction
	local force = knockbackData.Force
	
	-- Apply knockback locally
	Utility.ApplyKnockback(self.Character, direction, force)
	
	Logger:Debug("Knockback applied", {force = force})
end

-- ========================================
-- VALIDATION
-- ========================================

function CombatController:_CanPerformAction(actionType: string): boolean
	-- Check if enabled
	if not self._enabled then
		DebugLogger.ClientValidationFailed(actionType, "System not enabled")
		return false
	end
	
	-- Check character validity
	if not Utility.IsCharacterValid(self.Character) then
		DebugLogger.ClientValidationFailed(actionType, "Invalid character")
		return false
	end
	
	-- Validate currentState type (debug protection)
	if type(self._currentState) ~= "string" then
		Logger:Error("_currentState is not a string!", {
			stateType = type(self._currentState),
			state = tostring(self._currentState),
			actionType = actionType
		})
		-- Force reset to Idle
		self._currentState = Enums.CombatState.Idle
	end
	
	-- Check state
	if self._currentState == Enums.CombatState.Stunned or self._currentState == Enums.CombatState.Dead then
		DebugLogger.ClientValidationFailed(actionType, string.format("Invalid state: %s", self._currentState))
		return false
	end
	
	-- Check if action is allowed in current state (using lookup table)
	local validStates = VALID_ACTION_STATES[actionType]
	if validStates and not validStates[self._currentState] then
		DebugLogger.ClientValidationFailed(actionType, string.format("Invalid state: %s", self._currentState))
		return false
	end
	
	-- Check cooldown
	local cooldownConfig = self:_GetCooldownForAction(actionType)
	if not Utility.IsCooldownReady(self._cooldowns[actionType], cooldownConfig) then
		local remaining = Utility.GetCooldownRemaining(self._cooldowns[actionType], cooldownConfig)
		DebugLogger.ClientValidationFailed(actionType, string.format("On cooldown: %.1fs", remaining))
		return false
	end
	
	return true
end

function CombatController:_GetCooldownForAction(actionType: string): number
	local cooldownGetter = COOLDOWN_CONFIGS[actionType]
	return cooldownGetter and cooldownGetter() or 0
end

-- ========================================
-- UPDATE LOOP
-- ========================================

function CombatController:_StartUpdateLoop()
	RunService.Heartbeat:Connect(function(deltaTime)
		self:_Update(deltaTime)
	end)
end

function CombatController:_Update(_deltaTime: number)
	if not self._enabled then
		return
	end
	
	-- Process buffered inputs
	self:_ProcessBufferedInputs()
	
	-- Update combo window
	self:_UpdateComboWindow()
end

function CombatController:_ProcessBufferedInputs()
	if not self._inputBuffering:HasBufferedInputs() then
		return
	end
	
	-- Try to execute buffered input
	if self._currentState == Enums.CombatState.Idle then
		local bufferedInput = self._inputBuffering:GetNextInput()
		if bufferedInput and bufferedInput.ActionType == Enums.ActionType.M1 then
			self:_HandleLightAttack()
		end
	end
end

function CombatController:_UpdateComboWindow()
	local timeSinceLastAttack = os.clock() - self._lastAttackTime
	if timeSinceLastAttack > Config.LightAttack.ComboWindow and self._comboCount > 0 then
		self._comboCount = 0
		Logger:Debug("Combo reset")
	end
end

-- ========================================
-- STATE MANAGEMENT
-- ========================================

function CombatController:_ResetState()
	-- Reset state using StateManager
	self._stateManager:SetState(Enums.CombatState.Idle, "reset")
	self._comboCount = 0
	self._lastAttackTime = 0
	
	-- Reset cooldowns
	for action in pairs(self._cooldowns) do
		self._cooldowns[action] = 0
	end
	
	-- Unblock inputs
	self._inputHandler:BlockAllInputs(false)
	
	-- Clear buffer
	self._inputBuffering:ClearBuffer()
	
	Logger:Debug("State reset")
end

-- ========================================
-- PUBLIC API
-- ========================================

function CombatController:GetCurrentState(): string
	return self._currentState
end

function CombatController:GetComboCount(): number
	return self._comboCount
end

function CombatController:IsEnabled(): boolean
	return self._enabled
end

function CombatController:SetEnabled(enabled: boolean)
	self._enabled = enabled
	self._inputHandler:BlockAllInputs(not enabled)
	
	Logger:Info("CombatController enabled state changed", {enabled = enabled})
end

-- ========================================
-- CLEANUP
-- ========================================

function CombatController:Destroy()
	self._enabled = false
	
	if self._inputHandler then
		self._inputHandler:Destroy()
	end
	
	if self._inputBuffering then
		self._inputBuffering:Destroy()
	end
	
	if self._stateManager then
		self._stateManager:Destroy()
	end
	
	if self._movementController then
		self._movementController:Destroy()
	end
	
	if self._visualEffects then
		self._visualEffects:Destroy()
	end
	
	if self._animationManager then
		self._animationManager:Destroy()
	end
	
	self.Character = nil
	self.Humanoid = nil
	self.HumanoidRootPart = nil
	
	Logger:Info("CombatController destroyed")
end

return CombatController
