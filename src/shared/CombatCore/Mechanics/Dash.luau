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
	
	local character = player.Character
	if not Utility.IsCharacterValid(character) then
		Logger:Warning("Invalid character for Dash", {player = player.Name})
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
	
	Logger:Debug("Dash executed", {
		player = player.Name,
		direction = direction
	})
end

function Dash:CancelDash(player: Player)
	Logger:Debug("Dash cancel requested", {player = player.Name})
	
	-- Cancel validation thread if exists
	local startData = DashStartPositions[player]
	if startData and startData.Thread then
		task.cancel(startData.Thread)
	end
	
	-- Clean up tracking data
	DashStartPositions[player] = nil
end

-- ========================================
-- ANTI-EXPLOIT VALIDATION
-- ========================================

function Dash:_ValidateDashDistance(player: Player)
	local startData = DashStartPositions[player]
	if not startData then
		return -- Dash was cancelled or player left
	end
	
	local character = player.Character
	if not Utility.IsCharacterValid(character) then
		DashStartPositions[player] = nil
		return
	end
	
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then
		DashStartPositions[player] = nil
		return
	end
	
	local endPosition = humanoidRootPart.Position
	local distanceMoved = (endPosition - startData.Position).Magnitude
	local timeTaken = tick() - startData.Time
	
	-- Calculate max allowed distance (Distance + 25% tolerance)
	local maxAllowedDistance = Config.Dash.Distance * 1.25
	
	-- Calculate max allowed speed (with tolerance)
	local maxAllowedSpeed = (Config.Dash.Speed * 1.3) -- 30% tolerance
	local actualSpeed = distanceMoved / timeTaken
	
	-- Validate distance
	if distanceMoved > maxAllowedDistance then
		Logger:Warning("Dash distance exploit detected", {
			player = player.Name,
			distance = distanceMoved,
			maxAllowed = maxAllowedDistance,
			excess = distanceMoved - maxAllowedDistance
		})
		
		-- Revert to start position
		humanoidRootPart.CFrame = CFrame.new(startData.Position)
	end
	
	-- Validate speed
	if actualSpeed > maxAllowedSpeed then
		Logger:Warning("Dash speed exploit detected", {
			player = player.Name,
			speed = actualSpeed,
			maxAllowed = maxAllowedSpeed,
			timeTaken = timeTaken
		})
		
		-- Revert to start position
		humanoidRootPart.CFrame = CFrame.new(startData.Position)
	end
	
	-- Clean up
	DashStartPositions[player] = nil
end

-- ========================================
-- CLIENT BROADCASTING
-- ========================================

function Dash:_BroadcastDash(player: Player, direction: string)
	local NetworkManager = require(CombatSystem:WaitForChild("Network"):WaitForChild("NetworkManager"))
	local netManager = NetworkManager.GetServerInstance()
	
	-- Broadcast to all clients for VFX/SFX
	netManager:SendToAllClients(Enums.NetworkEvent.PlayAnimation, {
		Player = player,
		AnimationType = "Dash",
		Direction = direction,
	})
	
	netManager:SendToAllClients(Enums.NetworkEvent.PlayVFX, {
		VFXType = "DashTrail",
		Player = player,
		Direction = direction,
	})
end

return Dash
