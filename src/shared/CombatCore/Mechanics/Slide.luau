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

local Enums = require(Core.Enums)
local Logger = require(Core.Logger).GetInstance()
local Utility = require(Core.Utility)

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

function Slide:Execute(player: Player, data: {[string]: any})
	if not IS_SERVER then
		Logger:Warning("Slide can only be executed on server")
		return
	end
	
	local character = player.Character
	if not Utility.IsCharacterValid(character) then
		Logger:Warning("Invalid character for Slide", {player = player.Name})
		return
	end
	
	local direction = data.Direction or Enums.Direction.Forward
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
	
	Logger:Debug("Slide executed", {
		player = player.Name,
		direction = direction
	})
end

function Slide:CancelSlide(player: Player)
	Logger:Debug("Slide cancel requested", {player = player.Name})
	
	-- Cancel validation thread if exists
	local startData = SlideStartPositions[player]
	if startData and startData.Thread then
		task.cancel(startData.Thread)
	end
	
	-- Clean up tracking data
	SlideStartPositions[player] = nil
end

-- ========================================
-- ANTI-EXPLOIT VALIDATION
-- ========================================

function Slide:_ValidateSlideDistance(player: Player)
	local startData = SlideStartPositions[player]
	if not startData then
		return -- Slide was cancelled or player left
	end
	
	local character = player.Character
	if not Utility.IsCharacterValid(character) then
		SlideStartPositions[player] = nil
		return
	end
	
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then
		SlideStartPositions[player] = nil
		return
	end
	
	local endPosition = humanoidRootPart.Position
	local distanceMoved = (endPosition - startData.Position).Magnitude
	local timeTaken = tick() - startData.Time
	
	-- Calculate max allowed distance (Distance + 25% tolerance)
	local maxAllowedDistance = Config.Slide.Distance * 1.25
	
	-- Calculate max allowed speed (with tolerance)
	local maxAllowedSpeed = (Config.Slide.Speed * 1.3) -- 30% tolerance
	local actualSpeed = distanceMoved / timeTaken
	
	-- Validate distance
	if distanceMoved > maxAllowedDistance then
		Logger:Warning("Slide distance exploit detected", {
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
		Logger:Warning("Slide speed exploit detected", {
			player = player.Name,
			speed = actualSpeed,
			maxAllowed = maxAllowedSpeed,
			timeTaken = timeTaken
		})
		
		-- Revert to start position
		humanoidRootPart.CFrame = CFrame.new(startData.Position)
	end
	
	-- Clean up
	SlideStartPositions[player] = nil
end

-- ========================================
-- CLIENT BROADCASTING
-- ========================================

function Slide:_BroadcastSlide(player: Player)
	local NetworkManager = require(CombatSystem:WaitForChild("Network"):WaitForChild("NetworkManager"))
	local netManager = NetworkManager.GetServerInstance()
	
	-- Broadcast to all clients for VFX/SFX
	netManager:SendToAllClients(Enums.NetworkEvent.PlayAnimation, {
		Player = player,
		AnimationType = "Slide",
	})
	
	netManager:SendToAllClients(Enums.NetworkEvent.PlayVFX, {
		VFXType = "SlideTrail",
		Player = player,
	})
end

return Slide
