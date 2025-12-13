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
local RunService = game:GetService("RunService")

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
}

-- ========================================
-- CONSTRUCTOR
-- ========================================

function CombatService.new(): CombatService
	local self = setmetatable({}, CombatService)
	
	self._networkManager = nil
	self._mechanics = {}
	self._isInitialized = false
	
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
	self:_StartUpdateLoop()
	
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
	
	Logger:Debug("NetworkManager initialized")
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
		Logger:Debug("Mechanic loaded", {mechanic = name})
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
	Players.PlayerAdded:Connect(function(player)
		self:_OnPlayerAdded(player)
	end)
	
	-- Handle leaving players
	Players.PlayerRemoving:Connect(function(player)
		self:_OnPlayerRemoving(player)
	end)
end

function CombatService:_OnPlayerAdded(player: Player)
	-- Wait for character
	if player.Character then
		self:_OnCharacterAdded(player, player.Character)
	end
	
	player.CharacterAdded:Connect(function(character)
		self:_OnCharacterAdded(player, character)
	end)
	
	Logger:Info("Player added to combat service", {player = player.Name})
end

function CombatService:_OnCharacterAdded(player: Player, character: Model)
	-- Create or update player data
	if PlayerDataManager:HasPlayerData(player) then
		PlayerDataManager:UpdateCharacterReferences(player, character)
	else
		PlayerDataManager:CreatePlayerData(player)
	end
	
	-- Listen for death
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Died:Connect(function()
			self:_OnCharacterDied(player)
		end)
	end
	
	Logger:Info("Character added to combat service", {player = player.Name})
end

function CombatService:_OnCharacterDied(player: Player)
	PlayerDataManager:SetPlayerState(player, Enums.CombatState.Dead)
	PlayerDataManager:ResetCombo(player)
	
	Logger:Info("Character died", {player = player.Name})
end

function CombatService:_OnPlayerRemoving(player: Player)
	PlayerDataManager:RemovePlayerData(player)
	
	Logger:Info("Player removed from combat service", {player = player.Name})
end

-- ========================================
-- ACTION REQUEST HANDLERS
-- ========================================

function CombatService:_HandleActionRequest(player: Player, data: {[string]: any}): {[string]: any}
	local actionType = data.ActionType
	DebugLogger.ServerRequest(player.Name, "ActionRequest", actionType)
	
	-- Validate player
	if not PlayerDataManager:ValidatePlayerData(player) then
		DebugLogger.ServerValidationFailed(player.Name, actionType, "Invalid player data")
		return {Success = false, ErrorCode = "INVALID_PLAYER"}
	end
	
	-- Route to appropriate handler
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
	
	-- Handle combo
	local comboCount = data.ComboCount or 1
	local timeSinceLastAttack = os.clock() - (PlayerDataManager:GetPlayerData(player).LastAttackTime or 0)
	
	if timeSinceLastAttack <= Config.LightAttack.ComboWindow then
		PlayerDataManager:IncrementCombo(player, Config.LightAttack.MaxComboCount)
	else
		PlayerDataManager:ResetCombo(player)
		PlayerDataManager:IncrementCombo(player, Config.LightAttack.MaxComboCount)
	end
	
	comboCount = PlayerDataManager:GetComboCount(player)
	
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
	task.delay(animationDuration, function()
		if PlayerDataManager:GetPlayerState(player) == Enums.CombatState.Attacking then
			PlayerDataManager:SetPlayerState(player, Enums.CombatState.Idle)
		end
	end)
	
	Logger:Debug("Light attack processed", {player = player.Name, combo = comboCount})
	
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
	task.delay(Config.StrongAttack.StunDuration + 0.3, function()
		if PlayerDataManager:GetPlayerState(player) == Enums.CombatState.Attacking then
			PlayerDataManager:SetPlayerState(player, Enums.CombatState.Idle)
		end
	end)
	
	Logger:Debug("Strong attack processed", {player = player.Name})
	
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
	end
	
	-- Remove invulnerability and return to idle
	task.delay(Config.Dash.InvulnerabilityFrames, function()
		PlayerDataManager:SetInvulnerable(player, false)
	end)
	
	task.delay(Config.Dash.Duration, function()
		if PlayerDataManager:GetPlayerState(player) == Enums.CombatState.Dashing then
			PlayerDataManager:SetPlayerState(player, Enums.CombatState.Idle)
		end
	end)
	
	Logger:Debug("Dash processed", {player = player.Name, direction = data.Direction})
	
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
	task.delay(Config.Slide.Duration, function()
		if PlayerDataManager:GetPlayerState(player) == Enums.CombatState.Sliding then
			PlayerDataManager:SetPlayerState(player, Enums.CombatState.Idle)
		end
	end)
	
	Logger:Debug("Slide processed", {player = player.Name})
	
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
	
	Logger:Debug("Block processed", {player = player.Name, blocking = isBlocking})
	
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
	
	-- Check if already performing action (M1 can combo during Attacking)
	if actionType == Enums.ActionType.M1 then
		-- M1 allowed during Idle, Blocking, or Attacking (for combos)
		if currentState ~= Enums.CombatState.Idle and currentState ~= Enums.CombatState.Blocking and currentState ~= Enums.CombatState.Attacking then
			return {Success = false, ErrorMessage = "Already performing action", ErrorCode = "BUSY"}
		end
	else
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

function CombatService:_StartUpdateLoop()
	RunService.Heartbeat:Connect(function(deltaTime)
		self:_Update(deltaTime)
	end)
end

function CombatService:_Update(_deltaTime: number)
	-- Update stuns
	for player, data in pairs(PlayerDataManager:GetAllPlayerData()) do
		if data.IsStunned and data.StunEndTime and os.clock() >= data.StunEndTime then
			PlayerDataManager:SetStunned(player, false)
		end
	end
end

-- ========================================
-- PUBLIC API
-- ========================================

function CombatService:ApplyDamage(attacker: Player, victim: Player | Model, damage: number): Types.HitData?
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
