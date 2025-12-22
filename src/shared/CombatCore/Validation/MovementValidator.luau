--[[
	Module: MovementValidator
	Type: Validation Module (Shared)
	Location: ReplicatedStorage.CombatCore.Validation.MovementValidator
	Path: src/shared/CombatCore/Validation/MovementValidator.luau
	
	Description:
		Validates movement mechanics for anti-exploit protection.
		Checks distance and speed limits with tolerances.
		Handles exploit detection and automatic position correction.
		
		Extracted from MovementMechanicBase for single responsibility.
		Phase 2 Refactoring - Separated validation logic.
	
	Responsibilities:
		- Validate movement distance within allowed limits
		- Validate movement speed with tolerance
		- Detect and log exploit attempts
		- Revert positions on exploit detection
		- Clean up tracking data
	
	Dependencies:
		- ReplicatedStorage.CombatCore.Logging (Logger)
		- ReplicatedStorage.CombatCore.Validation (ValidationHelper)
	
	Author: Professional Roblox Scripter
	Created: December 18, 2025 (Phase 2 - Task 2)
--]]

-- Module Imports
local Logger = require(script.Parent.Parent.Logging.Logger).GetInstance()
local ValidationHelper = require(script.Parent.ValidationHelper)

-- Movement Validator Module
local MovementValidator = {}

-- ========================================
-- TYPES
-- ========================================

export type MovementStartData = {
	Position: Vector3,
	Time: number,
	Thread: thread?,
}

export type ValidationConfig = {
	MaxDistance: number,
	MaxSpeed: number,
	DistanceTolerance: number?, -- Default: 1.25 (25%)
	SpeedTolerance: number?, -- Default: 1.3 (30%)
}

-- ========================================
-- VALIDATION
-- ========================================

-- Validate movement distance and speed for anti-exploit
function MovementValidator.ValidateMovement(
	player: Player,
	startData: MovementStartData?,
	trackingTable: {[Player]: any},
	mechanicName: string,
	config: ValidationConfig
): boolean
	if not startData then
		return false -- Movement was cancelled or player left
	end
	
	-- Get character (support Players and Test Rigs)
	local character = if typeof(player) == "Instance" and player:IsA("Player") then player.Character else player
	if not ValidationHelper.IsCharacterValid(character) then
		trackingTable[player] = nil
		return false
	end
	
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then
		trackingTable[player] = nil
		return false
	end
	
	-- Calculate actual movement
	local endPosition = humanoidRootPart.Position
	local distanceMoved = (endPosition - startData.Position).Magnitude
	local timeTaken = os.clock() - startData.Time
	
	-- Apply tolerances (with defaults)
	local distanceTolerance = config.DistanceTolerance or 1.25 -- 25% tolerance
	local speedTolerance = config.SpeedTolerance or 1.3 -- 30% tolerance
	
	-- Calculate limits
	local maxAllowedDistance = config.MaxDistance * distanceTolerance
	local maxAllowedSpeed = config.MaxSpeed * speedTolerance
	local actualSpeed = distanceMoved / timeTaken
	
	-- Check for exploits
	local exploitDetected = false
	
	-- Validate distance
	if distanceMoved > maxAllowedDistance then
		Logger:Warning(mechanicName .. " distance exploit detected", {
			player = if typeof(player) == "Instance" and player:IsA("Player") then player.Name else "TestRig",
			distance = distanceMoved,
			maxAllowed = maxAllowedDistance,
			excess = distanceMoved - maxAllowedDistance
		})
		exploitDetected = true
	end
	
	-- Validate speed
	if actualSpeed > maxAllowedSpeed then
		Logger:Warning(mechanicName .. " speed exploit detected", {
			player = if typeof(player) == "Instance" and player:IsA("Player") then player.Name else "TestRig",
			speed = actualSpeed,
			maxAllowed = maxAllowedSpeed,
			timeTaken = timeTaken
		})
		exploitDetected = true
	end
	
	-- Revert to start position if exploit detected
	if exploitDetected then
		MovementValidator.RevertPosition(humanoidRootPart, startData.Position, mechanicName)
	end
	
	-- Clean up tracking data
	trackingTable[player] = nil
	
	return not exploitDetected
end

-- Revert character position to safe location
function MovementValidator.RevertPosition(humanoidRootPart: BasePart, safePosition: Vector3, mechanicName: string)
	humanoidRootPart.CFrame = CFrame.new(safePosition)
	Logger:Info(mechanicName .. " position reverted", {
		revertedTo = tostring(safePosition)
	})
end

-- ========================================
-- TRACKING MANAGEMENT
-- ========================================

-- Cancel movement tracking and clean up thread
function MovementValidator.CancelTracking(player: Player, trackingTable: {[Player]: any})
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

-- Initialize tracking for new movement
function MovementValidator.StartTracking(
	player: Player,
	position: Vector3,
	trackingTable: {[Player]: any},
	validationThread: thread?
): MovementStartData
	local startData: MovementStartData = {
		Position = position,
		Time = os.clock(),
		Thread = validationThread,
	}
	
	trackingTable[player] = startData
	return startData
end

-- Check if player is currently being tracked
function MovementValidator.IsTracking(player: Player, trackingTable: {[Player]: any}): boolean
	return trackingTable[player] ~= nil
end

-- ========================================
-- UTILITIES
-- ========================================

-- Calculate distance moved from start data
function MovementValidator.CalculateDistanceMoved(character: Model, startPosition: Vector3): number?
	if not ValidationHelper.IsCharacterValid(character) then
		return nil
	end
	
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then
		return nil
	end
	
	local currentPosition = humanoidRootPart.Position
	return (currentPosition - startPosition).Magnitude
end

-- Calculate movement speed
function MovementValidator.CalculateSpeed(distanceMoved: number, timeTaken: number): number
	if timeTaken <= 0 then
		return 0
	end
	return distanceMoved / timeTaken
end

return MovementValidator
