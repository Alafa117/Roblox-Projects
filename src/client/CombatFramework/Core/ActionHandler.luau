--[[
	Module: ActionHandler
	Type: Client Action Handler
	Location: StarterPlayer.StarterPlayerScripts.CombatFramework.Core.ActionHandler
	Path: src/client/CombatFramework/Core/ActionHandler.luau
	
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
		- State/ (StateManager, CooldownManager, ComboManager)
		- Animation/ (AnimationController)
		- Movement/ (MovementController)
		- VisualEffectsController, NetworkManager
		- Config, Enums, Logger, DebugLogger
	
	Author: Professional Roblox Scripter
	Created: December 13, 2025
--]]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Module Imports
local CombatSystem = ReplicatedStorage:WaitForChild("CombatCore")

local Config = require(CombatSystem.Config.Config)
local Enums = require(CombatSystem.Data.Enums)
local Logger = require(CombatSystem.Logging.Logger).GetInstance()

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
	-- FIXED: Check cooldown BEFORE anything else (December 30, 2025)
	-- Don't execute, buffer, or animate when M1 is on cooldown (after finisher)
	-- This prevents animation desync and unnecessary input spam
	local isOnCooldown = self._cooldownManager:GetRemaining(Enums.ActionType.M1) > 0
	if isOnCooldown then
		Logger:ClientValidationFailed("M1", "On cooldown")
		return
	end
	
	-- Check if can attack
	if not self._combatController:CanPerformAction(Enums.ActionType.M1) then
		-- Only buffer if state is invalid (not cooldown, we already checked that)
		self._inputBuffering:AddInput(Enums.ActionType.M1)
		return
	end
	
	-- Cancel movement if active (consolidated logic)
	local _, cancelledMovement = self:_CancelActiveMovement()
	
	-- Get current combo without incrementing (server will handle increment)
	local currentComboCount = self._comboManager:GetCurrentCombo()
	
	-- Send to server and wait for response BEFORE playing animation
	-- FIXED: Wait for server confirmation before playing animation (December 30, 2025)
	-- This prevents animations from playing when action is rejected (e.g., during M2)
	Logger:ClientAction("M1 Request", string.format("CurrentCombo: %d, CancelledMovement: %s", currentComboCount, tostring(cancelledMovement)))
	local result = self._networkManager:InvokeServer(Enums.NetworkEvent.RequestAction, {
		ActionType = Enums.ActionType.M1,
		ComboCount = currentComboCount,
		CancelledMovement = cancelledMovement,
	})
	
	-- Handle server response
	if result and result.Success then
		-- Server accepted: Update state, play animation, apply cooldown
		self._stateManager:HandleLightAttackState()
		
		if result.ComboCount then
			-- Sync combo with server
			self._comboManager:SetCombo(result.ComboCount)
			
			-- Play animation based on server's combo count
			self._animationController:PlayLightAttack(result.ComboCount)
			
			-- Apply cooldown based on server's combo count
			if result.ComboCount == 6 then
				self._cooldownManager:StartWithDuration(Enums.ActionType.M1, 3.0)
				Logger:ClientAction("M1 Finisher", "Applied 3s cooldown")
			else
				self._cooldownManager:Start(Enums.ActionType.M1)
			end
		end
	elseif result and result.ServerComboCount ~= nil then
		-- Server rejected: Sync combo to server's state, NO animation or state change
		self._comboManager:SetCombo(result.ServerComboCount)
		Logger:ClientValidationFailed("M1", string.format("Rejected by server, synced combo to %d", result.ServerComboCount))
	end
end

-- Handle M2 strong attack
function ActionHandler:HandleStrongAttack()
	Logger:ClientAction("_HandleStrongAttack", "Called")
	
	-- FIXED: Check cooldown BEFORE attempting action (December 30, 2025)
	-- Don't buffer or attempt M2 when on cooldown (3s after execution)
	local isOnCooldown = self._cooldownManager:GetRemaining(Enums.ActionType.M2) > 0
	if isOnCooldown then
		Logger:ClientValidationFailed("M2", "On cooldown")
		return
	end
	
	-- Check if can attack
	if not self._combatController:CanPerformAction(Enums.ActionType.M2) then
		Logger:ClientValidationFailed("M2", "Cannot perform action")
		return
	end
	
	-- Cancel movement if active (consolidated logic)
	local _, cancelledMovement = self:_CancelActiveMovement()
	
	-- Send to server and wait for response BEFORE playing animation
	-- FIXED: Wait for server confirmation before playing animation (December 30, 2025)
	-- This prevents animations from playing when action is rejected (e.g., during M1)
	Logger:ClientAction("M2 Request", string.format("Instant attack, CancelledMovement: %s", tostring(cancelledMovement)))
	local result = self._networkManager:InvokeServer(Enums.NetworkEvent.RequestAction, {
		ActionType = Enums.ActionType.M2,
		CancelledMovement = cancelledMovement,
	})
	
	-- Handle server response
	if result and result.Success then
		-- Server accepted: Update state, play animation, apply cooldown
		self._stateManager:HandleStrongAttackState()
		
		-- Start cooldown IMMEDIATELY
		-- M2 cooldown = animation (0.8s) + actual cooldown (3.0s) = 3.8s total
		self._cooldownManager:Start(Enums.ActionType.M2)
		
		-- Reset combo
		self._comboManager:ResetCombo()
		
		-- Play animation
		self._animationController:PlayStrongAttack()
		
		-- NOTE: Outline applied by server via PlayAnimation event callback
	else
		-- Server rejected: NO animation, state change, or cooldown
		Logger:ClientValidationFailed("M2", "Rejected by server")
	end
end

-- Handle Q dash
function ActionHandler:HandleDash(direction: string)
	Logger:ClientAction("_HandleDash", string.format("Direction: %s", direction))
	
	-- Check if can dash
	if not self._combatController:CanPerformAction(Enums.ActionType.Q) then
		Logger:ClientValidationFailed("Dash", "Cannot perform action")
		return
	end
	
	-- Send to server and wait for response BEFORE executing
	-- FIXED: Wait for server confirmation before executing (December 31, 2025)
	-- This prevents Dash from executing during M1/M2
	local result = self._networkManager:InvokeServer(Enums.NetworkEvent.RequestDash, {
		Direction = direction,
	})
	
	-- Handle server response
	if result and result.Success then
		-- Server accepted: Update state, play animation, start movement
		self._stateManager:HandleDashState()
		
		-- Play animation
		self._animationController:PlayDash(direction)
		
		-- Start client-side dynamic movement
		self._movementController:StartDynamicMovement("Dash", {
			Speed = Config.Dash.Speed,
			Duration = Config.Dash.Duration,
			FrictionMultiplier = Config.Dash.FrictionMultiplier,
		})
		
		-- Apply cooldown AFTER dash completes
		local dashDuration = 0.45
		task.delay(dashDuration, function()
			self._cooldownManager:Start(Enums.ActionType.Q)
		end)
	else
		-- Server rejected: NO animation, state change, or movement
		Logger:ClientValidationFailed("Dash", "Rejected by server")
	end
end

-- Handle C slide
function ActionHandler:HandleSlide(direction: string)
	Logger:ClientAction("_HandleSlide", string.format("Direction: %s", direction))
	
	-- Check if can slide
	if not self._combatController:CanPerformAction(Enums.ActionType.C) then
		Logger:ClientValidationFailed("Slide", "Cannot perform action")
		return
	end
	
	-- Send to server and wait for response BEFORE executing
	-- FIXED: Wait for server confirmation before executing (December 31, 2025)
	-- This prevents Slide from executing during M1/M2
	Logger:ClientAction("Slide Request", "Sent to server")
	local result = self._networkManager:InvokeServer(Enums.NetworkEvent.RequestSlide, {
		Direction = direction,
	})
	
	-- Handle server response
	if result and result.Success then
		-- Server accepted: Update state, play animation, start movement
		self._stateManager:HandleSlideState()
		
		-- Play animation
		self._animationController:PlaySlide()
		
		-- Start client-side dynamic movement
		self._movementController:StartDynamicMovement("Slide", {
			Speed = Config.Slide.Speed,
			Duration = Config.Slide.Duration,
			FrictionMultiplier = Config.Slide.FrictionMultiplier,
		})
		
		-- Apply cooldown AFTER slide completes
		local slideDuration = 0.4
		task.delay(slideDuration, function()
			self._cooldownManager:Start(Enums.ActionType.C)
		end)
	else
		-- Server rejected: NO animation, state change, or movement
		Logger:ClientValidationFailed("Slide", "Rejected by server")
	end
end

-- Handle F block start
function ActionHandler:HandleBlockStart()
	-- Check if can block
	if not self._combatController:CanPerformAction(Enums.ActionType.F) then
		return
	end
	
	-- Update state using StateManager
	self._stateManager:HandleBlockStartState()
	
	-- FIXED: Don't start cooldown here (December 27, 2025)
	-- Cooldown should apply when RELEASING block (at end), not at start
	-- This is consistent with other actions (M2, Dash, Slide)
	
	-- Send to server
	self._networkManager:SendToServer(Enums.NetworkEvent.RequestBlock, {
		IsBlocking = true,
	})
end

-- Handle F block end
function ActionHandler:HandleBlockEnd()
	-- CRITICAL: Always allow block deactivation (December 26, 2025)
	-- Block end should NEVER be blocked by cooldown
	-- Cooldown only applies to RE-ACTIVATING the block, not releasing it
	
	-- Update state using StateManager
	self._stateManager:HandleBlockEndState()
	
	-- FIXED: NO cooldown for Block (December 27, 2025)
	-- Block is defensive mechanic that must be available immediately
	-- User needs to activate it right after actions finish
	
	-- Send to server
	self._networkManager:SendToServer(Enums.NetworkEvent.RequestBlock, {
		IsBlocking = false,
	})
end

return ActionHandler
