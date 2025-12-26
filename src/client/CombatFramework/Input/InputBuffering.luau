--[[
	Module: InputBuffering
	Type: Client Input Buffering System
	Location: StarterPlayer.StarterPlayerScripts.CombatFramework.Input.InputBuffering
	Path: src/client/CombatFramework/Input/InputBuffering.luau
	
	Description:
		Implements input buffering for smoother combat feel.
		Stores inputs that occur during animation locks and executes them when possible.
		Prevents input loss during combo chains and ability cooldowns.
		300ms buffer window provides premium UX for input tolerance.
	
	Dependencies:
		- ReplicatedStorage.CombatCore.Core.Logger
	
	Author: Professional Roblox Scripter
	Created: December 9, 2025
	Updated: December 23, 2025 - Moved to Input/ subfolder
--]]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Module Imports
local RS = ReplicatedStorage
local CombatSystem = RS:WaitForChild("CombatCore")

local Logger = require(CombatSystem.Logging.Logger).GetInstance()

-- Constants
local BUFFER_WINDOW = 0.15 -- Reduced from 0.3s to 0.15s to prevent extra M1s (December 26, 2025)
local MAX_BUFFER_SIZE = 3 -- Maximum buffered inputs

-- Input Buffering Class
local InputBuffering = {}
InputBuffering.__index = InputBuffering

-- ========================================
-- TYPES
-- ========================================

type BufferedInput = {
	ActionType: string,
	Timestamp: number,
	Data: {[string]: any}?,
}

type InputBuffering = {
	_buffer: {BufferedInput},
}

-- ========================================
-- CONSTRUCTOR
-- ========================================

function InputBuffering.new(): InputBuffering
	local self = setmetatable({}, InputBuffering)
	
	self._buffer = {}
	
	Logger:Debug("InputBuffering initialized")
	
	return self
end

-- ========================================
-- BUFFER MANAGEMENT
-- ========================================

function InputBuffering:AddInput(actionType: string, data: {[string]: any}?)
	-- Check if same action is already in buffer (prevent spam)
	local now = os.clock()
	for i = #self._buffer, 1, -1 do
		local buffered = self._buffer[i]
		if buffered.ActionType == actionType and (now - buffered.Timestamp) < 0.1 then
			-- Same action buffered within 100ms, ignore duplicate (December 26, 2025)
			return
		end
	end
	
	-- Check if buffer is full
	if #self._buffer >= MAX_BUFFER_SIZE then
		-- Remove oldest input
		table.remove(self._buffer, 1)
		Logger:Debug("Buffer full, removed oldest input")
	end
	
	-- Add new input
	local bufferedInput: BufferedInput = {
		ActionType = actionType,
		Timestamp = os.clock(),
		Data = data,
	}
	
	table.insert(self._buffer, bufferedInput)
	Logger:Debug("Input buffered", {action = actionType, bufferSize = #self._buffer})
end

function InputBuffering:GetNextInput(): BufferedInput?
	self:_CleanExpiredInputs()
	
	if #self._buffer == 0 then
		return nil
	end
	
	-- Return and remove oldest input
	local input = table.remove(self._buffer, 1)
	Logger:Debug("Input retrieved from buffer", {action = input.ActionType})
	
	return input
end

function InputBuffering:HasBufferedInputs(): boolean
	self:_CleanExpiredInputs()
	return #self._buffer > 0
end

function InputBuffering:ClearBuffer()
	table.clear(self._buffer)
end

-- ========================================
-- PRIVATE METHODS
-- ========================================

function InputBuffering:_CleanExpiredInputs()
	local currentTime = os.clock()
	local removed = 0
	
	-- Remove expired inputs from the front
	while #self._buffer > 0 do
		local input = self._buffer[1]
		if currentTime - input.Timestamp > BUFFER_WINDOW then
			table.remove(self._buffer, 1)
			removed += 1
		else
			break -- All subsequent inputs are newer
		end
	end
	
	if removed > 0 then
		Logger:Debug("Expired inputs removed", {count = removed})
	end
end

-- ========================================
-- CLEANUP
-- ========================================

function InputBuffering:Destroy()
	self:ClearBuffer()
	
	Logger:Info("InputBuffering destroyed")
end

return InputBuffering
