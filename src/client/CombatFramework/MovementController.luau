--[[
	Module: MovementController
	Type: Client Movement Module
	Location: StarterPlayer.StarterPlayerScripts.CombatFramework.MovementController
	Path: src/client/CombatFramework/MovementController.luau
	
	Description:
		Unified client-side movement controller for Dash and Slide mechanics.
		Eliminates code duplication by centralizing dynamic movement logic.
		Handles WASD direction detection, camera rotation, and friction-based movement.
	
	Dependencies:
		- ReplicatedStorage.CombatCore.Core (Config, Utility, DebugLogger)
		- game:GetService("UserInputService")
	
	Author: Professional Roblox Scripter
	Created: December 13, 2025
--]]

-- Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Module Imports
local CombatSystem = ReplicatedStorage:WaitForChild("CombatCore")
local Core = CombatSystem:WaitForChild("Core")

local Config = require(Core.Config)
local Utility = require(Core.Utility)
local DebugLogger = require(Core.DebugLogger)
local HitboxVisualizer = require(Core.HitboxVisualizer)

-- Constants
local LocalPlayer = Players.LocalPlayer

-- Movement Controller Class
local MovementController = {}
MovementController.__index = MovementController

-- ========================================
-- TYPES
-- ========================================

type MovementConfig = {
	Speed: number,
	Duration: number,
	FrictionMultiplier: number,
}

type ActiveMovement = {
	bodyVelocity: BodyVelocity,
	humanoid: Humanoid,
	originalWalkSpeed: number,
	running: boolean,
}

type MovementController = {
	_activeMovement: ActiveMovement?,
	_movementThread: thread?,
}

-- ========================================
-- CONSTRUCTOR
-- ========================================

function MovementController.new(): MovementController
	local self = setmetatable({}, MovementController)
	
	self._activeMovement = nil
	self._movementThread = nil
	
	return self
end

-- ========================================
-- DIRECTION DETECTION
-- ========================================

-- Get current WASD input direction relative to camera
function MovementController:GetCurrentInputDirection(): Vector3?
	local character = LocalPlayer.Character
	if not character then return nil end
	
	local rootPart = Utility.GetRootPart(character)
	if not rootPart then return nil end
	
	-- Get camera direction
	local cameraLook = rootPart.CFrame.LookVector
	local cameraRight = rootPart.CFrame.RightVector
	
	-- Detect WASD inputs
	local moveVector = Vector3.zero
	
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then
		moveVector = moveVector + cameraLook
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then
		moveVector = moveVector - cameraLook
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then
		moveVector = moveVector - cameraRight
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then
		moveVector = moveVector + cameraRight
	end
	
	if moveVector.Magnitude > 0 then
		return moveVector.Unit
	end
	
	-- Default: forward if no input
	return cameraLook
end

-- Determine fixed direction type (front/back/left/right) from vector
function MovementController:GetFixedDirectionFromVector(directionVector: Vector3): string
	local camera = workspace.CurrentCamera
	local cameraLook = camera.CFrame.LookVector
	local cameraRight = camera.CFrame.RightVector
	
	local dot = directionVector:Dot(cameraLook)
	local dotRight = directionVector:Dot(cameraRight)
	
	if math.abs(dot) > math.abs(dotRight) then
		return dot > 0 and "front" or "back"
	else
		return dotRight > 0 and "right" or "left"
	end
end

-- ========================================
-- UNIFIED DYNAMIC MOVEMENT
-- ========================================

function MovementController:StartDynamicMovement(movementType: string, config: MovementConfig)
	local character = LocalPlayer.Character
	if not character then return end
	
	local rootPart = Utility.GetRootPart(character)
	local humanoid = Utility.GetHumanoid(character)
	if not rootPart or not humanoid then return end
	
	-- Cancel existing movement
	self:StopMovement()
	
	-- Store initial direction from WASD
	local initialDirection = self:GetCurrentInputDirection()
	if not initialDirection then
		initialDirection = rootPart.CFrame.LookVector
	end
	
	local fixedDirection = self:GetFixedDirectionFromVector(initialDirection)
	
	-- Disable humanoid movement
	humanoid.AutoRotate = false
	local originalWalkSpeed = humanoid.WalkSpeed
	humanoid.WalkSpeed = 0
	
	-- Create BodyVelocity for movement
	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.MaxForce = Vector3.new(100000, 0, 100000)
	bodyVelocity.Parent = rootPart
	
	-- Movement parameters
	local rate = 0.01
	local elapsed = 0
	
	local running = true
	self._activeMovement = {
		bodyVelocity = bodyVelocity,
		humanoid = humanoid,
		originalWalkSpeed = originalWalkSpeed,
		running = running
	}
	
	-- Cancel previous movement thread if any
	if self._movementThread then
		task.cancel(self._movementThread)
		self._movementThread = nil
	end
	
	-- Show hitbox visualization if enabled
	if Config.Debug.ShowHitboxes then
		local visualizationType = movementType == "Dash" and "Dash" or "Slide"
		local visualRange = config.Speed * config.Duration -- Approximate travel distance
		HitboxVisualizer.ShowAttack(
			rootPart.Position,
			initialDirection,
			Vector3.new(3, 3, 3), -- Small hitbox size for visualization
			visualRange,
			visualizationType,
			config.Duration
		)
	end
	
	-- Movement loop with friction
	self._movementThread = task.spawn(function()
		while elapsed <= config.Duration do
			if not self._activeMovement or not self._activeMovement.running or not rootPart or not rootPart.Parent then
				break
			end
			
			-- Rotate character to match camera direction
			local forwardVector = workspace.CurrentCamera.CFrame.LookVector
			local targetRotation = math.atan2(forwardVector.X, forwardVector.Z) + math.pi
			rootPart.CFrame = CFrame.new(rootPart.Position) * CFrame.Angles(0, targetRotation, 0)
			
			-- Apply velocity based on fixed direction with friction
			if bodyVelocity and bodyVelocity.Parent then
				local currentLook = rootPart.CFrame.LookVector
				local currentRight = rootPart.CFrame.RightVector
				local velocityDirection
				
				if fixedDirection == "front" then
					velocityDirection = currentLook
				elseif fixedDirection == "back" then
					velocityDirection = -currentLook
				elseif fixedDirection == "right" then
					velocityDirection = currentRight
				elseif fixedDirection == "left" then
					velocityDirection = -currentRight
				end
				
				-- Apply friction decay (smooth deceleration)
				local progress = elapsed / config.Duration
				local frictionMultiplier = 1 - (progress * config.FrictionMultiplier)
				
				bodyVelocity.Velocity = velocityDirection * config.Speed * frictionMultiplier
			end
			
			elapsed = elapsed + rate
			task.wait(rate)
		end
		
		self:StopMovement()
	end)
	
	DebugLogger.ClientAction(movementType, string.format("Started - Direction: %s", fixedDirection))
end

-- ========================================
-- MOVEMENT CONTROL
-- ========================================

function MovementController:StopMovement()
	if not self._activeMovement then return end
	
	-- Store references before clearing
	local bodyVelocity = self._activeMovement.bodyVelocity
	local humanoid = self._activeMovement.humanoid
	local originalWalkSpeed = self._activeMovement.originalWalkSpeed
	
	-- Stop loop (signal to thread to exit)
	self._activeMovement.running = false
	
	-- Cancel thread if still running (give it a moment to detect running = false)
	if self._movementThread then
		task.wait(0.01) -- Small delay to let loop detect running = false
		pcall(function()
			task.cancel(self._movementThread)
		end)
		-- Ignore errors - thread may have already completed
		self._movementThread = nil
	end
	
	-- Cleanup BodyVelocity
	if bodyVelocity and bodyVelocity.Parent then
		bodyVelocity:Destroy()
	end
	
	-- Restore humanoid
	if humanoid then
		humanoid.AutoRotate = true
		humanoid.WalkSpeed = originalWalkSpeed
	end
	
	-- Clear active movement last
	self._activeMovement = nil
end

function MovementController:IsMoving(): boolean
	return self._activeMovement ~= nil
end

-- ========================================
-- CLEANUP
-- ========================================

function MovementController:Destroy()
	self:StopMovement()
end

return MovementController
