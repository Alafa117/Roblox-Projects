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

local Config = require(CombatSystem.Config.Config)
local Enums = require(CombatSystem.Data.Enums)
local Logger = require(CombatSystem.Logging.Logger).GetInstance()

-- State Manager Class
local StateManager = {}
StateManager.__index = StateManager

-- Valid state transitions (from -> to)
local VALID_TRANSITIONS = {
	[Enums.CombatState.Idle] = {
		[Enums.CombatState.LightAttacking] = true,
		[Enums.CombatState.StrongAttacking] = true,
		[Enums.CombatState.Dashing] = true,
		[Enums.CombatState.Sliding] = true,
		[Enums.CombatState.Blocking] = true,
		[Enums.CombatState.Stunned] = true,
		[Enums.CombatState.Dead] = true,
	},
	-- Light Attack state transitions
	[Enums.CombatState.LightAttacking] = {
		[Enums.CombatState.LightAttacking] = true, -- M1 combo chains
		[Enums.CombatState.StrongAttacking] = true, -- M1 -> M2 combo
		[Enums.CombatState.Idle] = true,
		[Enums.CombatState.Stunned] = true,
		[Enums.CombatState.Dead] = true,
	},
	-- Strong Attack state transitions
	[Enums.CombatState.StrongAttacking] = {
		[Enums.CombatState.Idle] = true,
		[Enums.CombatState.Stunned] = true,
		[Enums.CombatState.Dead] = true,
	},
	[Enums.CombatState.Dashing] = {
		[Enums.CombatState.LightAttacking] = true, -- Cancel into M1
		[Enums.CombatState.StrongAttacking] = true, -- Cancel into M2
		[Enums.CombatState.Idle] = true,
		[Enums.CombatState.Stunned] = true,
		[Enums.CombatState.Dead] = true,
	},
	[Enums.CombatState.Sliding] = {
		[Enums.CombatState.LightAttacking] = true, -- Cancel into M1
		[Enums.CombatState.StrongAttacking] = true, -- Cancel into M2
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
	
	return self
end

-- ========================================
-- STATE HELPERS
-- ========================================

-- Helper to check if currently in any attacking state
-- Returns true if state is LightAttacking or StrongAttacking
function StateManager:IsAttacking(): boolean
	local state = self._controller._currentState
	return state == Enums.CombatState.LightAttacking 
		or state == Enums.CombatState.StrongAttacking
end

-- ========================================
-- STATE TRANSITIONS
-- ========================================

function StateManager:SetState(newState: string, _actionType: string?)
	local oldState = self._controller._currentState
	
	if not self:_IsValidTransition(oldState, newState) then return false end
	
	-- Cancel old state timers
	if oldState ~= newState and oldState ~= Enums.CombatState.Idle then
		for action, timer in pairs(self._activeStateTimers) do
			if self:_GetExpectedStateForAction(action) == oldState then
				pcall(task.cancel, timer)
				self._activeStateTimers[action] = nil
			end
		end
	end
	
	self._controller._currentState = newState
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
	if self._activeStateTimers[actionType] then
		pcall(task.cancel, self._activeStateTimers[actionType])
	end
	
	self._activeStateTimers[actionType] = task.delay(duration, function()
		if self._activeStateTimers[actionType] then
			self:_ResetStateIfMatches(actionType)
			self._activeStateTimers[actionType] = nil
		end
	end)
end

function StateManager:_ResetStateIfMatches(actionType: string)
	local current = self._controller._currentState
	local expected = self:_GetExpectedStateForAction(actionType)
	
	if current == expected and current ~= Enums.CombatState.Idle then
		if not self:SetState(Enums.CombatState.Idle, actionType) then
			self._controller._currentState = Enums.CombatState.Idle
		end
	end
end

function StateManager:_GetExpectedStateForAction(actionType: string): string
	if actionType == Enums.ActionType.M1 then
		return Enums.CombatState.LightAttacking
	elseif actionType == Enums.ActionType.M2 then
		return Enums.CombatState.StrongAttacking
	elseif actionType == Enums.ActionType.Q then
		return Enums.CombatState.Dashing
	elseif actionType == Enums.ActionType.C then
		return Enums.CombatState.Sliding
	elseif actionType == Enums.ActionType.F then
		return Enums.CombatState.Blocking
	end
	return Enums.CombatState.Idle
end

-- State configuration lookup
local STATE_CONFIG = {
	-- M1 state resets quickly (0.4s) to allow M2, but cooldown prevents another M1 combo
	[Enums.ActionType.M1] = {state = Enums.CombatState.LightAttacking, resetTime = function() return 0.4 end},
	-- M2 locks for full stun duration + buffer
	[Enums.ActionType.M2] = {state = Enums.CombatState.StrongAttacking, resetTime = function() return Config.StrongAttack.StunDuration + 0.3 end},
	[Enums.ActionType.Q] = {state = Enums.CombatState.Dashing, resetTime = function() return Config.Dash.Duration + 0.1 end},
	[Enums.ActionType.C] = {state = Enums.CombatState.Sliding, resetTime = function() return Config.Slide.Duration + 0.1 end},
	[Enums.ActionType.F] = {state = Enums.CombatState.Blocking},
}

-- ========================================
-- ACTION-SPECIFIC STATE MANAGEMENT
-- ========================================

function StateManager:HandleActionState(actionType: string, isEnd: boolean?)
	local config = STATE_CONFIG[actionType]
	if not config then return end
	
	if isEnd then
		self:SetState(Enums.CombatState.Idle, actionType)
	else
		self:SetState(config.state, actionType)
		if config.resetTime then
			self:ScheduleStateReset(actionType, config.resetTime())
		end
	end
end

-- Legacy compatibility wrappers
function StateManager:HandleLightAttackState()
	self:HandleActionState(Enums.ActionType.M1)
end

function StateManager:HandleStrongAttackState()
	self:HandleActionState(Enums.ActionType.M2)
end

function StateManager:HandleDashState()
	self:HandleActionState(Enums.ActionType.Q)
end

function StateManager:HandleSlideState()
	self:HandleActionState(Enums.ActionType.C)
end

function StateManager:HandleBlockStartState()
	self:HandleActionState(Enums.ActionType.F)
end

function StateManager:HandleBlockEndState()
	self:HandleActionState(Enums.ActionType.F, true)
end

-- ========================================
-- CLEANUP
-- ========================================

function StateManager:CancelAllTimers()
	for _, timer in pairs(self._activeStateTimers) do
		pcall(task.cancel, timer)
	end
	table.clear(self._activeStateTimers)
end

function StateManager:Destroy()
	self:CancelAllTimers()
	self._controller = nil
end

return StateManager
