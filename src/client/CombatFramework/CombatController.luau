--[[
	Module: CombatController
	Type: Client Main Controller
	Location: StarterPlayer.StarterPlayerScripts.CombatController.CombatController
	Path: src/client/CombatFramework/CombatController.luau
	
	Description:
		Main client-side controller for the Combat System.
		Manages input handling, server communication, local state, and visual feedback.
		Implements client-side prediction for responsive combat feel.
		Coordinates between InputHandler, AnimationManager, and network layer.
	
	Dependencies:
		- ReplicatedStorage.CombatCore.Core (Config, Enums, Types, Logger, Utility)
		- ReplicatedStorage.CombatCore.Network.NetworkManager
		- CombatController.InputHandler
		- CombatController.InputBuffering
	
	Author: Professional Roblox Scripter
	Created: December 10, 2025
--]]

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

-- Module Imports
local RS = ReplicatedStorage
local CombatSystem = RS:WaitForChild("CombatCore")
local Core = CombatSystem:WaitForChild("Core")

local Config = require(Core.Config)
local Enums = require(Core.Enums)
local Logger = require(Core.Logger).GetInstance()
local Utility = require(Core.Utility)
local DebugLogger = require(Core.DebugLogger)

local InputHandler = require(script.Parent.InputHandler)
local InputBuffering = require(script.Parent.InputBuffering)
local StateManager = require(script.Parent.StateManager)

-- Constants
local LocalPlayer = Players.LocalPlayer

-- Combat Controller Class
local CombatController = {}
CombatController.__index = CombatController

-- ========================================
-- TYPES
-- ========================================

type CombatController = {
	_inputHandler: any,
	_inputBuffering: any,
	_stateManager: any,
	_networkManager: any?,
	_animationManager: any?,
	
	_currentState: string,
	_comboCount: number,
	_lastAttackTime: number,
	
	_cooldowns: {[string]: number},
	_isInitialized: boolean,
	_enabled: boolean,
	
	-- Active movement tracking
	_activeDash: any?,
	_activeSlide: any?,
	
	Character: Model?,
	Humanoid: Humanoid?,
	HumanoidRootPart: BasePart?,
}

-- ========================================
-- CONSTRUCTOR
-- ========================================

function CombatController.new(): CombatController
	local self = setmetatable({}, CombatController)
	
	-- Core Components
	self._inputHandler = InputHandler.new()
	self._inputBuffering = InputBuffering.new()
	self._stateManager = StateManager.new(self)
	self._networkManager = nil
	self._animationManager = nil
	
	-- State
	self._currentState = Enums.CombatState.Idle
	self._comboCount = 0
	self._lastAttackTime = 0
	
	-- Cooldowns
	self._cooldowns = {
		[Enums.ActionType.M1] = 0,
		[Enums.ActionType.M2] = 0,
		[Enums.ActionType.Q] = 0,
		[Enums.ActionType.C] = 0,
		[Enums.ActionType.F] = 0,
	}
	
	-- Flags
	self._isInitialized = false
	self._enabled = false
	
	-- Active movement tracking
	self._activeDash = nil
	self._activeSlide = nil
	
	-- Character References
	self.Character = nil
	self.Humanoid = nil
	self.HumanoidRootPart = nil
	
	Logger:Info("CombatController created")
	
	return self
end

-- ========================================
-- INITIALIZATION
-- ========================================

function CombatController:Initialize()
	if self._isInitialized then
		Logger:Warning("CombatController already initialized")
		return
	end
	
	-- Wait for character
	self:_WaitForCharacter()
	
	-- Initialize network manager
	self:_InitializeNetworkManager()
	
	-- Initialize animation manager
	self:_InitializeAnimationManager()
	
	-- Setup input callbacks
	self:_SetupInputCallbacks()
	
	-- Initialize input handler
	self._inputHandler:Initialize()
	
	-- Configure mouse lock for combat
	self:_ConfigureMouseLock()
	
	-- Start update loop
	self:_StartUpdateLoop()
	
	self._isInitialized = true
	self._enabled = true
	
	Logger:Info("CombatController initialized successfully")
end

-- ========================================
-- CHARACTER SETUP
-- ========================================

function CombatController:_WaitForCharacter()
	-- Wait for initial character
	if not LocalPlayer.Character then
		LocalPlayer.CharacterAdded:Wait()
	end
	
	self:_OnCharacterAdded(LocalPlayer.Character)
	
	-- Listen for respawns
	LocalPlayer.CharacterAdded:Connect(function(character)
		self:_OnCharacterAdded(character)
	end)
end

function CombatController:_ConfigureMouseLock()
	-- Enable toggleable mouse lock (Shift key to lock/unlock - Roblox default behavior)
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true -- Keep cursor visible when unlocked
	
	Logger:Info("Mouse lock toggle enabled (press Shift to lock/unlock)")
end

function CombatController:_OnCharacterAdded(character: Model)
	-- Wait for humanoid
	local humanoid = character:WaitForChild("Humanoid", 5)
	local rootPart = character:WaitForChild("HumanoidRootPart", 5)
	
	if not humanoid or not rootPart then
		Logger:Error("Failed to get character components")
		return
	end
	
	-- Verify R6
	if not Utility.IsR6Character(character) then
		Logger:Warning("Character is not R6, combat system may not work correctly")
	end
	
	-- Update references
	self.Character = character
	self.Humanoid = humanoid
	self.HumanoidRootPart = rootPart
	
	-- Reset state
	self:_ResetState()
	
	-- Load animations
	if self._animationManager then
		self._animationManager:LoadAnimations(character)
	end
	
	-- Listen for death
	humanoid.Died:Connect(function()
		self:_OnCharacterDied()
	end)
	
	Logger:Info("Character loaded", {character = character.Name})
end

function CombatController:_OnCharacterDied()
	-- Disable inputs
	self._inputHandler:BlockAllInputs(true)
	
	-- Reset state
	self._currentState = Enums.CombatState.Dead
	
	Logger:Info("Character died")
end

-- ========================================
-- NETWORK MANAGER SETUP
-- ========================================

function CombatController:_InitializeNetworkManager()
	-- Wait for network manager
	local networkManagerModule = CombatSystem:WaitForChild("Network"):WaitForChild("NetworkManager")
	local NetworkManager = require(networkManagerModule)
	
	self._networkManager = NetworkManager.GetClientInstance()
	
	-- Register server callbacks
	self._networkManager:RegisterCallback(Enums.NetworkEvent.StateChanged, function(newState)
		self:_OnServerStateChanged(newState)
	end)
	
	self._networkManager:RegisterCallback(Enums.NetworkEvent.ActionResult, function(result)
		self:_OnActionResult(result)
	end)
	
	self._networkManager:RegisterCallback(Enums.NetworkEvent.TakeDamage, function(damageData)
		self:_OnTakeDamage(damageData)
	end)
	
	self._networkManager:RegisterCallback(Enums.NetworkEvent.ApplyKnockback, function(knockbackData)
		self:_OnApplyKnockback(knockbackData)
	end)
	
	Logger:Debug("NetworkManager initialized")
end

-- ========================================
-- ANIMATION MANAGER SETUP
-- ========================================

function CombatController:_InitializeAnimationManager()
	-- Wait for animation manager
	local animationModule = CombatSystem:WaitForChild("Animations"):WaitForChild("AnimationManager")
	local AnimationManager = require(animationModule)
	
	self._animationManager = AnimationManager.new(self.Character)
	
	Logger:Debug("AnimationManager initialized")
end

-- ========================================
-- INPUT CALLBACKS
-- ========================================

function CombatController:_SetupInputCallbacks()
	-- M1 - Light Attack
	self._inputHandler:RegisterCallback(Enums.ActionType.M1, function(_actionType, inputState, _inputObject, _direction)
		if inputState == Enum.UserInputState.Begin then
			self:_HandleLightAttack()
		end
	end)
	
	-- M2 - Strong Attack (Instant)
	self._inputHandler:RegisterCallback(Enums.ActionType.M2, function(_actionType, inputState, _inputObject, _direction)
		if inputState == Enum.UserInputState.Begin then
			self:_HandleStrongAttack()
		end
	end)
	
	-- Q - Dash
	self._inputHandler:RegisterCallback(Enums.ActionType.Q, function(_actionType, inputState, _inputObject, direction)
		DebugLogger.ClientAction("Dash callback", string.format("State: %s, Direction: %s", tostring(inputState), direction))
		if inputState == Enum.UserInputState.Begin then
			self:_HandleDash(direction)
		end
	end)
	
	-- C - Slide
	self._inputHandler:RegisterCallback(Enums.ActionType.C, function(_actionType, inputState, _inputObject, direction)
		DebugLogger.ClientAction("Slide callback", string.format("State: %s, Direction: %s", tostring(inputState), direction))
		if inputState == Enum.UserInputState.Begin then
			self:_HandleSlide(direction)
		end
	end)
	
	-- F - Block
	self._inputHandler:RegisterCallback(Enums.ActionType.F, function(_actionType, inputState, _inputObject)
		if inputState == Enum.UserInputState.Begin then
			self:_HandleBlockStart()
		elseif inputState == Enum.UserInputState.End then
			self:_HandleBlockEnd()
		end
	end)
	
	Logger:Debug("Input callbacks registered")
end

-- ========================================
-- ACTION HANDLERS
-- ========================================

function CombatController:_HandleLightAttack()
	-- Check if can attack
	if not self:_CanPerformAction(Enums.ActionType.M1) then
		self._inputBuffering:AddInput(Enums.ActionType.M1)
		return
	end
	
	-- Store if we were dashing/sliding for cleanup after attack
	local wasDashing = self._currentState == Enums.CombatState.Dashing
	local wasSliding = self._currentState == Enums.CombatState.Sliding
	
	-- Check combo window
	local timeSinceLastAttack = os.clock() - self._lastAttackTime
	if timeSinceLastAttack <= Config.LightAttack.ComboWindow then
		self._comboCount = math.min(self._comboCount + 1, Config.LightAttack.MaxComboCount)
	else
		self._comboCount = 1
	end
	
	-- Update state using StateManager
	self._stateManager:HandleLightAttackState()
	self._lastAttackTime = os.clock()
	-- Cooldown activates IMMEDIATELY (regardless of hit/miss)
	self._cooldowns[Enums.ActionType.M1] = os.clock()
	
	-- Play animation locally (prediction)
	if self._animationManager then
		self._animationManager:PlayAttackAnimation(Enums.AttackType.LightAttack, self._comboCount)
	end
	
	-- Send to server
	DebugLogger.ClientAction("M1 Request", string.format("Combo: %d", self._comboCount))
	self._networkManager:SendToServer(Enums.NetworkEvent.RequestAction, {
		ActionType = Enums.ActionType.M1,
		ComboCount = self._comboCount,
	})
	
	-- Cancel movement AFTER sending attack for instant hit detection
	if wasDashing then
		DebugLogger.ClientAction("M1", "Cancelled Dash")
		self:_StopClientDash()
		self._networkManager:SendToServer(Enums.NetworkEvent.CancelDash, {})
	elseif wasSliding then
		DebugLogger.ClientAction("M1", "Cancelled Slide")
		self:_StopClientSlide()
		self._networkManager:SendToServer(Enums.NetworkEvent.CancelSlide, {})
	end
	
	Logger:Debug("Light attack requested", {combo = self._comboCount})
end

function CombatController:_HandleStrongAttack()
	DebugLogger.ClientAction("_HandleStrongAttack", "Called")
	-- Check if can attack
	if not self:_CanPerformAction(Enums.ActionType.M2) then
		DebugLogger.ClientValidationFailed("M2", "Cannot perform action")
		return
	end
	
	-- Store if we were dashing/sliding for cleanup after attack
	local wasDashing = self._currentState == Enums.CombatState.Dashing
	local wasSliding = self._currentState == Enums.CombatState.Sliding
	
	-- Update state FIRST for instant attack
	self._stateManager:HandleStrongAttackState()
	-- Cooldown activates IMMEDIATELY (regardless of hit/miss)
	self._cooldowns[Enums.ActionType.M2] = os.clock()
	self._comboCount = 0 -- Reset combo
	
	-- Apply M2 visual effect (red body + white outline)
	self:_ApplyM2ChargeEffect()
	
	-- Play animation locally
	if self._animationManager then
		self._animationManager:PlayAttackAnimation(Enums.AttackType.StrongAttack)
	end
	
	-- Send to server (no charge duration needed)
	DebugLogger.ClientAction("M2 Request", "Instant attack")
	self._networkManager:SendToServer(Enums.NetworkEvent.RequestAction, {
		ActionType = Enums.ActionType.M2,
	})
	
	-- Cancel movement AFTER sending attack for instant hit detection
	if wasDashing then
		DebugLogger.ClientAction("M2", "Cancelled Dash")
		self:_StopClientDash()
		self._networkManager:SendToServer(Enums.NetworkEvent.CancelDash, {})
	elseif wasSliding then
		DebugLogger.ClientAction("M2", "Cancelled Slide")
		self:_StopClientSlide()
		self._networkManager:SendToServer(Enums.NetworkEvent.CancelSlide, {})
	end
	
	Logger:Debug("Strong attack requested")
end

function CombatController:_HandleDash(direction: string)
	DebugLogger.ClientAction("_HandleDash", string.format("Direction: %s", direction))
	-- Check if can dash
	if not self:_CanPerformAction(Enums.ActionType.Q) then
		DebugLogger.ClientValidationFailed("Dash", "Cannot perform action")
		return
	end
	
	-- Update state using StateManager
	self._stateManager:HandleDashState()
	self._cooldowns[Enums.ActionType.Q] = os.clock()
	
	-- Play animation locally
	if self._animationManager then
		self._animationManager:PlayDashAnimation(direction)
	end
	
	-- Send to server (for validation/authority)
	self._networkManager:SendToServer(Enums.NetworkEvent.RequestDash, {
		Direction = direction,
	})
	
	-- Start client-side dynamic movement with real-time WASD control
	self:_StartClientDash()
	
	Logger:Debug("Dash requested", {direction = direction})
end

function CombatController:_HandleSlide(direction: string)
	DebugLogger.ClientAction("_HandleSlide", string.format("Direction: %s", direction))
	-- Check if can slide
	if not self:_CanPerformAction(Enums.ActionType.C) then
		DebugLogger.ClientValidationFailed("Slide", "Cannot perform action")
		return
	end
	
	-- Update state using StateManager
	self._stateManager:HandleSlideState()
	self._cooldowns[Enums.ActionType.C] = os.clock()
	
	-- Play animation locally
	if self._animationManager then
		self._animationManager:PlaySlideAnimation()
	end
	
	-- Send to server (for validation/authority)
	DebugLogger.ClientAction("Slide Request", "Sent to server")
	self._networkManager:SendToServer(Enums.NetworkEvent.RequestSlide, {
		Direction = direction,
	})
	
	-- Start client-side dynamic movement with real-time WASD control
	self:_StartClientSlide()
	
	Logger:Debug("Slide requested")
end

function CombatController:_HandleBlockStart()
	-- Check if can block
	if not self:_CanPerformAction(Enums.ActionType.F) then
		return
	end
	
	-- Update state using StateManager
	self._stateManager:HandleBlockStartState()
	
	-- Play animation locally
	if self._animationManager then
		self._animationManager:PlayBlockAnimation(true)
	end
	
	-- Send to server
	self._networkManager:SendToServer(Enums.NetworkEvent.RequestBlock, {
		IsBlocking = true,
	})
	
	Logger:Debug("Block started")
end

function CombatController:_HandleBlockEnd()
	-- Update state using StateManager
	self._stateManager:HandleBlockEndState()
	self._cooldowns[Enums.ActionType.F] = os.clock()
	
	-- Stop animation
	if self._animationManager then
		self._animationManager:PlayBlockAnimation(false)
	end
	
	-- Send to server
	self._networkManager:SendToServer(Enums.NetworkEvent.RequestBlock, {
		IsBlocking = false,
	})
	
	Logger:Debug("Block ended")
end

-- ========================================
-- SERVER CALLBACKS
-- ========================================

function CombatController:_OnServerStateChanged(newState: string)
	self._currentState = newState
	Logger:Debug("State changed by server", {state = newState})
	
	-- Block inputs based on state
	if newState == Enums.CombatState.Stunned or newState == Enums.CombatState.Dead then
		self._inputHandler:BlockAllInputs(true)
	else
		self._inputHandler:BlockAllInputs(false)
	end
end

function CombatController:_OnActionResult(result: {[string]: any})
	local success = result.Success
	local errorCode = result.ErrorCode
	
	if not success then
		Logger:Warning("Action rejected by server", {error = errorCode})
		
		-- Reset state on failure
		self._currentState = Enums.CombatState.Idle
	end
end

function CombatController:_OnTakeDamage(damageData: {[string]: any})
	-- Play hit animation
	if self._animationManager then
		self._animationManager:PlayHitAnimation()
	end
	
	-- Play VFX/SFX
	-- TODO: Implement visual effects
	
	Logger:Info("Took damage", {damage = damageData.Damage})
end

function CombatController:_OnApplyKnockback(knockbackData: {[string]: any})
	if not self.HumanoidRootPart then
		return
	end
	
	local direction = knockbackData.Direction
	local force = knockbackData.Force
	
	-- Apply knockback locally
	Utility.ApplyKnockback(self.Character, direction, force)
	
	Logger:Debug("Knockback applied", {force = force})
end

-- ========================================
-- VALIDATION
-- ========================================

function CombatController:_CanPerformAction(actionType: string): boolean
	-- Check if enabled
	if not self._enabled then
		DebugLogger.ClientValidationFailed(actionType, "System not enabled")
		return false
	end
	
	-- Check character validity
	if not Utility.IsCharacterValid(self.Character) then
		DebugLogger.ClientValidationFailed(actionType, "Invalid character")
		return false
	end
	
	-- Check state
	if self._currentState == Enums.CombatState.Stunned or self._currentState == Enums.CombatState.Dead then
		DebugLogger.ClientValidationFailed(actionType, string.format("Invalid state: %s", tostring(self._currentState)))
		return false
	end
	
	-- Check if already performing action (except block and M1 during combo)
	if actionType == Enums.ActionType.M1 then
		-- M1 can be used during Attacking state for combos, and can CANCEL Dash/Slide
		if self._currentState ~= Enums.CombatState.Idle 
			and self._currentState ~= Enums.CombatState.Attacking 
			and self._currentState ~= Enums.CombatState.Dashing
			and self._currentState ~= Enums.CombatState.Sliding then
			DebugLogger.ClientValidationFailed("M1", string.format("Invalid state: %s", tostring(self._currentState)))
			return false
		end
	elseif actionType == Enums.ActionType.M2 then
		-- M2 can CANCEL Dash/Slide
		if self._currentState ~= Enums.CombatState.Idle 
			and self._currentState ~= Enums.CombatState.Dashing
			and self._currentState ~= Enums.CombatState.Sliding then
			DebugLogger.ClientValidationFailed("M2", string.format("Invalid state: %s", tostring(self._currentState)))
			return false
		end
	elseif actionType ~= Enums.ActionType.F then
		if self._currentState ~= Enums.CombatState.Idle and self._currentState ~= Enums.CombatState.Blocking then
			DebugLogger.ClientValidationFailed(actionType, string.format("Invalid state: %s", tostring(self._currentState)))
			return false
		end
	end
	
	-- Check cooldown
	local cooldownConfig = self:_GetCooldownForAction(actionType)
	if not Utility.IsCooldownReady(self._cooldowns[actionType], cooldownConfig) then
		local remaining = Utility.GetCooldownRemaining(self._cooldowns[actionType], cooldownConfig)
		DebugLogger.ClientValidationFailed(actionType, string.format("On cooldown: %.1fs", remaining))
		return false
	end
	
	return true
end

function CombatController:_GetCooldownForAction(actionType: string): number
	if actionType == Enums.ActionType.M1 then
		return Config.LightAttack.Cooldown
	elseif actionType == Enums.ActionType.M2 then
		return Config.StrongAttack.Cooldown
	elseif actionType == Enums.ActionType.Q then
		return Config.Dash.Cooldown
	elseif actionType == Enums.ActionType.C then
		return Config.Slide.Cooldown
	elseif actionType == Enums.ActionType.F then
		return Config.Block.Cooldown
	end
	return 0
end

-- ========================================
-- UPDATE LOOP
-- ========================================

function CombatController:_StartUpdateLoop()
	RunService.Heartbeat:Connect(function(deltaTime)
		self:_Update(deltaTime)
	end)
end

function CombatController:_Update(_deltaTime: number)
	if not self._enabled then
		return
	end
	
	-- Process buffered inputs
	self:_ProcessBufferedInputs()
	
	-- Update combo window
	self:_UpdateComboWindow()
end

function CombatController:_ProcessBufferedInputs()
	if not self._inputBuffering:HasBufferedInputs() then
		return
	end
	
	-- Try to execute buffered input
	if self._currentState == Enums.CombatState.Idle then
		local bufferedInput = self._inputBuffering:GetNextInput()
		if bufferedInput and bufferedInput.ActionType == Enums.ActionType.M1 then
			self:_HandleLightAttack()
		end
	end
end

function CombatController:_UpdateComboWindow()
	local timeSinceLastAttack = os.clock() - self._lastAttackTime
	if timeSinceLastAttack > Config.LightAttack.ComboWindow and self._comboCount > 0 then
		self._comboCount = 0
		Logger:Debug("Combo reset")
	end
end

-- ========================================
-- STATE MANAGEMENT
-- ========================================

function CombatController:_ResetState()
	self._currentState = Enums.CombatState.Idle
	self._comboCount = 0
	self._lastAttackTime = 0
	
	-- Reset cooldowns
	for action in pairs(self._cooldowns) do
		self._cooldowns[action] = 0
	end
	
	-- Unblock inputs
	self._inputHandler:BlockAllInputs(false)
	
	-- Clear buffer
	self._inputBuffering:ClearBuffer()
	
	Logger:Debug("State reset")
end

-- ========================================
-- VISUAL EFFECTS
-- ========================================

-- Apply M2 charge visual effect (red body + white outline)
function CombatController:_ApplyM2ChargeEffect()
	local character = LocalPlayer.Character
	if not character then return end
	
	-- Remove existing highlight if any
	self:_RemoveM2ChargeEffect()
	
	-- Create Highlight effect
	local highlight = Instance.new("Highlight")
	highlight.Name = "M2ChargeEffect"
	highlight.FillColor = Color3.fromRGB(255, 50, 50) -- Red body
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255) -- White outline
	highlight.FillTransparency = 0.3 -- Slightly transparent red
	highlight.OutlineTransparency = 0 -- Solid white outline
	highlight.Adornee = character
	highlight.Parent = character
	
	-- Auto-remove after M2 duration
	task.delay(Config.StrongAttack.StunDuration + 0.3, function()
		self:_RemoveM2ChargeEffect()
	end)
end

function CombatController:_RemoveM2ChargeEffect()
	local character = LocalPlayer.Character
	if not character then return end
	
	local existingHighlight = character:FindFirstChild("M2ChargeEffect")
	if existingHighlight then
		existingHighlight:Destroy()
	end
end

-- ========================================
-- CLIENT-SIDE DYNAMIC MOVEMENT
-- ========================================

-- Get current WASD direction relative to camera
function CombatController:_GetCurrentInputDirection(): Vector3?
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

function CombatController:_StartClientDash()
	local character = LocalPlayer.Character
	if not character then return end
	
	local rootPart = Utility.GetRootPart(character)
	local humanoid = Utility.GetHumanoid(character)
	if not rootPart or not humanoid then return end
	
	-- Cancel existing dash
	self:_StopClientDash()
	
	-- Store initial direction from WASD
	local initialDirection = self:_GetCurrentInputDirection()
	if not initialDirection then
		initialDirection = rootPart.CFrame.LookVector -- Default to looking direction
	end
	
	-- Determine fixed direction type (front/back/left/right) from initial input
	local camera = workspace.CurrentCamera
	local cameraLook = camera.CFrame.LookVector
	local cameraRight = camera.CFrame.RightVector
	local dot = initialDirection:Dot(cameraLook)
	local dotRight = initialDirection:Dot(cameraRight)
	
	local fixedDirection = "front"
	if math.abs(dot) > math.abs(dotRight) then
		fixedDirection = dot > 0 and "front" or "back"
	else
		fixedDirection = dotRight > 0 and "right" or "left"
	end
	
	-- Disable humanoid movement
	humanoid.AutoRotate = false
	local originalWalkSpeed = humanoid.WalkSpeed
	humanoid.WalkSpeed = 0
	
	-- Create BodyVelocity for optimized dash (lighter than LinearVelocity)
	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.MaxForce = Vector3.new(100000, 0, 100000)
	bodyVelocity.Parent = rootPart
	
	-- Dash parameters with friction (similar to Slide)
	local dashStrength = Config.Dash.Speed
	local rate = 0.01
	local elapsed = 0
	
	-- Optimized loop with task.wait and friction
	local running = true
	self._activeDash = {
		bodyVelocity = bodyVelocity,
		humanoid = humanoid,
		originalWalkSpeed = originalWalkSpeed,
		running = running
	}
	
	task.spawn(function()
		while elapsed <= Config.Dash.Duration do
			if not self._activeDash or not self._activeDash.running or not rootPart or not rootPart.Parent then
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
				local progress = elapsed / Config.Dash.Duration
				local frictionMultiplier = 1 - (progress * Config.Dash.FrictionMultiplier)
				
				bodyVelocity.Velocity = velocityDirection * dashStrength * frictionMultiplier
			end
			
			elapsed = elapsed + rate
			task.wait(rate)
		end
		
		self:_StopClientDash()
	end)
	
	DebugLogger.ClientAction("Dash", string.format("Started - Direction: %s", fixedDirection))
end

function CombatController:_StopClientDash()
	if not self._activeDash then return end
	
	-- Stop loop
	self._activeDash.running = false
	
	-- Cleanup
	if self._activeDash.bodyVelocity and self._activeDash.bodyVelocity.Parent then
		self._activeDash.bodyVelocity:Destroy()
	end
	
	-- Restore humanoid
	if self._activeDash.humanoid then
		self._activeDash.humanoid.AutoRotate = true
		self._activeDash.humanoid.WalkSpeed = self._activeDash.originalWalkSpeed
	end
	
	self._activeDash = nil
end

function CombatController:_StartClientSlide()
	local character = LocalPlayer.Character
	if not character then return end
	
	local rootPart = Utility.GetRootPart(character)
	local humanoid = Utility.GetHumanoid(character)
	if not rootPart or not humanoid then return end
	
	-- Cancel existing slide
	self:_StopClientSlide()
	
	-- Store initial direction from WASD
	local initialDirection = self:_GetCurrentInputDirection()
	if not initialDirection then
		initialDirection = rootPart.CFrame.LookVector
	end
	
	-- Determine fixed direction type from initial input
	local camera = workspace.CurrentCamera
	local cameraLook = camera.CFrame.LookVector
	local cameraRight = camera.CFrame.RightVector
	local dot = initialDirection:Dot(cameraLook)
	local dotRight = initialDirection:Dot(cameraRight)
	
	local fixedDirection = "front"
	if math.abs(dot) > math.abs(dotRight) then
		fixedDirection = dot > 0 and "front" or "back"
	else
		fixedDirection = dotRight > 0 and "right" or "left"
	end
	
	-- Disable humanoid movement
	humanoid.AutoRotate = false
	local originalWalkSpeed = humanoid.WalkSpeed
	humanoid.WalkSpeed = 0
	
	-- Create BodyVelocity for optimized slide
	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.MaxForce = Vector3.new(100000, 0, 100000)
	bodyVelocity.Parent = rootPart
	
	-- Slide parameters with friction
	local slideStrength = Config.Slide.Speed
	local rate = 0.01
	
	local running = true
	self._activeSlide = {
		bodyVelocity = bodyVelocity,
		humanoid = humanoid,
		originalWalkSpeed = originalWalkSpeed,
		running = running
	}
	
	local elapsed = 0
	task.spawn(function()
		while elapsed <= Config.Slide.Duration do
			if not self._activeSlide or not self._activeSlide.running or not rootPart or not rootPart.Parent then
				break
			end
			
			-- Rotate character to match camera direction
			local forwardVector = workspace.CurrentCamera.CFrame.LookVector
			local targetRotation = math.atan2(forwardVector.X, forwardVector.Z) + math.pi
			rootPart.CFrame = CFrame.new(rootPart.Position) * CFrame.Angles(0, targetRotation, 0)
			
			-- Apply velocity with friction decay
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
				
				-- Apply friction based on progress
				local progress = elapsed / Config.Slide.Duration
				local frictionMultiplier = 1 - (progress * Config.Slide.FrictionMultiplier)
				
				bodyVelocity.Velocity = velocityDirection * slideStrength * frictionMultiplier
			end
			
			elapsed = elapsed + rate
			task.wait(rate)
		end
		
		self:_StopClientSlide()
	end)
	
	DebugLogger.ClientAction("Slide", string.format("Started - Direction: %s", fixedDirection))
end

function CombatController:_StopClientSlide()
	if not self._activeSlide then return end
	
	-- Stop loop
	self._activeSlide.running = false
	
	-- Cleanup
	if self._activeSlide.bodyVelocity and self._activeSlide.bodyVelocity.Parent then
		self._activeSlide.bodyVelocity:Destroy()
	end
	
	-- Restore humanoid
	if self._activeSlide.humanoid then
		self._activeSlide.humanoid.AutoRotate = true
		self._activeSlide.humanoid.WalkSpeed = self._activeSlide.originalWalkSpeed
	end
	
	self._activeSlide = nil
end

-- ========================================
-- PUBLIC API
-- ========================================

function CombatController:GetCurrentState(): string
	return self._currentState
end

function CombatController:GetComboCount(): number
	return self._comboCount
end

function CombatController:IsEnabled(): boolean
	return self._enabled
end

function CombatController:SetEnabled(enabled: boolean)
	self._enabled = enabled
	self._inputHandler:BlockAllInputs(not enabled)
	
	Logger:Info("CombatController enabled state changed", {enabled = enabled})
end

-- ========================================
-- CLEANUP
-- ========================================

function CombatController:Destroy()
	self._enabled = false
	
	if self._inputHandler then
		self._inputHandler:Destroy()
	end
	
	if self._inputBuffering then
		self._inputBuffering:Destroy()
	end
	
	if self._animationManager then
		self._animationManager:Destroy()
	end
	
	self.Character = nil
	self.Humanoid = nil
	self.HumanoidRootPart = nil
	
	Logger:Info("CombatController destroyed")
end

return CombatController
