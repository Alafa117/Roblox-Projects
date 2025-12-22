--[[
	Module: ActionHandler
	Type: Client Action Handler
	Location: ReplicatedFirst.CombatFramework.ActionHandler
	Path: src/client/CombatFramework/ActionHandler.luau
	
	Description:
		Handles all combat action execution on the client.
		Processes light attacks (M1), strong attacks (M2), dash (Q), slide (C), and block (F).
		Coordinates between state management, animations, cooldowns, and network synchronization.
	
	Features:
		- M1 combo system with intelligent cooldown logic
		- M2 instant attack with visual effects
		- Dash/Slide movement with cancellation on attacks
		- Block start/end with animation support
		- Network synchronization for all actions
	
	Dependencies:
		- StateManager, CooldownManager, AnimationController, MovementController
		- VisualEffectsController, NetworkManager
		- Config, Enums, Logger, DebugLogger
	
	Author: Professional Roblox Scripter
	Created: December 13, 2025
--]]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Module Imports
local CombatSystem = ReplicatedStorage:WaitForChild("CombatCore")
local Core = CombatSystem:WaitForChild("Core")

local Config = require(Core.Config)
local Enums = require(Core.Enums)
local Logger = require(Core.Logger).GetInstance()

-- ========================================
-- ACTION HANDLER CLASS
-- ========================================

local ActionHandler = {}
ActionHandler.__index = ActionHandler

-- ========================================
-- TYPES
-- ========================================

export type ActionHandler = {
	_stateManager: any,
	_cooldownManager: any,
	_animationController: any,
	_movementController: any,
	_visualEffects: any,
	_networkManager: any,
	_inputBuffering: any,
	_comboManager: any,
	_combatController: any, -- Reference for validation only
	
	HandleLightAttack: (self: ActionHandler) -> (),
	HandleStrongAttack: (self: ActionHandler) -> (),
	HandleDash: (self: ActionHandler, direction: string) -> (),
	HandleSlide: (self: ActionHandler, direction: string) -> (),
	HandleBlockStart: (self: ActionHandler) -> (),
	HandleBlockEnd: (self: ActionHandler) -> (),
}

-- ========================================
-- CONSTRUCTOR
-- ========================================

function ActionHandler.new(combatController: any): ActionHandler
	local self = setmetatable({}, ActionHandler)
	
	-- Store reference to parent controller (for validation only)
	self._combatController = combatController
	
	-- Store references to needed managers (will be set after construction)
	self._stateManager = nil
	self._cooldownManager = nil
	self._animationController = nil
	self._movementController = nil
	self._visualEffects = nil
	self._networkManager = nil
	self._inputBuffering = nil
	self._comboManager = nil
	
	return self
end

-- ========================================
-- INITIALIZATION
-- ========================================

-- Set references to all needed managers
function ActionHandler:Initialize(managers: {
	stateManager: any,
	cooldownManager: any,
	animationController: any,
	movementController: any,
	visualEffects: any,
	networkManager: any,
	inputBuffering: any,
	comboManager: any,
})
	self._stateManager = managers.stateManager
	self._cooldownManager = managers.cooldownManager
	self._animationController = managers.animationController
	self._movementController = managers.movementController
	self._visualEffects = managers.visualEffects
	self._networkManager = managers.networkManager
	self._inputBuffering = managers.inputBuffering
	self._comboManager = managers.comboManager
end

-- ========================================
-- HELPER METHODS
-- ========================================

-- Cancel active movement (Dash/Slide) if any
-- Returns: (wasCancelled, shouldNotifyServer)
function ActionHandler:_CancelActiveMovement(): (boolean, boolean)
	local currentState = self._combatController:GetCurrentState()
	local isMoving = self._movementController:IsMoving()
	local wasDashing = currentState == Enums.CombatState.Dashing
	local wasSliding = currentState == Enums.CombatState.Sliding
	
	-- Calculate if movement was cancelled
	local cancelledMovement = wasDashing or wasSliding or isMoving
	
	-- Early exit if no movement
	if not cancelledMovement then
		return false, false
	end
	
	-- Always stop the MovementController if it's active
	if isMoving then
		self._movementController:StopMovement()
		Logger:ClientAction("Movement", "Stopped MovementController")
	end
	
	-- Send cancellation events based on state
	if wasDashing then
		Logger:ClientAction("Movement", "Cancelled Dash")
		self._networkManager:SendToServer(Enums.NetworkEvent.CancelDash, {})
	elseif wasSliding then
		Logger:ClientAction("Movement", "Cancelled Slide")
		self._networkManager:SendToServer(Enums.NetworkEvent.CancelSlide, {})
	end
	
	return true, cancelledMovement
end

-- ========================================
-- ACTION HANDLERS
-- ========================================

-- Handle M1 light attack with combo system
function ActionHandler:HandleLightAttack()
	-- Check if can attack
	if not self._combatController:CanPerformAction(Enums.ActionType.M1) then
		self._inputBuffering:AddInput(Enums.ActionType.M1)
		return
	end
	
	-- Cancel movement if active (consolidated logic)
	local _, cancelledMovement = self:_CancelActiveMovement()
	
	-- Update combo using ComboManager (returns count and window status)
	local comboCount, wasInWindow = self._comboManager:UpdateCombo()
	
	-- Update state
	self._stateManager:HandleLightAttackState()
	
	-- Cooldown logic: ComboManager determines if cooldown should apply
	if self._comboManager:ShouldApplyCooldown(comboCount, wasInWindow) then
		self._cooldownManager:Start(Enums.ActionType.M1)
	else
		self._cooldownManager:Clear(Enums.ActionType.M1)
	end
	
	-- Play animation locally (prediction)
	self._animationController:PlayLightAttack(comboCount)
	
	-- Send to server
	Logger:ClientAction("M1 Request", string.format("Combo: %d, CancelledMovement: %s", comboCount, tostring(cancelledMovement)))
	self._networkManager:SendToServer(Enums.NetworkEvent.RequestAction, {
		ActionType = Enums.ActionType.M1,
		ComboCount = comboCount,
		CancelledMovement = cancelledMovement,
	})
end

-- Handle M2 strong attack
function ActionHandler:HandleStrongAttack()
	Logger:ClientAction("_HandleStrongAttack", "Called")
	
	-- Check if can attack
	if not self._combatController:CanPerformAction(Enums.ActionType.M2) then
		Logger:ClientValidationFailed("M2", "Cannot perform action")
		return
	end
	
	-- Cancel movement if active (consolidated logic)
	local _, cancelledMovement = self:_CancelActiveMovement()
	
	-- Update state
	self._stateManager:HandleStrongAttackState()
	
	-- Cooldown activates IMMEDIATELY
	self._cooldownManager:Start(Enums.ActionType.M2)
	
	-- Reset combo
	self._comboManager:ResetCombo()
	
	-- Apply M2 visual effect
	self._visualEffects:ApplyStrongAttackEffect()
	
	-- Play animation locally
	self._animationController:PlayStrongAttack()
	
	-- Send to server
	Logger:ClientAction("M2 Request", string.format("Instant attack, CancelledMovement: %s", tostring(cancelledMovement)))
	self._networkManager:SendToServer(Enums.NetworkEvent.RequestAction, {
		ActionType = Enums.ActionType.M2,
		CancelledMovement = cancelledMovement,
	})
end

-- Handle Q dash
function ActionHandler:HandleDash(direction: string)
	Logger:ClientAction("_HandleDash", string.format("Direction: %s", direction))
	
	-- Check if can dash
	if not self._combatController:CanPerformAction(Enums.ActionType.Q) then
		Logger:ClientValidationFailed("Dash", "Cannot perform action")
		return
	end
	
	-- Update state using StateManager
	self._stateManager:HandleDashState()
	self._cooldownManager:Start(Enums.ActionType.Q)
	
	-- Play animation locally
	self._animationController:PlayDash(direction)
	
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
end

-- Handle C slide
function ActionHandler:HandleSlide(direction: string)
	Logger:ClientAction("_HandleSlide", string.format("Direction: %s", direction))
	
	-- Check if can slide
	if not self._combatController:CanPerformAction(Enums.ActionType.C) then
		Logger:ClientValidationFailed("Slide", "Cannot perform action")
		return
	end
	
	-- Update state using StateManager
	self._stateManager:HandleSlideState()
	self._cooldownManager:Start(Enums.ActionType.C)
	
	-- Play animation locally
	self._animationController:PlaySlide()
	
	-- Send to server (for validation/authority)
	Logger:ClientAction("Slide Request", "Sent to server")
	self._networkManager:SendToServer(Enums.NetworkEvent.RequestSlide, {
		Direction = direction,
	})
	
	-- Start client-side dynamic movement
	self._movementController:StartDynamicMovement("Slide", {
		Speed = Config.Slide.Speed,
		Duration = Config.Slide.Duration,
		FrictionMultiplier = Config.Slide.FrictionMultiplier,
	})
end

-- Handle F block start
function ActionHandler:HandleBlockStart()
	-- Check if can block
	if not self._combatController:CanPerformAction(Enums.ActionType.F) then
		return
	end
	
	-- Update state using StateManager
	self._stateManager:HandleBlockStartState()
	
	-- Send to server
	self._networkManager:SendToServer(Enums.NetworkEvent.RequestBlock, {
		IsBlocking = true,
	})
end

-- Handle F block end
function ActionHandler:HandleBlockEnd()
	-- Update state using StateManager
	self._stateManager:HandleBlockEndState()
	self._cooldownManager:Start(Enums.ActionType.F)
	
	-- Send to server
	self._networkManager:SendToServer(Enums.NetworkEvent.RequestBlock, {
		IsBlocking = false,
	})
end

return ActionHandler
