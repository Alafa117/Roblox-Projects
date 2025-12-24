--[[
	Module: InputHandler
	Type: Client Input Module
	Location: StarterPlayer.StarterPlayerScripts.CombatFramework.Input.InputHandler
	Path: src/client/CombatFramework/Input/InputHandler.luau
	
	Description:
		Handles all player input for the Combat System.
		Detects M1 (Light Attack), M2 (Strong Attack), Q (Dash), C (Slide), F (Block).
		Uses UserInputService for keyboard/mouse and ContextActionService for mobile compatibility.
		Implements input buffering and state-aware input blocking.
	
	Dependencies:
		- ReplicatedStorage.CombatCore.Core (Enums, Logger)
		- Input.InputBuffering (for buffering system)
	
	Author: Professional Roblox Scripter
	Created: December 9, 2025
	Updated: December 23, 2025 - Moved to Input/ subfolder
--]]

-- Services
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Module Imports
local RS = ReplicatedStorage
local CombatSystem = RS:WaitForChild("CombatCore")

local Enums = require(CombatSystem.Data.Enums)
local Logger = require(CombatSystem.Logging.Logger).GetInstance()

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
	_connections: {RBXScriptConnection},
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
	self._connections = {} -- Track connections for cleanup
	
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
	if self._enabled then return end
	self._enabled = true
	
	-- Mouse/Controller M1/M2
	local inputBeganConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			self:_TriggerAction(Enums.ActionType.M1, Enum.UserInputState.Begin, input)
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			self:_TriggerAction(Enums.ActionType.M2, Enum.UserInputState.Begin, input)
		end
	end)
	table.insert(self._connections, inputBeganConnection)
	
	-- Keyboard bindings
	self:_BindAction("CombatM1", Enum.KeyCode.ButtonR2, function(_, state, obj)
		if state == Enum.UserInputState.Begin then
			self:_TriggerAction(Enums.ActionType.M1, state, obj)
		end
	end)
	
	self:_BindAction("CombatDash", Enum.KeyCode.Q, function(_, state, obj)
		if state == Enum.UserInputState.Begin then
			self:_TriggerAction(Enums.ActionType.Q, state, obj)
		end
	end)
	
	self:_BindAction("CombatSlide", Enum.KeyCode.C, function(_, state, obj)
		if state == Enum.UserInputState.Begin then
			self:_TriggerAction(Enums.ActionType.C, state, obj)
		end
	end)
	
	self:_BindAction("CombatBlock", Enum.KeyCode.F, function(_, state, obj)
		self._inputStates[Enums.ActionType.F] = (state == Enum.UserInputState.Begin)
		self:_TriggerAction(Enums.ActionType.F, state, obj)
	end)
	
	-- Mobile touch
	if UserInputService.TouchEnabled then
		local touchConnection = UserInputService.TouchTap:Connect(function(_, gameProcessed)
			if not gameProcessed then
				self:_TriggerAction(Enums.ActionType.M1, Enum.UserInputState.Begin, nil)
			end
		end)
		table.insert(self._connections, touchConnection)
	end
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
-- ACTION TRIGGERING
-- ========================================

function InputHandler:_TriggerAction(actionType: string, inputState: Enum.UserInputState, inputObject: InputObject?)
	if not self._enabled or self._blockedInputs[actionType] then return end
	
	-- Debounce
	local now = os.clock()
	if now - (self._lastInputTime[actionType] or 0) < INPUT_DEBOUNCE_TIME then return end
	self._lastInputTime[actionType] = now
	
	-- Update state
	self._inputStates[actionType] = (inputState == Enum.UserInputState.Begin)
	
	-- Trigger callbacks
	local callbacks = self._callbacks[actionType]
	if callbacks then
		local direction = self:_GetMovementDirection()
		for _, callback in ipairs(callbacks) do
			callback(actionType, inputState, inputObject, direction)
		end
	end
end

-- ========================================
-- MOVEMENT DIRECTION DETECTION
-- ========================================

function InputHandler:_GetMovementDirection(): string
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then return Enums.Direction.Forward end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then return Enums.Direction.Backward end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then return Enums.Direction.Left end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then return Enums.Direction.Right end
	return Enums.Direction.Forward
end

-- ========================================
-- CALLBACK REGISTRATION
-- ========================================

function InputHandler:RegisterCallback(actionType: string, callback: InputCallback)
	if self._callbacks[actionType] then
		table.insert(self._callbacks[actionType], callback)
	end
end

-- ========================================
-- INPUT BLOCKING
-- ========================================

function InputHandler:BlockAllInputs(blocked: boolean)
	for actionType in pairs(self._blockedInputs) do
		self._blockedInputs[actionType] = blocked
	end
end

-- ========================================
-- CLEANUP
-- ========================================

function InputHandler:Destroy()
	self._enabled = false
	
	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end
	
	for _, action in ipairs({"CombatM1", "CombatDash", "CombatSlide", "CombatBlock"}) do
		ContextActionService:UnbindAction(action)
	end
	
	table.clear(self._callbacks)
	table.clear(self._inputStates)
	table.clear(self._blockedInputs)
	table.clear(self._lastInputTime)
	table.clear(self._connections)
end

return InputHandler
