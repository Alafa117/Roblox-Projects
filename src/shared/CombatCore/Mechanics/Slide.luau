--[[
	Module: Slide
	Type: Combat Mechanic Module (Server)
	Location: ReplicatedStorage.CombatCore.Mechanics.Slide
	Path: src/shared/CombatCore/Mechanics/Slide.luau
	
	Description:
		Implements the Slide (C) movement mechanic.
		Lower movement that maintains momentum with friction.
		Server-authoritative physics for consistency.
		Useful for dodging high attacks and repositioning.
	
	Dependencies:
		- ReplicatedStorage.CombatCore.Core (Config, Enums, Types, Logger, Utility)
	
	Author: Professional Roblox Scripter
	Created: December 11, 2025
--]]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Module Imports
local RS = ReplicatedStorage
local CombatSystem = RS:WaitForChild("CombatCore")
local Core = CombatSystem:WaitForChild("Core")

local Logger = require(Core.Logger).GetInstance()
local Utility = require(Core.Utility)

local MovementMechanicBase = require(script.Parent.MovementMechanicBase)

-- Slide Module
local Slide = {}

-- ========================================
-- CONSTANTS
-- ========================================

local IS_SERVER = RunService:IsServer()
local Config = require(Core.Config)

-- Anti-exploit tracking
local SlideStartPositions = {} -- {[player] = {Position = Vector3, Time = number, Thread = thread}}

-- ========================================
-- EXECUTE METHOD
-- ========================================

function Slide:Execute(player: Player, _data: {[string]: any})
	if not IS_SERVER then
		Logger:Warning("Slide can only be executed on server")
		return
	end
	
	local character = player.Character
	if not Utility.IsCharacterValid(character) then
		Logger:Warning("Invalid character for Slide", {player = player.Name})
		return
	end
	
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	
	if not humanoidRootPart then
		Logger:Warning("HumanoidRootPart not found for Slide", {player = player.Name})
		return
	end
	
	-- Schedule validation after slide duration
	local validationThread = task.delay(Config.Slide.Duration + 0.1, function()
		self:_ValidateSlideDistance(player)
	end)
	
	-- Store start position, time, and thread for validation
	SlideStartPositions[player] = {
		Position = humanoidRootPart.Position,
		Time = tick(),
		Thread = validationThread
	}
	
	-- Broadcast to clients for VFX
	self:_BroadcastSlide(player)
end

function Slide:CancelSlide(player: Player)
	Logger:Debug("Slide cancel requested", {player = player.Name})
	MovementMechanicBase.CancelMovement(player, SlideStartPositions)
end

-- ========================================
-- ANTI-EXPLOIT VALIDATION
-- ========================================

function Slide:_ValidateSlideDistance(player: Player)
	local startData = SlideStartPositions[player]
	MovementMechanicBase.ValidateMovementDistance(
		player,
		startData,
		SlideStartPositions,
		"Slide",
		Config.Slide.Distance,
		Config.Slide.Speed
	)
end

-- ========================================
-- CLIENT BROADCASTING
-- ========================================

function Slide:_BroadcastSlide(player: Player)
	MovementMechanicBase.BroadcastMovement(player, "Slide", "SlideTrail", nil)
end

return Slide
