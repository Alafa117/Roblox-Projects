--[[
	Module: MovementMechanicBase
	Type: Helper Module (Shared)
	Location: ReplicatedStorage.CombatCore.Mechanics.MovementMechanicBase
	Path: src/shared/CombatCore/Mechanics/MovementMechanicBase.luau
	
	Description:
		Base helper for movement mechanics (Dash, Slide).
		Centralizes anti-exploit validation, thread cancellation, and broadcasting.
		Eliminates code duplication between Dash and Slide mechanics.
	
	Dependencies:
		- ReplicatedStorage.CombatCore.Core (Config, Enums, Logger, Utility)
		- ReplicatedStorage.CombatCore.Network (NetworkManager)
	
	Author: Professional Roblox Scripter
	Created: December 13, 2025
--]]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Module Imports
local CombatSystem = ReplicatedStorage:WaitForChild("CombatCore")
local Core = CombatSystem:WaitForChild("Core")

local Enums = require(Core.Enums)
local Logger = require(Core.Logger).GetInstance()
local Utility = require(Core.Utility)

-- Movement Mechanic Base Module
local MovementMechanicBase = {}

-- ========================================
-- ANTI-EXPLOIT VALIDATION
-- ========================================

function MovementMechanicBase.ValidateMovementDistance(
	player: Player,
	startData: {Position: Vector3, Time: number, Thread: thread?},
	trackingTable: {[Player]: any},
	mechanicName: string,
	maxDistance: number,
	maxSpeed: number
): boolean
	if not startData then
		return false -- Movement was cancelled or player left
	end
	
	-- Get character (support Players and Test Rigs)
	local character = if typeof(player) == "Instance" and player:IsA("Player") then player.Character else player
	if not Utility.IsCharacterValid(character) then
		trackingTable[player] = nil
		return false
	end
	
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then
		trackingTable[player] = nil
		return false
	end
	
	local endPosition = humanoidRootPart.Position
	local distanceMoved = (endPosition - startData.Position).Magnitude
	local timeTaken = tick() - startData.Time
	
	-- Calculate max allowed distance (Distance + 25% tolerance)
	local maxAllowedDistance = maxDistance * 1.25
	
	-- Calculate max allowed speed (with tolerance)
	local maxAllowedSpeed = maxSpeed * 1.3 -- 30% tolerance
	local actualSpeed = distanceMoved / timeTaken
	
	local exploitDetected = false
	
	-- Validate distance
	if distanceMoved > maxAllowedDistance then
		Logger:Warning(mechanicName .. " distance exploit detected", {
			player = player.Name,
			distance = distanceMoved,
			maxAllowed = maxAllowedDistance,
			excess = distanceMoved - maxAllowedDistance
		})
		exploitDetected = true
	end
	
	-- Validate speed
	if actualSpeed > maxAllowedSpeed then
		Logger:Warning(mechanicName .. " speed exploit detected", {
			player = player.Name,
			speed = actualSpeed,
			maxAllowed = maxAllowedSpeed,
			timeTaken = timeTaken
		})
		exploitDetected = true
	end
	
	-- Revert to start position if exploit detected
	if exploitDetected then
		humanoidRootPart.CFrame = CFrame.new(startData.Position)
	end
	
	-- Clean up
	trackingTable[player] = nil
	
	return not exploitDetected
end

-- ========================================
-- MOVEMENT CANCELLATION
-- ========================================

function MovementMechanicBase.CancelMovement(player: Player, trackingTable: {[Player]: any})
	local startData = trackingTable[player]
	if startData and startData.Thread then
		pcall(function()
			task.cancel(startData.Thread)
		end)
		-- Ignore errors - thread may have already completed
	end
	
	-- Clean up tracking data
	trackingTable[player] = nil
end

-- ========================================
-- CLIENT BROADCASTING
-- ========================================

function MovementMechanicBase.BroadcastMovement(
	player: Player,
	animationType: string,
	vfxType: string,
	direction: string?
)
	local NetworkManager = require(CombatSystem:WaitForChild("Network"):WaitForChild("NetworkManager"))
	local netManager = NetworkManager.GetServerInstance()
	
	-- Broadcast to all clients for VFX/SFX
	local animData = {
		Player = player,
		AnimationType = animationType,
	}
	
	if direction then
		animData.Direction = direction
	end
	
	netManager:SendToAllClients(Enums.NetworkEvent.PlayAnimation, animData)
	
	local vfxData = {
		VFXType = vfxType,
		Player = player,
	}
	
	if direction then
		vfxData.Direction = direction
	end
	
	netManager:SendToAllClients(Enums.NetworkEvent.PlayVFX, vfxData)
end

return MovementMechanicBase
