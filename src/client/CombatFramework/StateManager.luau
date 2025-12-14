--[[
	Module: StateManager
	Type: Client State Management Module
	Location: StarterPlayer.StarterPlayerScripts.CombatFramework.StateManager
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

-- Valid state transitions (from -> to)
local VALID_TRANSITIONS = {
	[Enums.CombatState.Idle] = {
		[Enums.CombatState.Attacking] = true,
		[Enums.CombatState.Dashing] = true,
		[Enums.CombatState.Sliding] = true,
		[Enums.CombatState.Blocking] = true,
		[Enums.CombatState.Stunned] = true,
		[Enums.CombatState.Dead] = true,
	},
	[Enums.CombatState.Attacking] = {
		[Enums.CombatState.Attacking] = true, -- Combo chains
		[Enums.CombatState.Idle] = true,
		[Enums.CombatState.Stunned] = true,
		[Enums.CombatState.Dead] = true,
	},
	[Enums.CombatState.Dashing] = {
		[Enums.CombatState.Attacking] = true, -- Cancel into attack
		[Enums.CombatState.Idle] = true,
		[Enums.CombatState.Stunned] = true,
		[Enums.CombatState.Dead] = true,
	},
	[Enums.CombatState.Sliding] = {
		[Enums.CombatState.Attacking] = true, -- Cancel into attack
		[Enums.CombatState.Idle] = true,
		[Enums.CombatState.Stunned] = true,
		[Enums.CombatState.Dead] = true,
	},
	[Enums.CombatState.Blocking] = {
		[Enums.CombatState.Idle] = true,
		[Enums.CombatState.Stunned] = true,
		[Enums.CombatState.Dead] = true,
	},
	[Enums.CombatState.Stunned] = {
		[Enums.CombatState.Idle] = true,
		[Enums.CombatState.Dead] = true,
	},
	[Enums.CombatState.Dead] = {
		[Enums.CombatState.Idle] = true, -- Respawn
	},
}

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
	
	-- Validate transition
	if not self:_IsValidTransition(oldState, newState) then
		Logger:Warning("Invalid state transition blocked", {
			from = oldState,
			to = newState,
			action = actionType or "manual"
		})
		return false
	end
	
	-- Cancel timer for old state if transitioning away
	if oldState ~= newState and oldState ~= Enums.CombatState.Idle then
		-- Cancel any active timer for the old state
		for action, timer in pairs(self._activeStateTimers) do
			local expectedState = self:_GetExpectedStateForAction(action)
			if expectedState == oldState then
				local success = pcall(function()
					task.cancel(timer)
				end)
				if not success then
					Logger:Debug("Timer already completed", {action = action})
				end
				self._activeStateTimers[action] = nil
			end
		end
	end
	
	self._controller._currentState = newState
	
	Logger:Debug("State changed", {
		from = oldState,
		to = newState,
		action = actionType or "manual"
	})
	
	return true
end

function StateManager:_IsValidTransition(fromState: string, toState: string): boolean
	-- Allow same state (no transition)
	if fromState == toState then
		return true
	end
	
	-- Check transition table
	local validDestinations = VALID_TRANSITIONS[fromState]
	if not validDestinations then
		Logger:Warning("Unknown source state", {state = fromState})
		return false
	end
	
	return validDestinations[toState] == true
end

-- ========================================
-- AUTO STATE RESET
-- ========================================

function StateManager:ScheduleStateReset(actionType: string, duration: number)
	-- Cancel any existing timer for this action to prevent double resets
	if self._activeStateTimers[actionType] then
		local success = pcall(function()
			task.cancel(self._activeStateTimers[actionType])
		end)
		if not success then
			Logger:Debug("Timer already completed", {action = actionType})
		end
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
		local success = self:SetState(Enums.CombatState.Idle, actionType)
		
		-- If SetState failed validation, force reset (duration expired = must reset)
		if not success then
			Logger:Warning("Forced state reset after duration", {
				from = currentState,
				action = actionType
			})
			self._controller._currentState = Enums.CombatState.Idle
		end
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
	
	-- Reset after combo window expires (allow full combo timing)
	-- Use ComboWindow instead of Cooldown to prevent premature state reset during combos
	local resetTime = Config.LightAttack.ComboWindow + 0.1 -- ComboWindow + small buffer
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
