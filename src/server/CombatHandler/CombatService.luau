--[[
	Module: CombatService
	Type: Server Main Service
	Location: ServerScriptService.CombatHandler.CombatService
	Path: src/server/CombatHandler/CombatService.luau
	
	Description:
		Main server-side service for the Combat System.
		Handles all combat actions with authoritative validation.
		Processes attacks, dashes, slides, blocks with anti-exploit checks.
		Manages player states, cooldowns, and synchronization with clients.
	
	Dependencies:
		- ReplicatedStorage.CombatCore.Core (Config, Enums, Types, Logger, Utility)
		- ReplicatedStorage.CombatCore.Network.NetworkManager
		- ServerScriptService.CombatService.PlayerDataManager
	
	Author: Professional Roblox Scripter
	Created: December 11, 2025
--]]

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- local RunService = game:GetService("RunService") -- Removed: Update loop disabled

-- Module Imports
local RS = ReplicatedStorage
local CombatSystem = RS:WaitForChild("CombatCore")
local Core = CombatSystem:WaitForChild("Core")

local Config = require(Core.Config)
local Enums = require(Core.Enums)
local Types = require(Core.Types)
local Logger = require(Core.Logger).GetInstance()
local DebugLogger = require(Core.DebugLogger)

local PlayerDataManager = require(script.Parent.PlayerDataManager).GetInstance()

-- Combat Service Class
local CombatService = {}
CombatService.__index = CombatService

-- Singleton Instance
local ServiceInstance: CombatService? = nil

-- ========================================
-- TYPES
-- ========================================

type CombatService = {
	_networkManager: any?,
	_mechanics: {[string]: any},
	_isInitialized: boolean,
	_activeTasks: {[Player]: {[string]: thread}},
	_connections: {RBXScriptConnection},
	_playerConnections: {[Player]: {RBXScriptConnection}},
}

-- ========================================
-- CONSTRUCTOR
-- ========================================

function CombatService.new(): CombatService
	local self = setmetatable({}, CombatService)
	
	self._networkManager = nil
	self._mechanics = {}
	self._isInitialized = false
	self._activeTasks = {} -- Track active task.delay calls per player
	self._connections = {} -- Track global event connections
	self._playerConnections = {} -- Track per-player event connections
	
	Logger:Info("CombatService created")
	
	return self
end

-- ========================================
-- SINGLETON
-- ========================================

function CombatService.GetInstance(): CombatService
	if not ServiceInstance then
		ServiceInstance = CombatService.new()
	end
	return ServiceInstance
end

-- ========================================
-- INITIALIZATION
-- ========================================

function CombatService:Initialize()
	if self._isInitialized then
		Logger:Warning("CombatService already initialized")
		return
	end
	
	-- Initialize network manager
	self:_InitializeNetworkManager()
	
	-- Load combat mechanics
	self:_LoadMechanics()
	
	-- Setup player connections
	self:_SetupPlayerConnections()
	
	-- Start update loop
	-- self:_StartUpdateLoop() -- Disabled: Empty update loop causing unnecessary overhead
	
	self._isInitialized = true
	
	Logger:Info("CombatService initialized successfully")
end

-- ========================================
-- NETWORK MANAGER SETUP
-- ========================================

function CombatService:_InitializeNetworkManager()
	local networkModule = CombatSystem:WaitForChild("Network"):WaitForChild("NetworkManager")
	local NetworkManager = require(networkModule)
	
	self._networkManager = NetworkManager.GetServerInstance()
	
	-- Register client request handlers
	self._networkManager:RegisterHandler(Enums.NetworkEvent.RequestAction, function(player, data)
		return self:_HandleActionRequest(player, data)
	end)
	
	self._networkManager:RegisterHandler(Enums.NetworkEvent.RequestBlock, function(player, data)
		return self:_HandleBlockRequest(player, data)
	end)
	
	self._networkManager:RegisterHandler(Enums.NetworkEvent.RequestDash, function(player, data)
		return self:_HandleDashRequest(player, data)
	end)
	
	self._networkManager:RegisterHandler(Enums.NetworkEvent.RequestSlide, function(player, data)
		return self:_HandleSlideRequest(player, data)
	end)
	
	self._networkManager:RegisterHandler(Enums.NetworkEvent.CancelDash, function(player, _data)
		return self:_HandleCancelDash(player)
	end)
	
	self._networkManager:RegisterHandler(Enums.NetworkEvent.CancelSlide, function(player, _data)
		return self:_HandleCancelSlide(player)
	end)
	
	-- Logger:Debug("NetworkManager initialized") -- Removed: Hot path optimization
end

-- ========================================
-- MECHANICS LOADING
-- ========================================

function CombatService:_LoadMechanics()
	-- Wait for mechanics folder
	local mechanicsFolder = CombatSystem:WaitForChild("Mechanics")
	
	-- Load each mechanic module
	local mechanicModules = {
		LightAttack = mechanicsFolder:WaitForChild("LightAttack"),
		StrongAttack = mechanicsFolder:WaitForChild("StrongAttack"),
		Dash = mechanicsFolder:WaitForChild("Dash"),
		Slide = mechanicsFolder:WaitForChild("Slide"),
	}
	
	for name, module in pairs(mechanicModules) do
		self._mechanics[name] = require(module)
		-- Logger:Debug("Mechanic loaded", {mechanic = name}) -- Removed: Loop optimization
	end
	
	Logger:Info("All mechanics loaded")
end

-- ========================================
-- PLAYER CONNECTIONS
-- ========================================

function CombatService:_SetupPlayerConnections()
	-- Handle existing players
	for _, player in ipairs(Players:GetPlayers()) do
		self:_OnPlayerAdded(player)
	end
	
	-- Handle new players
	local playerAddedConnection = Players.PlayerAdded:Connect(function(player)
		self:_OnPlayerAdded(player)
	end)
	table.insert(self._connections, playerAddedConnection)
	
	-- Handle leaving players
	local playerRemovingConnection = Players.PlayerRemoving:Connect(function(player)
		self:_OnPlayerRemoving(player)
	end)
	table.insert(self._connections, playerRemovingConnection)
end

function CombatService:_OnPlayerAdded(player: Player)
	-- Wait for character
	if player.Character then
		self:_OnCharacterAdded(player, player.Character)
	end
	
	-- Track player-specific connections
	if not self._playerConnections[player] then
		self._playerConnections[player] = {}
	end
	
	local characterAddedConnection = player.CharacterAdded:Connect(function(character)
		self:_OnCharacterAdded(player, character)
	end)
	table.insert(self._playerConnections[player], characterAddedConnection)
	
	Logger:Info("Player added to combat service", {player = player.Name})
end

function CombatService:_OnCharacterAdded(player: Player, character: Model)
	-- Create or update player data
	if PlayerDataManager:GetPlayerData(player) then
		PlayerDataManager:UpdateCharacterReferences(player, character)
	else
		PlayerDataManager:CreatePlayerData(player)
	end
	
	-- Listen for death
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		if not self._playerConnections[player] then
			self._playerConnections[player] = {}
		end
		
		local diedConnection = humanoid.Died:Connect(function()
			self:_OnCharacterDied(player)
		end)
		table.insert(self._playerConnections[player], diedConnection)
	end
	
	Logger:Info("Character added to combat service", {player = player.Name})
end

function CombatService:_OnCharacterDied(player: Player)
	-- Cancel active tasks on death
	self:_CancelPlayerTasks(player)
	
	PlayerDataManager:SetPlayerState(player, Enums.CombatState.Dead)
	PlayerDataManager:ResetCombo(player)
	
	Logger:Info("Character died", {player = player.Name})
end

function CombatService:_OnPlayerRemoving(player: Player)
	-- Disconnect player-specific connections
	if self._playerConnections[player] then
		for _, connection in ipairs(self._playerConnections[player]) do
			connection:Disconnect()
		end
		self._playerConnections[player] = nil
	end
	
	-- Cancel active tasks
	self:_CancelPlayerTasks(player)
	
	-- Remove player data
	PlayerDataManager:RemovePlayerData(player)
	
	Logger:Info("Player removed from combat service", {player = player.Name})
end

-- ========================================
-- ACTION REQUEST HANDLERS
-- ========================================

function CombatService:_HandleActionRequest(player: Player, data: {[string]: any}): {[string]: any}
	local actionType = data.ActionType
	DebugLogger.ServerRequest(player.Name, "ActionRequest", actionType)
	
	-- Route to appropriate handler (validation done in _ValidateAction)
	if actionType == Enums.ActionType.M1 then
		return self:_ProcessLightAttack(player, data)
	elseif actionType == Enums.ActionType.M2 then
		return self:_ProcessStrongAttack(player, data)
	end
	
	return {Success = false, ErrorCode = "INVALID_ACTION"}
end

function CombatService:_HandleBlockRequest(player: Player, data: {[string]: any}): {[string]: any}
	return self:_ProcessBlock(player, data)
end

function CombatService:_HandleDashRequest(player: Player, data: {[string]: any}): {[string]: any}
	return self:_ProcessDash(player, data)
end

function CombatService:_HandleSlideRequest(player: Player, data: {[string]: any}): {[string]: any}
	return self:_ProcessSlide(player, data)
end

-- ========================================
-- TASK MANAGEMENT HELPERS
-- ========================================

-- Schedule state transition after delay with automatic cleanup
function CombatService:_ScheduleStateTransition(player: Player, targetState: string, delay: number, fromState: string?)
	local taskId = tostring(player.UserId) .. "_" .. targetState .. "_" .. os.clock()
	
	local thread = task.delay(delay, function()
		-- Remove from tracking
		if self._activeTasks[player] then
			self._activeTasks[player][taskId] = nil
		end
		
		-- Only transition if player still in expected state (or no specific state required)
		local currentState = PlayerDataManager:GetPlayerState(player)
		if not fromState or currentState == fromState then
			if PlayerDataManager:ValidatePlayerData(player) then
				PlayerDataManager:SetPlayerState(player, targetState)
			end
		end
	end)
	
	-- Track task for cleanup
	if not self._activeTasks[player] then
		self._activeTasks[player] = {}
	end
	self._activeTasks[player][taskId] = thread
end

-- Cancel all active tasks for a player
function CombatService:_CancelPlayerTasks(player: Player)
	local tasks = self._activeTasks[player]
	if not tasks then return end
	
	for _, thread in pairs(tasks) do
		task.cancel(thread)
	end
	
	self._activeTasks[player] = nil
end

-- ========================================
-- LIGHT ATTACK PROCESSING
-- ========================================

function CombatService:_ProcessLightAttack(player: Player, data: {[string]: any}): {[string]: any}
	-- Validate state
	local validationResult = self:_ValidateAction(player, Enums.ActionType.M1)
	if not validationResult.Success then
		return validationResult
	end
	
	-- Update player state
	PlayerDataManager:SetPlayerState(player, Enums.CombatState.Attacking)
	-- Cooldown activates IMMEDIATELY (general cooldown, independent of hit/miss)
	PlayerDataManager:SetCooldown(player, Enums.ActionType.M1, os.clock())
	
	-- Check if attack cancelled movement
	local cancelledMovement = data.CancelledMovement or false
	if cancelledMovement then
		DebugLogger.ServerMechanicExecution("LightAttack", player.Name, "Cancelled movement for attack")
	end
	
	-- Handle combo (server is authoritative, client ComboCount is for reference only)
	local playerData = PlayerDataManager:GetPlayerData(player)
	local timeSinceLastAttack = os.clock() - (playerData.LastAttackTime or 0)
	
	-- Check if combo window is still active
	if timeSinceLastAttack > Config.LightAttack.ComboWindow then
		PlayerDataManager:ResetCombo(player)
	end
	
	-- Increment combo
	PlayerDataManager:IncrementCombo(player, Config.LightAttack.MaxComboCount)
	local comboCount = PlayerDataManager:GetComboCount(player)
	
	-- Execute attack mechanic
	local mechanic = self._mechanics.LightAttack
	if mechanic then
		DebugLogger.ServerMechanicExecution("LightAttack", player.Name, string.format("Combo: %d", comboCount))
		mechanic:Execute(player, {ComboCount = comboCount})
	else
		Logger:Error("LightAttack mechanic not loaded", {player = player.Name})
	end
	
	-- Check if this was the finisher (6th hit)
	if comboCount == 6 then
		DebugLogger.ServerMechanicExecution("LightAttack", player.Name, "Finisher reached - Extended cooldown")
		-- Apply longer cooldown for finisher
		PlayerDataManager:SetCooldown(player, Enums.ActionType.M1, os.clock() + (Config.LightAttack.FinisherCooldown - Config.LightAttack.Cooldown))
		-- Reset combo after finisher
		PlayerDataManager:ResetCombo(player)
	end
	
	-- Return to idle after animation (80% of cooldown for smooth combo flow)
	local animationDuration = Config.LightAttack.Cooldown * 0.8
	self:_ScheduleStateTransition(player, Enums.CombatState.Idle, animationDuration, Enums.CombatState.Attacking)
	
	-- Logger:Debug("Light attack processed", {player = player.Name, combo = comboCount}) -- Removed: Hot path
	
	return {Success = true, ComboCount = comboCount}
end

-- ========================================
-- STRONG ATTACK PROCESSING
-- ========================================

function CombatService:_ProcessStrongAttack(player: Player, _data: {[string]: any}): {[string]: any}
	DebugLogger.ServerRequest(player.Name, "StrongAttack", "Instant")
	-- Validate state
	local validationResult = self:_ValidateAction(player, Enums.ActionType.M2)
	if not validationResult.Success then
		DebugLogger.ServerValidationFailed(player.Name, "StrongAttack", validationResult.ErrorMessage or "Unknown")
		return validationResult
	end
	
	-- Check if attack cancelled movement
	local cancelledMovement = _data.CancelledMovement or false
	if cancelledMovement then
		DebugLogger.ServerMechanicExecution("StrongAttack", player.Name, "Cancelled movement for attack")
	end
	
	-- Update player state
	PlayerDataManager:SetPlayerState(player, Enums.CombatState.Attacking)
	-- Cooldown activates IMMEDIATELY (general cooldown, independent of hit/miss)
	PlayerDataManager:SetCooldown(player, Enums.ActionType.M2, os.clock())
	PlayerDataManager:ResetCombo(player)
	
	-- Execute attack mechanic (instant attack, no charge)
	local mechanic = self._mechanics.StrongAttack
	if mechanic then
		DebugLogger.ServerMechanicExecution("StrongAttack", player.Name, "Executing instant attack")
		mechanic:Execute(player, {})
	else
		Logger:Error("StrongAttack mechanic not loaded", {player = player.Name})
	end
	
	-- Return to idle after animation (StunDuration + buffer)
	self:_ScheduleStateTransition(player, Enums.CombatState.Idle, Config.StrongAttack.StunDuration + 0.3, Enums.CombatState.Attacking)
	
	-- Logger:Debug("Strong attack processed", {player = player.Name}) -- Removed: Hot path
	
	return {Success = true}
end

-- ========================================
-- DASH PROCESSING
-- ========================================

function CombatService:_ProcessDash(player: Player, data: {[string]: any}): {[string]: any}
	-- Validate state
	local validationResult = self:_ValidateAction(player, Enums.ActionType.Q)
	if not validationResult.Success then
		return validationResult
	end
	
	-- Update player state
	PlayerDataManager:SetPlayerState(player, Enums.CombatState.Dashing)
	PlayerDataManager:SetCooldown(player, Enums.ActionType.Q, os.clock())
	
	-- Enable invulnerability frames
	PlayerDataManager:SetInvulnerable(player, true)
	
	-- Execute dash mechanic
	local mechanic = self._mechanics.Dash
	if mechanic then
		mechanic:Execute(player, {Direction = data.Direction})
	else
		Logger:Error("Dash mechanic not loaded", {player = player.Name})
	end
	
	-- Schedule invulnerability removal
	local invulnThread = task.delay(Config.Dash.InvulnerabilityFrames, function()
		PlayerDataManager:SetInvulnerable(player, false)
	end)
	
	-- Track invulnerability task
	if not self._activeTasks[player] then
		self._activeTasks[player] = {}
	end
	self._activeTasks[player]["invuln_" .. os.clock()] = invulnThread
	
	-- Return to idle after dash
	self:_ScheduleStateTransition(player, Enums.CombatState.Idle, Config.Dash.Duration, Enums.CombatState.Dashing)
	
	-- Logger:Debug("Dash processed", {player = player.Name, direction = data.Direction}) -- Removed: Hot path
	
	return {Success = true}
end

-- ========================================
-- SLIDE PROCESSING
-- ========================================

function CombatService:_ProcessSlide(player: Player, data: {[string]: any}): {[string]: any}
	DebugLogger.ServerRequest(player.Name, "Slide", data.Direction or "Forward")
	-- Validate state
	local validationResult = self:_ValidateAction(player, Enums.ActionType.C)
	if not validationResult.Success then
		DebugLogger.ServerValidationFailed(player.Name, "Slide", validationResult.ErrorMessage or "Unknown")
		return validationResult
	end
	
	-- Update player state
	PlayerDataManager:SetPlayerState(player, Enums.CombatState.Sliding)
	PlayerDataManager:SetCooldown(player, Enums.ActionType.C, os.clock())
	
	-- Execute slide mechanic
	local mechanic = self._mechanics.Slide
	if mechanic then
		DebugLogger.ServerMechanicExecution("Slide", player.Name, "Executing")
		mechanic:Execute(player, {Direction = data.Direction})
	else
		Logger:Error("Slide mechanic not loaded", {player = player.Name})
	end
	
	-- Return to idle after slide
	self:_ScheduleStateTransition(player, Enums.CombatState.Idle, Config.Slide.Duration, Enums.CombatState.Sliding)
	
	-- Logger:Debug("Slide processed", {player = player.Name}) -- Removed: Hot path
	
	return {Success = true}
end

-- ========================================
-- DASH/SLIDE CANCELLATION
-- ========================================

function CombatService:_HandleCancelDash(player: Player): {[string]: any}
	DebugLogger.ServerRequest(player.Name, "CancelDash", nil)
	
	-- Cancel active dash via mechanic
	local mechanic = self._mechanics.Dash
	if mechanic and mechanic.CancelDash then
		mechanic:CancelDash(player)
		DebugLogger.ServerMechanicExecution("Dash", player.Name, "Cancelled")
	end
	
	return {Success = true}
end

function CombatService:_HandleCancelSlide(player: Player): {[string]: any}
	DebugLogger.ServerRequest(player.Name, "CancelSlide", nil)
	
	-- Cancel active slide via mechanic
	local mechanic = self._mechanics.Slide
	if mechanic and mechanic.CancelSlide then
		mechanic:CancelSlide(player)
		DebugLogger.ServerMechanicExecution("Slide", player.Name, "Cancelled")
	end
	
	return {Success = true}
end

-- ========================================
-- BLOCK PROCESSING
-- ========================================

function CombatService:_ProcessBlock(player: Player, data: {[string]: any}): {[string]: any}
	local isBlocking = data.IsBlocking
	
	-- Validate player
	if not PlayerDataManager:ValidatePlayerData(player) then
		return {Success = false, ErrorCode = "INVALID_PLAYER"}
	end
	
	-- Check if stunned
	if PlayerDataManager:IsStunned(player) then
		return {Success = false, ErrorCode = "STUNNED"}
	end
	
	-- Update blocking state
	PlayerDataManager:SetBlocking(player, isBlocking)
	
	-- Sync with client
	self._networkManager:SendToClient(player, Enums.NetworkEvent.StateChanged, {
		State = isBlocking and Enums.CombatState.Blocking or Enums.CombatState.Idle
	})
	
	-- Logger:Debug("Block processed", {player = player.Name, blocking = isBlocking}) -- Removed: Hot path
	
	return {Success = true}
end

-- ========================================
-- VALIDATION
-- ========================================

function CombatService:_ValidateAction(player: Player, actionType: string): Types.ValidationResult
	-- Validate player data
	if not PlayerDataManager:ValidatePlayerData(player) then
		return {Success = false, ErrorMessage = "Invalid player data", ErrorCode = "INVALID_PLAYER"}
	end
	
	-- Check state
	local currentState = PlayerDataManager:GetPlayerState(player)
	if currentState == Enums.CombatState.Stunned then
		return {Success = false, ErrorMessage = "Player is stunned", ErrorCode = "STUNNED"}
	end
	
	if currentState == Enums.CombatState.Dead then
		return {Success = false, ErrorMessage = "Player is dead", ErrorCode = "DEAD"}
	end
	
	-- Check if already performing action
	if actionType == Enums.ActionType.M1 then
		-- M1 allowed during: Idle, Blocking, Attacking (combos), Dashing (cancel), Sliding (cancel)
		if currentState ~= Enums.CombatState.Idle 
			and currentState ~= Enums.CombatState.Blocking 
			and currentState ~= Enums.CombatState.Attacking
			and currentState ~= Enums.CombatState.Dashing
			and currentState ~= Enums.CombatState.Sliding then
			return {Success = false, ErrorMessage = "Already performing action", ErrorCode = "BUSY"}
		end
	elseif actionType == Enums.ActionType.M2 then
		-- M2 allowed during: Idle, Blocking, Dashing (cancel), Sliding (cancel)
		if currentState ~= Enums.CombatState.Idle 
			and currentState ~= Enums.CombatState.Blocking
			and currentState ~= Enums.CombatState.Dashing
			and currentState ~= Enums.CombatState.Sliding then
			return {Success = false, ErrorMessage = "Already performing action", ErrorCode = "BUSY"}
		end
	else
		-- Other actions only allowed during Idle or Blocking
		if currentState ~= Enums.CombatState.Idle and currentState ~= Enums.CombatState.Blocking then
			return {Success = false, ErrorMessage = "Already performing action", ErrorCode = "BUSY"}
		end
	end
	
	-- Check cooldown
	local cooldownDuration = self:_GetCooldownDuration(actionType)
	if not PlayerDataManager:IsCooldownReady(player, actionType, cooldownDuration) then
		local remaining = PlayerDataManager:GetCooldownRemaining(player, actionType, cooldownDuration)
		return {
			Success = false,
			ErrorMessage = string.format("Cooldown not ready: %.2fs remaining", remaining),
			ErrorCode = "ON_COOLDOWN"
		}
	end
	
	return {Success = true}
end

function CombatService:_GetCooldownDuration(actionType: string): number
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
-- Note: Stun checks are already handled via task.delay in SetStunned()
-- This loop is kept for future extensions (stamina regen, combo timeout, etc.)

-- Disabled: Empty update loop causing unnecessary overhead (60 FPS server-side)
-- Re-enable when implementing stamina regeneration, combo timeouts, or status effect ticks
--[[
function CombatService:_StartUpdateLoop()
	local heartbeatConnection = RunService.Heartbeat:Connect(function(deltaTime)
		self:_Update(deltaTime)
	end)
	table.insert(self._connections, heartbeatConnection)
end

function CombatService:_Update(_deltaTime: number)
	-- Reserved for future continuous updates:
	-- - Stamina regeneration
	-- - Combo timeout checks
	-- - Status effect ticks
end
--]]

-- ========================================
-- CLEANUP
-- ========================================

function CombatService:Destroy()
	self._isInitialized = false
	
	-- Disconnect all global connections
	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end
	table.clear(self._connections)
	
	-- Disconnect all player-specific connections
	for _, connections in pairs(self._playerConnections) do
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
	end
	table.clear(self._playerConnections)
	
	-- Cancel all active tasks
	for player, _ in pairs(self._activeTasks) do
		self:_CancelPlayerTasks(player)
	end
	
	Logger:Info("CombatService destroyed")
end

-- ========================================
-- PUBLIC API
-- ========================================

function CombatService:ApplyDamage(attacker: Player, victim: Player | Model, damage: number): Types.HitData?
	-- Validate attacker
	if not attacker or not attacker:IsA("Player") then
		Logger:Warning("Invalid attacker in ApplyDamage")
		return nil
	end
	
	-- Support for both Players and NPCs/Dummies
	local isPlayer = typeof(victim) == "Instance" and victim:IsA("Player")
	local victimCharacter = if isPlayer then victim.Character else victim
	local victimHumanoid = if victimCharacter then victimCharacter:FindFirstChildOfClass("Humanoid") else nil
	local victimRoot = if victimCharacter then victimCharacter:FindFirstChild("HumanoidRootPart") else nil
	
	if not victimHumanoid or not victimRoot then
		Logger:Debug("Invalid victim - no humanoid or root part")
		return nil
	end
	
	-- Check invulnerability (only for players)
	if isPlayer and PlayerDataManager:IsInvulnerable(victim) then
		Logger:Debug("Damage blocked by invulnerability", {victim = victim.Name})
		return nil
	end
	
	-- Check blocking (only for players)
	local actualDamage = damage
	local hitResult = Enums.HitResult.Success
	
	if isPlayer and PlayerDataManager:IsBlocking(victim) then
		-- Check for perfect block
		local blockDuration = PlayerDataManager:GetBlockDuration(victim)
		if blockDuration <= Config.Block.PerfectBlockWindow then
			actualDamage = damage * (1 - Config.Block.PerfectBlockReduction)
			hitResult = Enums.HitResult.PerfectBlock
		else
			actualDamage = damage * (1 - Config.Block.DamageReduction)
			hitResult = Enums.HitResult.Blocked
		end
	end
	
	-- Apply damage
	victimHumanoid:TakeDamage(actualDamage)
	
	-- Create hit data
	local hitData: Types.HitData = {
		Attacker = attacker,
		Victim = victim,
		Damage = damage,
		ActualDamage = actualDamage,
		Knockback = Vector3.new(0, 0, 0), -- Will be set by mechanic
		HitResult = hitResult,
		HitPosition = victimRoot.Position,
		Timestamp = os.clock(),
	}
	
	-- Notify client (only for players)
	if isPlayer then
		self._networkManager:SendToClient(victim, Enums.NetworkEvent.TakeDamage, {
			Damage = actualDamage,
			Attacker = attacker.Name,
			HitResult = hitResult,
		})
	end
	
	local victimName = if isPlayer then victim.Name else victimCharacter.Name
	Logger:Info("Damage applied", {
		attacker = attacker.Name,
		victim = victimName,
		damage = actualDamage,
		result = hitResult,
		isNPC = not isPlayer
	})
	
	return hitData
end

return CombatService
