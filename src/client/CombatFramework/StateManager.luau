--[[
	Module: StateManager
	Type: Client State Management Module
	Location: StarterPlayer.StarterPlayerScripts.CombatController.StateManager
	Path: src/client/CombatFramework/StateManager.luau
	
	Description:
		Manages combat state transitions and automatic state resets.
		Centralizes state logic to avoid code duplication and ensure consistent behavior.
		Uses Config values for accurate timing based on combat mechanics.
	
	Author: Professional Roblox Scripter
	Created: December 11, 2025
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Module Imports
local RS = ReplicatedStorage
local CombatSystem = RS:WaitForChild("CombatCore")
local Core = CombatSystem:WaitForChild("Core")

local Config = require(Core.Config)
local Enums = require(Core.Enums)
local Logger = require(Core.Logger).GetInstance()

-- State Manager Class
local StateManager = {}
StateManager.__index = StateManager

-- ========================================
-- CONSTRUCTOR
-- ========================================

function StateManager.new(controller)
	local self = setmetatable({}, StateManager)
	
	self._controller = controller
	self._activeStateTimers = {} -- Track active timers by action type
	
	Logger:Debug("StateManager initialized")
	
	return self
end

-- ========================================
-- STATE TRANSITIONS
-- ========================================

function StateManager:SetState(newState: string, actionType: string?)
	local oldState = self._controller._currentState
	self._controller._currentState = newState
	
	Logger:Debug("State changed", {
		from = oldState,
		to = newState,
		action = actionType or "manual"
	})
end

-- ========================================
-- AUTO STATE RESET
-- ========================================

function StateManager:ScheduleStateReset(actionType: string, duration: number)
	-- Cancel any existing timer for this action to prevent double resets
	if self._activeStateTimers[actionType] then
		task.cancel(self._activeStateTimers[actionType])
		self._activeStateTimers[actionType] = nil
	end
	
	-- Schedule new reset
	self._activeStateTimers[actionType] = task.delay(duration, function()
		-- Check if timer wasn't cancelled
		if self._activeStateTimers[actionType] then
			self:_ResetStateIfMatches(actionType)
			self._activeStateTimers[actionType] = nil
		end
	end)
end

function StateManager:_ResetStateIfMatches(actionType: string)
	local currentState = self._controller._currentState
	local expectedState = self:_GetExpectedStateForAction(actionType)
	
	-- Only reset if we're still in the expected state and not already Idle
	if currentState == expectedState and currentState ~= Enums.CombatState.Idle then
		self:SetState(Enums.CombatState.Idle, actionType)
	end
end

function StateManager:_GetExpectedStateForAction(actionType: string): string
	if actionType == Enums.ActionType.M1 or actionType == Enums.ActionType.M2 then
		return Enums.CombatState.Attacking
	elseif actionType == Enums.ActionType.Q then
		return Enums.CombatState.Dashing
	elseif actionType == Enums.ActionType.C then
		return Enums.CombatState.Sliding
	elseif actionType == Enums.ActionType.F then
		return Enums.CombatState.Blocking
	end
	return Enums.CombatState.Idle
end

-- ========================================
-- ACTION-SPECIFIC STATE MANAGEMENT
-- ========================================

function StateManager:HandleLightAttackState()
	self:SetState(Enums.CombatState.Attacking, Enums.ActionType.M1)
	
	-- Reset after animation duration (use Config cooldown as reference)
	local resetTime = Config.LightAttack.Cooldown * 0.8 -- 80% of cooldown
	self:ScheduleStateReset(Enums.ActionType.M1, resetTime)
end

function StateManager:HandleStrongAttackState()
	self:SetState(Enums.CombatState.Attacking, Enums.ActionType.M2)
	
	-- Reset after animation duration
	local resetTime = Config.StrongAttack.StunDuration + 0.3 -- Stun + buffer
	self:ScheduleStateReset(Enums.ActionType.M2, resetTime)
end

function StateManager:HandleDashState()
	self:SetState(Enums.CombatState.Dashing, Enums.ActionType.Q)
	
	-- Reset after dash completes
	local resetTime = Config.Dash.Duration + 0.1
	self:ScheduleStateReset(Enums.ActionType.Q, resetTime)
end

function StateManager:HandleSlideState()
	self:SetState(Enums.CombatState.Sliding, Enums.ActionType.C)
	
	-- Reset after slide completes
	local resetTime = Config.Slide.Duration + 0.1
	self:ScheduleStateReset(Enums.ActionType.C, resetTime)
end

function StateManager:HandleBlockStartState()
	self:SetState(Enums.CombatState.Blocking, Enums.ActionType.F)
end

function StateManager:HandleBlockEndState()
	self:SetState(Enums.CombatState.Idle, Enums.ActionType.F)
end

-- ========================================
-- CLEANUP
-- ========================================

function StateManager:CancelAllTimers()
	for _actionType, timer in pairs(self._activeStateTimers) do
		task.cancel(timer)
	end
	self._activeStateTimers = {}
	Logger:Debug("All state timers cancelled")
end

function StateManager:Destroy()
	self:CancelAllTimers()
	self._controller = nil
end

return StateManager
