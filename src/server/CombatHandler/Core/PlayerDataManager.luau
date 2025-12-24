--[[
	Module: PlayerDataManager
	Type: Server Data Manager
	Location: ServerScriptService.CombatHandler.Core.PlayerDataManager
	Path: src/server/CombatHandler/Core/PlayerDataManager.luau
	
	Description:
		Manages combat-related data for all players on the server.
		Tracks player states, cooldowns, combos, and combat statistics.
		Provides thread-safe access to player combat data.
		Implements data cleanup on player leave.
	
	Dependencies:
		- ReplicatedStorage.CombatCore.Core (Types, Enums, Logger)
	
	Author: Professional Roblox Scripter
	Created: December 11, 2025
--]]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Module Imports
local CombatSystem = ReplicatedStorage:WaitForChild("CombatCore")

local Types = require(CombatSystem.Data.Types)
local Enums = require(CombatSystem.Data.Enums)
local Logger = require(CombatSystem.Logging.Logger).GetInstance()
local ValidationHelper = require(CombatSystem.Validation.ValidationHelper)
local TypeValidators = require(CombatSystem.Validation.TypeValidators)

-- Player Data Manager Class
local PlayerDataManager = {}
PlayerDataManager.__index = PlayerDataManager

-- Singleton Instance
local ManagerInstance: PlayerDataManager? = nil

-- Cache NetworkManager to avoid repeated lookups
local NetworkManagerCache = nil

-- ========================================
-- TYPES
-- ========================================

---@class PlayerDataManager
---@field _playerData table<Player, PlayerCombatData> Player combat data storage
type PlayerDataManager = {
	_playerData: {[Player]: Types.PlayerCombatData},
}

-- ========================================
-- CONSTRUCTOR
-- ========================================

---Creates a new PlayerDataManager instance
---@return PlayerDataManager PlayerDataManager instance
function PlayerDataManager.new(): PlayerDataManager
	local self = setmetatable({}, PlayerDataManager)
	
	self._playerData = {}
	
	-- Initialize NetworkManager cache on construction (optimization)
	if not NetworkManagerCache then
		local Network = CombatSystem:FindFirstChild("Network")
		if Network then
			local NetworkManagerModule = Network:FindFirstChild("NetworkManager")
			if NetworkManagerModule then
				NetworkManagerCache = require(NetworkManagerModule).GetServerInstance()
			end
		end
	end
	
	Logger:Info("PlayerDataManager created")
	
	return self
end

-- ========================================
-- SINGLETON
---Gets or creates the singleton PlayerDataManager instance
---@return PlayerDataManager PlayerDataManager instance
-- ========================================

function PlayerDataManager.GetInstance(): PlayerDataManager
	if not ManagerInstance then
		ManagerInstance = PlayerDataManager.new()
	end
	return ManagerInstance
end

-- ========================================
-- PLAYER DATA INITIALIZATION
---Creates and initializes combat data for a player
---@param player Player The player to create data for
---@return PlayerCombatData The created combat data
-- ========================================

function PlayerDataManager:CreatePlayerData(player: Player): Types.PlayerCombatData
	-- Check if data already exists
	local existingData = self:GetPlayerData(player)
	if existingData then
		Logger:Warning("Player data already exists", {player = player.Name})
		return existingData
	end
	
	-- Wait for character
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid", 5)
	local rootPart = character:WaitForChild("HumanoidRootPart", 5)
	
	-- Create data structure
	local data: Types.PlayerCombatData = {
		Player = player,
		Character = character,
		Humanoid = humanoid,
		HumanoidRootPart = rootPart,
		
		CurrentState = Enums.CombatState.Idle,
		PreviousState = nil,
		
		ComboCount = 0,
		LastAttackTime = 0,
		
		Cooldowns = {
			M1 = 0,
			M2 = 0,
			Q = 0,
			C = 0,
			F = 0,
		},
		
		IsInvulnerable = false,
		IsStunned = false,
		StunEndTime = nil,
		StunTimer = nil,
		
		IsBlocking = false,
		BlockStartTime = nil,
		
		Health = humanoid and humanoid.Health or 100,
		MaxHealth = humanoid and humanoid.MaxHealth or 100,
		Stamina = 100,
		MaxStamina = 100,
	}
	
	-- ✅ Validate PlayerCombatData structure before storing
	local isValid, errorMessage = TypeValidators.ValidateWithError(
		TypeValidators.PlayerCombatData,
		data,
		"PlayerCombatData for " .. player.Name
	)
	
	if not isValid then
		Logger:Error("Failed to create player data - validation failed", {
			player = player.Name,
			error = errorMessage
		})
		error(errorMessage)
	end
	
	self._playerData[player] = data
	
	Logger:Info("Player combat data created", {player = player.Name})
	
	return data
end

function PlayerDataManager:RemovePlayerData(player: Player)
	local data = self._playerData[player]
	if not data then
		return
	end
	
	-- Cancel any active timers
	if data.StunTimer then
		task.cancel(data.StunTimer)
		data.StunTimer = nil
	end
	
	self._playerData[player] = nil
	
	Logger:Info("Player combat data removed", {player = player.Name})
end

-- ========================================
-- DATA ACCESS
-- ========================================

function PlayerDataManager:GetPlayerData(player: Player): Types.PlayerCombatData?
	return self._playerData[player]
end

function PlayerDataManager:GetAllPlayerData(): {[Player]: Types.PlayerCombatData}
	return self._playerData
end

-- ========================================
-- STATE MANAGEMENT
-- ========================================

function PlayerDataManager:SetPlayerState(player: Player, newState: string)
	local data = self:GetPlayerData(player)
	if not data then
		Logger:Warning("Cannot set state, player data not found", {player = player.Name})
		return
	end
	
	data.PreviousState = data.CurrentState
	data.CurrentState = newState
	
	-- Logger:Debug("Player state changed", {...}) -- Removed: Hot path optimization
	
	-- Sync with client using cached NetworkManager
	if NetworkManagerCache then
		NetworkManagerCache:SendToClient(player, Enums.NetworkEvent.StateChanged, {State = newState})
	end
end

function PlayerDataManager:GetPlayerState(player: Player): string?
	local data = self:GetPlayerData(player)
	return data and data.CurrentState
end

-- ========================================
-- COOLDOWN MANAGEMENT
-- ========================================

function PlayerDataManager:SetCooldown(player: Player, action: string, timestamp: number)
	local data = self:GetPlayerData(player)
	if not data then
		return
	end
	
	data.Cooldowns[action] = timestamp
end

function PlayerDataManager:IsCooldownReady(player: Player, action: string, cooldownDuration: number): boolean
	local data = self:GetPlayerData(player)
	if not data then
		return false
	end
	
	return ValidationHelper.IsCooldownReady(data.Cooldowns[action], cooldownDuration)
end

function PlayerDataManager:GetCooldownRemaining(player: Player, action: string, cooldownDuration: number): number
	local data = self:GetPlayerData(player)
	if not data then
		return 0
	end
	
	return ValidationHelper.GetCooldownRemaining(data.Cooldowns[action], cooldownDuration)
end

-- ========================================
-- COMBO MANAGEMENT
-- ========================================

function PlayerDataManager:IncrementCombo(player: Player, maxCombo: number)
	local data = self:GetPlayerData(player)
	if not data then
		return
	end
	
	data.ComboCount = math.min(data.ComboCount + 1, maxCombo)
	data.LastAttackTime = os.clock()
	
	-- Logger:Debug("Combo incremented", {player = player.Name, combo = data.ComboCount}) -- Removed: Hot path
end

function PlayerDataManager:ResetCombo(player: Player)
	local data = self:GetPlayerData(player)
	if not data then
		return
	end
	
	data.ComboCount = 0
	
	-- Logger:Debug("Combo reset", {player = player.Name}) -- Removed: Hot path
end

function PlayerDataManager:GetComboCount(player: Player): number
	local data = self:GetPlayerData(player)
	return data and data.ComboCount or 0
end

-- ========================================
-- STATUS EFFECTS
-- ========================================

function PlayerDataManager:SetInvulnerable(player: Player, invulnerable: boolean)
	local data = self:GetPlayerData(player)
	if not data then
		return
	end
	
	data.IsInvulnerable = invulnerable
	
	-- Logger:Debug("Invulnerability changed", {player = player.Name, invulnerable = invulnerable}) -- Removed: Hot path
end

function PlayerDataManager:IsInvulnerable(player: Player): boolean
	local data = self:GetPlayerData(player)
	return data and data.IsInvulnerable or false
end

function PlayerDataManager:SetStunned(player: Player, stunned: boolean, duration: number?)
	local data = self:GetPlayerData(player)
	if not data then
		return
	end
	
	-- Cancel existing stun timer if any
	if data.StunTimer then
		task.cancel(data.StunTimer)
		data.StunTimer = nil
	end
	
	data.IsStunned = stunned
	
	if stunned and duration then
		data.StunEndTime = os.clock() + duration
		self:SetPlayerState(player, Enums.CombatState.Stunned)
		
		-- Schedule automatic stun removal
		data.StunTimer = task.delay(duration, function()
			-- Only clear if player still exists and is still stunned
			if self._playerData[player] then
				local currentData = self:GetPlayerData(player)
				if currentData and currentData.IsStunned then
					-- Clear timer reference BEFORE calling SetStunned to avoid recursive cancel
					currentData.StunTimer = nil
					self:SetStunned(player, false)
				end
			end
		end)
	else
		data.StunEndTime = nil
		if data.CurrentState == Enums.CombatState.Stunned then
			self:SetPlayerState(player, Enums.CombatState.Idle)
		end
	end
	
	-- Logger:Debug("Stun changed", {player = player.Name, stunned = stunned, duration = duration}) -- Removed: Hot path
end

function PlayerDataManager:IsStunned(player: Player): boolean
	local data = self:GetPlayerData(player)
	if not data or not data.IsStunned then
		return false
	end
	
	-- Check if stun expired
	if data.StunEndTime and os.clock() >= data.StunEndTime then
		self:SetStunned(player, false)
		return false
	end
	
	return true
end

-- ========================================
-- BLOCKING
-- ========================================

function PlayerDataManager:SetBlocking(player: Player, blocking: boolean)
	local data = self:GetPlayerData(player)
	if not data then
		return
	end
	
	data.IsBlocking = blocking
	
	if blocking then
		data.BlockStartTime = os.clock()
		self:SetPlayerState(player, Enums.CombatState.Blocking)
	else
		data.BlockStartTime = nil
		if data.CurrentState == Enums.CombatState.Blocking then
			self:SetPlayerState(player, Enums.CombatState.Idle)
		end
	end
	
	-- Logger:Debug("Blocking changed", {player = player.Name, blocking = blocking}) -- Removed: Hot path
end

function PlayerDataManager:IsBlocking(player: Player): boolean
	local data = self:GetPlayerData(player)
	return data and data.IsBlocking or false
end

function PlayerDataManager:GetBlockDuration(player: Player): number
	local data = self:GetPlayerData(player)
	if not data or not data.BlockStartTime then
		return 0
	end
	
	return os.clock() - data.BlockStartTime
end

-- ========================================
-- CHARACTER UPDATES
-- ========================================

function PlayerDataManager:UpdateCharacterReferences(player: Player, character: Model)
	local data = self:GetPlayerData(player)
	if not data then
		return
	end
	
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	
	data.Character = character
	data.Humanoid = humanoid
	data.HumanoidRootPart = rootPart
	
	-- Reset state
	data.CurrentState = Enums.CombatState.Idle
	data.PreviousState = nil
	data.ComboCount = 0
	data.IsInvulnerable = false
	data.IsStunned = false
	data.IsBlocking = false
	
	-- Reset cooldowns
	for action in pairs(data.Cooldowns) do
		data.Cooldowns[action] = 0
	end
	
	Logger:Info("Character references updated", {player = player.Name})
end

-- ========================================
-- VALIDATION
-- ========================================

function PlayerDataManager:ValidatePlayerData(player: Player): boolean
	local data = self:GetPlayerData(player)
	if not data then
		return false
	end
	
	-- Check character validity
	if not ValidationHelper.IsCharacterValid(data.Character) then
		return false
	end
	
	-- Check humanoid
	if not data.Humanoid or data.Humanoid.Health <= 0 then
		return false
	end
	
	return true
end

return PlayerDataManager
