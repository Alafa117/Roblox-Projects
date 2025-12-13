--[[
	Module: InputHandler
	Type: Client Controller Module
	Location: StarterPlayer.StarterPlayerScripts.CombatController.InputHandler
	Path: src/client/CombatFramework/InputHandler.luau
	
	Description:
		Handles all player input for the Combat System.
		Detects M1 (Light Attack), M2 (Strong Attack), Q (Dash), C (Slide), F (Block).
		Uses UserInputService for keyboard/mouse and ContextActionService for mobile compatibility.
		Implements input buffering and state-aware input blocking.
	
	Dependencies:
		- ReplicatedStorage.CombatCore.Core.Enums
		- ReplicatedStorage.CombatCore.Core.Logger
	
	Author: Professional Roblox Scripter
	Created: December 9, 2025
--]]

-- Services
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Module Imports
local RS = ReplicatedStorage
local CombatSystem = RS:WaitForChild("CombatCore")
local Core = CombatSystem:WaitForChild("Core")

local Enums = require(Core.Enums)
local Logger = require(Core.Logger).GetInstance()

-- Constants
local INPUT_DEBOUNCE_TIME = 0.1 -- 100ms debounce to prevent duplicate inputs

-- Input Handler Class
local InputHandler = {}
InputHandler.__index = InputHandler

-- ========================================
-- TYPES
-- ========================================

type InputCallback = (actionType: string, inputState: Enum.UserInputState, inputObject: InputObject?) -> ()

type InputHandler = {
	_enabled: boolean,
	_callbacks: {[string]: {InputCallback}},
	_inputStates: {[string]: boolean},
	_blockedInputs: {[string]: boolean},
	_lastInputTime: {[string]: number}, -- For debouncing
}

-- ========================================
-- CONSTRUCTOR
-- ========================================

function InputHandler.new(): InputHandler
	local self = setmetatable({}, InputHandler)
	
	self._enabled = false
	self._callbacks = {}
	self._inputStates = {}
	self._blockedInputs = {}
	self._lastInputTime = {} -- Debounce tracking
	
	-- Initialize callback tables for each action
	for _, actionType in pairs(Enums.ActionType) do
		self._callbacks[actionType] = {}
		self._inputStates[actionType] = false
		self._blockedInputs[actionType] = false
		self._lastInputTime[actionType] = 0
	end
	
	Logger:Debug("InputHandler initialized")
	
	return self
end

-- ========================================
-- INPUT BINDING
-- ========================================

function InputHandler:Initialize()
	if self._enabled then
		Logger:Warning("InputHandler already initialized")
		return
	end
	
	self._enabled = true
	
	-- Bind M1 (Light Attack) - Mouse Button 1
	self:_BindAction(
		"CombatM1",
		Enum.KeyCode.ButtonR2, -- For controllers
		function(_actionName, inputState, inputObject)
			self:_HandleM1Input(inputState, inputObject)
		end
	)
	
	-- Bind mouse buttons (M1 and M2) in a single listener to avoid duplication
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			self:_HandleM1Input(Enum.UserInputState.Begin, input)
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			self:_HandleM2Input(Enum.UserInputState.Begin, input)
		end
	end)
	
	-- Bind Q (Dash)
	self:_BindAction(
		"CombatDash",
		Enum.KeyCode.Q,
		function(_actionName, inputState, inputObject)
			if inputState == Enum.UserInputState.Begin then
				self:_TriggerAction(Enums.ActionType.Q, inputState, inputObject)
			end
		end
	)
	
	-- Bind C (Slide)
	self:_BindAction(
		"CombatSlide",
		Enum.KeyCode.C,
		function(_actionName, inputState, inputObject)
			if inputState == Enum.UserInputState.Begin then
				self:_TriggerAction(Enums.ActionType.C, inputState, inputObject)
			end
		end
	)
	
	-- Bind F (Block) - Hold to block
	self:_BindAction(
		"CombatBlock",
		Enum.KeyCode.F,
		function(_actionName, inputState, inputObject)
			self:_HandleBlockInput(inputState, inputObject)
		end
	)
	
	-- Mobile touch support for M1
	if UserInputService.TouchEnabled then
		UserInputService.TouchTap:Connect(function(_touchPositions, gameProcessed)
			if gameProcessed then return end
			self:_HandleM1Input(Enum.UserInputState.Begin, nil)
		end)
	end
	
	Logger:Info("InputHandler bindings initialized")
end

-- ========================================
-- PRIVATE: ACTION BINDING
-- ========================================

function InputHandler:_BindAction(actionName: string, keyCode: Enum.KeyCode, callback: (string, Enum.UserInputState, InputObject?) -> ())
	ContextActionService:BindAction(
		actionName,
		callback,
		false, -- Don't create mobile button
		keyCode
	)
	
	ContextActionService:SetPosition(actionName, UDim2.new(0, 0, 0, 0))
end

-- ========================================
-- INPUT HANDLERS
-- ========================================

function InputHandler:_HandleM1Input(inputState: Enum.UserInputState, inputObject: InputObject?)
	if inputState == Enum.UserInputState.Begin then
		self:_TriggerAction(Enums.ActionType.M1, inputState, inputObject)
	end
end

function InputHandler:_HandleM2Input(inputState: Enum.UserInputState, inputObject: InputObject?)
	if inputState == Enum.UserInputState.Begin then
		self:_TriggerAction(Enums.ActionType.M2, inputState, inputObject)
	end
end

function InputHandler:_HandleBlockInput(inputState: Enum.UserInputState, inputObject: InputObject?)
	if inputState == Enum.UserInputState.Begin then
		self._inputStates[Enums.ActionType.F] = true
		self:_TriggerAction(Enums.ActionType.F, Enum.UserInputState.Begin, inputObject)
		
	elseif inputState == Enum.UserInputState.End then
		self._inputStates[Enums.ActionType.F] = false
		self:_TriggerAction(Enums.ActionType.F, Enum.UserInputState.End, inputObject)
	end
end

-- ========================================
-- ACTION TRIGGERING
-- ========================================

function InputHandler:_TriggerAction(actionType: string, inputState: Enum.UserInputState, inputObject: InputObject?)
	if not self._enabled then
		return
	end
	
	-- Debouncing: ignore duplicate inputs within 100ms
	local now = os.clock()
	local lastTime = self._lastInputTime[actionType] or 0
	if now - lastTime < INPUT_DEBOUNCE_TIME then
		-- Silently ignore duplicate input
		return
	end
	self._lastInputTime[actionType] = now
	
	-- Check if input is blocked
	if self._blockedInputs[actionType] then
		Logger:Debug("Input blocked", {action = actionType})
		return
	end
	
	-- Update input state
	self._inputStates[actionType] = (inputState == Enum.UserInputState.Begin)
	
	-- Get movement direction for directional abilities
	local movementDirection = self:_GetMovementDirection()
	
	-- Trigger all registered callbacks
	local callbacks = self._callbacks[actionType]
	if callbacks then
		for _, callback in ipairs(callbacks) do
			task.spawn(function()
				callback(actionType, inputState, inputObject, movementDirection)
			end)
		end
	end
	
	Logger:Debug("Input triggered", {
		action = actionType,
		state = tostring(inputState),
		direction = movementDirection
	})
end

-- ========================================
-- MOVEMENT DIRECTION DETECTION
-- ========================================

function InputHandler:_GetMovementDirection(): string
	-- Check WASD keys for directional input
	local moveForward = UserInputService:IsKeyDown(Enum.KeyCode.W)
	local moveBackward = UserInputService:IsKeyDown(Enum.KeyCode.S)
	local moveLeft = UserInputService:IsKeyDown(Enum.KeyCode.A)
	local moveRight = UserInputService:IsKeyDown(Enum.KeyCode.D)
	
	-- Priority: Forward > Backward > Left > Right
	if moveForward then
		return Enums.Direction.Forward
	elseif moveBackward then
		return Enums.Direction.Backward
	elseif moveLeft then
		return Enums.Direction.Left
	elseif moveRight then
		return Enums.Direction.Right
	end
	
	return Enums.Direction.Forward -- Default
end

-- ========================================
-- CALLBACK REGISTRATION
-- ========================================

function InputHandler:RegisterCallback(actionType: string, callback: InputCallback)
	if not self._callbacks[actionType] then
		Logger:Warning("Invalid action type", {action = actionType})
		return
	end
	
	table.insert(self._callbacks[actionType], callback)
	Logger:Debug("Callback registered", {action = actionType})
end

-- ========================================
-- INPUT BLOCKING
-- ========================================

function InputHandler:BlockAllInputs(blocked: boolean)
	for actionType in pairs(self._blockedInputs) do
		self._blockedInputs[actionType] = blocked
	end
	
	Logger:Info("All inputs blocked", {blocked = blocked})
end

-- ========================================
-- CLEANUP
-- ========================================

function InputHandler:Destroy()
	self._enabled = false
	
	-- Unbind all actions
	ContextActionService:UnbindAction("CombatM1")
	ContextActionService:UnbindAction("CombatDash")
	ContextActionService:UnbindAction("CombatSlide")
	ContextActionService:UnbindAction("CombatBlock")
	
	-- Clear callbacks
	table.clear(self._callbacks)
	table.clear(self._inputStates)
	table.clear(self._blockedInputs)
	
	Logger:Info("InputHandler destroyed")
end

return InputHandler
