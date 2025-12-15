--[[
	Module: CombatService
	Type: Server Main Service
	Location: ServerScriptService.CombatHandler.CombatService
	Path: src/server/CombatHandler/CombatService.luau
	
	Description:
		Main server-side orchestration service for the Combat System.
		Manages initialization, player lifecycle, and request routing.
		Delegates action processing to ActionProcessor and damage calculations to DamageCalculator.
		Provides authoritative validation and synchronization with clients.
		
		Refactored: December 13, 2025 - Separated responsibilities into specialized modules
	
	Dependencies:
		- ReplicatedStorage.CombatCore.Core (Config, Enums, Types, Logger)
		- ReplicatedStorage.CombatCore.Network.NetworkManager
		- ServerScriptService.CombatHandler.PlayerDataManager
		- ServerScriptService.CombatHandler.ActionProcessor
		- ServerScriptService.CombatHandler.DamageCalculator
	
	Author: Professional Roblox Scripter
	Created: December 11, 2025
	Updated: December 13, 2025
--]]

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

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
local ActionProcessorModule = require(script.Parent.ActionProcessor)
local DamageCalculator = require(script.Parent.DamageCalculator)

-- NPCCombatHelper is in Testing folder (testing utilities, not core system)
local Testing = ServerScriptService:WaitForChild("Testing")
local NPCCombatHelper = require(Testing:WaitForChild("NPCCombatHelper"))

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
	_actionProcessor: any?,
	_isInitialized: boolean,
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
	self._actionProcessor = ActionProcessorModule.new()
	self._isInitialized = false
	self._connections = {} -- Track global event connections
	self._playerConnections = {} -- Track per-player event connections
	
	Logger:Info("CombatService created with ActionProcessor")
	
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
	end
	
	-- Pass mechanics to ActionProcessor
	self._actionProcessor:SetMechanics(self._mechanics)
	
	-- Initialize NPC Combat Helper
	NPCCombatHelper.Initialize(self._mechanics)
	
	Logger:Info("All mechanics loaded and configured (Players + NPCs)")
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
	-- Cancel active tasks on death via ActionProcessor
	self._actionProcessor:CancelPlayerTasks(player)
	
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
	
	-- Cancel active tasks via ActionProcessor
	self._actionProcessor:CancelPlayerTasks(player)
	
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
	
	-- Validate action first
	local validationResult = self:_ValidateAction(player, actionType)
	if not validationResult.Success then
		return validationResult
	end
	
	-- Route to ActionProcessor
	if actionType == Enums.ActionType.M1 then
		return self._actionProcessor:ProcessLightAttack(player, data)
	elseif actionType == Enums.ActionType.M2 then
		return self._actionProcessor:ProcessStrongAttack(player, data)
	end
	
	return {Success = false, ErrorCode = "INVALID_ACTION"}
end

function CombatService:_HandleBlockRequest(player: Player, data: {[string]: any}): {[string]: any}
	return self._actionProcessor:ProcessBlock(player, data, self._networkManager)
end

function CombatService:_HandleDashRequest(player: Player, data: {[string]: any}): {[string]: any}
	-- Validate action first
	local validationResult = self:_ValidateAction(player, Enums.ActionType.Q)
	if not validationResult.Success then
		return validationResult
	end
	
	return self._actionProcessor:ProcessDash(player, data)
end

function CombatService:_HandleSlideRequest(player: Player, data: {[string]: any}): {[string]: any}
	-- Validate action first
	local validationResult = self:_ValidateAction(player, Enums.ActionType.C)
	if not validationResult.Success then
		DebugLogger.ServerValidationFailed(player.Name, "Slide", validationResult.ErrorMessage or "Unknown")
		return validationResult
	end
	
	return self._actionProcessor:ProcessSlide(player, data)
end

-- ========================================
-- DASH/SLIDE CANCELLATION
-- ========================================

function CombatService:_HandleCancelDash(player: Player): {[string]: any}
	return self._actionProcessor:HandleCancelDash(player)
end

function CombatService:_HandleCancelSlide(player: Player): {[string]: any}
	return self._actionProcessor:HandleCancelSlide(player)
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
	
	-- Check if victim is ragdolled (invulnerable during ragdoll)
	local Utility = require(game.ReplicatedStorage.CombatCore.Core.Utility)
	if Utility.IsRagdolled(victimCharacter) then
		local victimName = if isPlayer then victim.Name else victimCharacter.Name
		Logger:Debug("Damage blocked - victim is ragdolled", {victim = victimName})
		return nil
	end
	
	-- Check blocking and apply damage reduction (for both players and NPCs)
	local actualDamage = damage
	local hitResult = Enums.HitResult.Success
	local isBlocking = false
	
	if isPlayer then
		isBlocking = PlayerDataManager:IsBlocking(victim)
		actualDamage = DamageCalculator.ApplyBlockReduction(damage, isBlocking)
		
		if isBlocking then
			-- Check for perfect block
			local blockDuration = PlayerDataManager:GetBlockDuration(victim)
			if blockDuration <= Config.Block.PerfectBlockWindow then
				hitResult = Enums.HitResult.PerfectBlock
			else
				hitResult = Enums.HitResult.Blocked
			end
		end
	else
		-- NPC blocking check (using NPCCombatHelper)
		isBlocking = NPCCombatHelper.IsNPCBlocking(victim)
		actualDamage = DamageCalculator.ApplyBlockReduction(damage, isBlocking)
		
		if isBlocking then
			-- Check for perfect block
			local blockDuration = NPCCombatHelper.GetNPCBlockDuration(victim)
			if blockDuration <= Config.Block.PerfectBlockWindow then
				hitResult = Enums.HitResult.PerfectBlock
			else
				hitResult = Enums.HitResult.Blocked
			end
		end
	end
	
	-- Apply damage via DamageCalculator
	DamageCalculator.ApplyDamage(victim, actualDamage)
	
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
