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
		- ReplicatedStorage.CombatCore (Config, ValidationHelper, Logger)
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

local Config = require(CombatSystem.Config.Config)
local ValidationHelper = require(CombatSystem.Validation.ValidationHelper)
local Logger = require(CombatSystem.Logging.Logger).GetInstance()
local HitboxVisualizer = require(CombatSystem.Helpers.HitboxVisualizer)

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

-- Get current WASD input as direction vector and fixed direction type
function MovementController:GetCurrentInputDirection(): (Vector3?, string)
	local character = LocalPlayer.Character
	if not character then return nil, "front" end
	
	local humanoid, rootPart = ValidationHelper.GetCharacterComponents(character)
	if not humanoid or not rootPart then return nil, "front" end
	
	local look = rootPart.CFrame.LookVector
	local right = rootPart.CFrame.RightVector
	
	-- Calculate direction based on WASD
	local moveVector = Vector3.zero
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then
		moveVector = moveVector + look
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then
		moveVector = moveVector - look
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then
		moveVector = moveVector - right
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then
		moveVector = moveVector + right
	end
	
	if moveVector.Magnitude > 0 then
		moveVector = moveVector.Unit
		local dot = moveVector:Dot(look)
		local dotRight = moveVector:Dot(right)
		local fixedDir = if math.abs(dot) > math.abs(dotRight) then (if dot > 0 then "front" else "back") else (if dotRight > 0 then "right" else "left")
		return moveVector, fixedDir
	end
	
	return look, "front"
end

-- ========================================
-- UNIFIED DYNAMIC MOVEMENT
-- ========================================

function MovementController:StartDynamicMovement(movementType: string, config: MovementConfig)
	local character = LocalPlayer.Character
	if not character then return end
	
	local humanoid, rootPart = ValidationHelper.GetCharacterComponents(character)
	if not humanoid or not rootPart then return end
	if not rootPart or not humanoid then return end
	
	self:StopMovement()
	
	local initialDirection, fixedDirection = self:GetCurrentInputDirection()
	initialDirection = initialDirection or rootPart.CFrame.LookVector
	
	-- Setup humanoid
	humanoid.AutoRotate = false
	local originalWalkSpeed = humanoid.WalkSpeed
	humanoid.WalkSpeed = 0
	
	-- Create velocity
	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.MaxForce = Vector3.new(100000, 0, 100000)
	bodyVelocity.Parent = rootPart
	
	self._activeMovement = {
		bodyVelocity = bodyVelocity,
		humanoid = humanoid,
		originalWalkSpeed = originalWalkSpeed,
		running = true
	}
	
	if self._movementThread then
		task.cancel(self._movementThread)
	end
	
	-- Movement loop
	local elapsed = 0
	local rate = 0.01
	local lastTrailTime = 0 -- Track last trail visualization
	local trailInterval = Config.Debug.MovementTrailInterval or 0.05
	
	self._movementThread = task.spawn(function()
		while elapsed <= config.Duration and self._activeMovement and self._activeMovement.running and rootPart.Parent do
			-- Rotate to camera
			local camLook = workspace.CurrentCamera.CFrame.LookVector
			rootPart.CFrame = CFrame.new(rootPart.Position) * CFrame.Angles(0, math.atan2(camLook.X, camLook.Z) + math.pi, 0)
			
			if bodyVelocity.Parent then
				local look, right = rootPart.CFrame.LookVector, rootPart.CFrame.RightVector
				local dir = if fixedDirection == "front" then look elseif fixedDirection == "back" then -look elseif fixedDirection == "right" then right else -right
				local friction = 1 - (elapsed / config.Duration * config.FrictionMultiplier)
				bodyVelocity.Velocity = dir * config.Speed * friction
			end
			
			-- Create trail visualization boxes
			if Config.Debug.ShowHitboxes and (elapsed - lastTrailTime) >= trailInterval then
				HitboxVisualizer.ShowMovementTrail(
					rootPart.Position,
					Vector3.new(3, 3, 3),
					movementType == "Dash" and "Dash" or "Slide",
					0.3 -- Trail duration
				)
				lastTrailTime = elapsed
			end
			
			elapsed += rate
			task.wait(rate)
		end
		self:StopMovement()
	end)
	
	Logger:ClientAction(movementType, "Started: " .. fixedDirection)
end

-- ========================================
-- MOVEMENT CONTROL
-- ========================================

function MovementController:StopMovement()
	if not self._activeMovement then return end
	
	local movement = self._activeMovement
	movement.running = false
	
	if self._movementThread then
		pcall(task.cancel, self._movementThread)
		self._movementThread = nil
	end
	
	if movement.bodyVelocity and movement.bodyVelocity.Parent then
		movement.bodyVelocity:Destroy()
	end
	
	if movement.humanoid then
		movement.humanoid.AutoRotate = true
		movement.humanoid.WalkSpeed = movement.originalWalkSpeed
	end
	
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
