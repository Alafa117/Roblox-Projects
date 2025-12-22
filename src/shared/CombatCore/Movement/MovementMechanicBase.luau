--[[
	Module: MovementMechanicBase
	Type: Helper Module (Shared)
	Location: ReplicatedStorage.CombatCore.Movement.MovementMechanicBase
	Path: src/shared/CombatCore/Movement/MovementMechanicBase.luau
	
	Description:
		Base helper for movement mechanics (Dash, Slide).
		Delegates validation to MovementValidator, handles broadcasting.
		Eliminates code duplication between Dash and Slide mechanics.
		
		Phase 2 Refactoring:
		Extracted validation logic to MovementValidator for single responsibility.
		MovementMechanicBase now focuses on coordination and broadcasting.
		
		Phase 4 Refactoring:
		Added InitializeMovement to consolidate duplicate setup code in Dash/Slide.
		Eliminates ~40 lines of duplicate validation initialization.
	
	Dependencies:
		- ReplicatedStorage.CombatCore.Data (Enums)
		- ReplicatedStorage.CombatCore.Validation (MovementValidator)
		- ReplicatedStorage.CombatCore.Network (NetworkManager)
		- ReplicatedStorage.CombatCore.Helpers (Utility)
		- ReplicatedStorage.CombatCore.Logging (Logger)
	
	Author: Professional Roblox Scripter
	Created: December 13, 2025
	Refactored: December 18, 2025 (Phase 2 - Task 2)
	Refactored: December 19, 2025 (Phase 4 - Task 2)
--]]

-- Module Imports
local Enums = require(script.Parent.Parent.Data.Enums)
local MovementValidator = require(script.Parent.Parent.Validation.MovementValidator)
local ValidationHelper = require(script.Parent.Parent.Validation.ValidationHelper)
local Logger = require(script.Parent.Parent.Logging.Logger).GetInstance()
local NetworkManager = require(script.Parent.Parent.Network.NetworkManager)

-- Movement Mechanic Base Module
local MovementMechanicBase = {}

-- ========================================
-- MOVEMENT INITIALIZATION (Phase 4: Consolidated from Dash/Slide)
-- ========================================

-- Initialize movement tracking with validation scheduling
-- Returns HumanoidRootPart if successful, nil otherwise
function MovementMechanicBase.InitializeMovement(
	player: Player,
	trackingTable: {[Player]: any},
	mechanicName: string,
	duration: number,
	validationCallback: (Player) -> ()
): Instance?
	-- Get character (support Players and Test Rigs)
	local character = if typeof(player) == "Instance" and player:IsA("Player") then player.Character else player
	if not ValidationHelper.IsCharacterValid(character) then
		local playerName = if typeof(player) == "Instance" and player:IsA("Player") then player.Name else "TestRig"
		Logger:Warning("Invalid character for " .. mechanicName, {player = playerName})
		return nil
	end
	
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	
	if not humanoidRootPart then
		local playerName = if typeof(player) == "Instance" and player:IsA("Player") then player.Name else "TestRig"
		Logger:Warning("HumanoidRootPart not found for " .. mechanicName, {player = playerName})
		return nil
	end
	
	-- Schedule validation after movement duration
	local validationThread = task.delay(duration + 0.1, function()
		validationCallback(player)
	end)
	
	-- Store start position, time, and thread for validation
	trackingTable[player] = {
		Position = humanoidRootPart.Position,
		Time = os.clock(),
		Thread = validationThread
	}
	
	return humanoidRootPart
end

-- ========================================
-- VALIDATION (Delegates to MovementValidator)
-- ========================================

-- Validate movement distance and speed (delegates to MovementValidator)
function MovementMechanicBase.ValidateMovementDistance(
	player: Player,
	startData: {Position: Vector3, Time: number, Thread: thread?},
	trackingTable: {[Player]: any},
	mechanicName: string,
	maxDistance: number,
	maxSpeed: number
): boolean
	return MovementValidator.ValidateMovement(
		player,
		startData,
		trackingTable,
		mechanicName,
		{
			MaxDistance = maxDistance,
			MaxSpeed = maxSpeed,
			DistanceTolerance = 1.25, -- 25% tolerance
			SpeedTolerance = 1.3, -- 30% tolerance
		}
	)
end

-- ========================================
-- MOVEMENT CANCELLATION (Delegates to MovementValidator)
-- ========================================

function MovementMechanicBase.CancelMovement(player: Player, trackingTable: {[Player]: any})
	MovementValidator.CancelTracking(player, trackingTable)
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
