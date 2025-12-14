--[[
	Module: Dash
	Type: Combat Mechanic Module (Server)
	Location: ReplicatedStorage.CombatCore.Mechanics.Dash
	Path: src/shared/CombatCore/Mechanics/Dash.luau
	
	Description:
		Implements the Dash (Q) movement mechanic.
		Quick directional movement with invulnerability frames.
		Server-authoritative physics with client prediction support.
		Directional dash based on player input (Forward, Backward, Left, Right).
	
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

local Enums = require(Core.Enums)
local Logger = require(Core.Logger).GetInstance()
local Utility = require(Core.Utility)

local MovementMechanicBase = require(script.Parent.MovementMechanicBase)

-- Dash Module
local Dash = {}

-- ========================================
-- CONSTANTS
-- ========================================

local IS_SERVER = RunService:IsServer()
local Config = require(Core.Config)

-- Anti-exploit tracking
local DashStartPositions = {} -- {[player] = {Position = Vector3, Time = number, Thread = thread}}

-- ========================================
-- EXECUTE METHOD
-- ========================================

function Dash:Execute(player: Player, data: {[string]: any})
	if not IS_SERVER then
		Logger:Warning("Dash can only be executed on server")
		return
	end
	
	-- Get character (support Players and Test Rigs)
	local character = if typeof(player) == "Instance" and player:IsA("Player") then player.Character else player
	if not Utility.IsCharacterValid(character) then
		local playerName = if typeof(player) == "Instance" and player:IsA("Player") then player.Name else "TestRig"
		Logger:Warning("Invalid character for Dash", {player = playerName})
		return
	end
	
	local direction = data.Direction or Enums.Direction.Forward
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	
	if not humanoidRootPart then
		Logger:Warning("HumanoidRootPart not found for Dash", {player = player.Name})
		return
	end
	
	-- Schedule validation after dash duration
	local validationThread = task.delay(Config.Dash.Duration + 0.1, function()
		self:_ValidateDashDistance(player)
	end)
	
	-- Store start position, time, and thread for validation
	DashStartPositions[player] = {
		Position = humanoidRootPart.Position,
		Time = tick(),
		Thread = validationThread
	}
	
	-- Broadcast to clients for VFX
	self:_BroadcastDash(player, direction)
end

function Dash:CancelDash(player: Player)
	Logger:Debug("Dash cancel requested", {player = player.Name})
	MovementMechanicBase.CancelMovement(player, DashStartPositions)
end

-- ========================================
-- ANTI-EXPLOIT VALIDATION
-- ========================================

function Dash:_ValidateDashDistance(player: Player)
	local startData = DashStartPositions[player]
	MovementMechanicBase.ValidateMovementDistance(
		player,
		startData,
		DashStartPositions,
		"Dash",
		Config.Dash.Distance,
		Config.Dash.Speed
	)
end

-- ========================================
-- CLIENT BROADCASTING
-- ========================================

function Dash:_BroadcastDash(player: Player, direction: string)
	MovementMechanicBase.BroadcastMovement(player, "Dash", "DashTrail", direction)
end

return Dash
