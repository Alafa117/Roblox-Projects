--[[
	Module: CharacterManager
	Type: Client Character Manager
	Location: StarterPlayer.StarterPlayerScripts.CombatFramework.CharacterManager
	Path: src/client/CombatFramework/CharacterManager.luau
	
	Description:
		Manages the player's character lifecycle on the client.
		Handles character loading, respawning, death, and reference management.
		Provides validation and safe access to character components.
	
	Dependencies:
		- ReplicatedStorage.CombatCore (Logger, ValidationHelper, Enums)
	
	Author: Professional Roblox Scripter
	Created: December 13, 2025
--]]

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Module Imports
local CombatSystem = ReplicatedStorage:WaitForChild("CombatCore")

local Logger = require(CombatSystem.Logging.Logger).GetInstance()
local ValidationHelper = require(CombatSystem.Validation.ValidationHelper)

-- Constants
local LocalPlayer = Players.LocalPlayer

-- Character Manager Class
local CharacterManager = {}
CharacterManager.__index = CharacterManager

-- ========================================
-- TYPES
-- ========================================

type CharacterManager = {
	_character: Model?,
	_humanoid: Humanoid?,
	_rootPart: BasePart?,
	_onCharacterAddedCallback: ((Model) -> ())?,
	_onCharacterDiedCallback: (() -> ())?,
	_connections: {RBXScriptConnection},
}

-- ========================================
-- CONSTRUCTOR
-- ========================================

function CharacterManager.new(): CharacterManager
	local self = setmetatable({}, CharacterManager)
	
	self._character = nil
	self._humanoid = nil
	self._rootPart = nil
	self._onCharacterAddedCallback = nil
	self._onCharacterDiedCallback = nil
	self._connections = {}
	
	return self
end

-- ========================================
-- INITIALIZATION
-- ========================================

function CharacterManager:Initialize(onCharacterAdded: (Model) -> (), onCharacterDied: () -> ())
	self._onCharacterAddedCallback = onCharacterAdded
	self._onCharacterDiedCallback = onCharacterDied
	
	-- Wait for and setup initial character
	self:WaitForCharacter()
end

function CharacterManager:WaitForCharacter()
	-- Wait for initial character if not present
	if not LocalPlayer.Character then
		LocalPlayer.CharacterAdded:Wait()
	end
	
	self:_OnCharacterAdded(LocalPlayer.Character)
	
	-- Listen for respawns
	local characterAddedConnection = LocalPlayer.CharacterAdded:Connect(function(character)
		self:_OnCharacterAdded(character)
	end)
	table.insert(self._connections, characterAddedConnection)
end

-- ========================================
-- CHARACTER LIFECYCLE
-- ========================================

function CharacterManager:_OnCharacterAdded(character: Model)
	-- Wait for essential components
	local humanoid = character:WaitForChild("Humanoid", 5)
	local rootPart = character:WaitForChild("HumanoidRootPart", 5)
	
	if not humanoid or not rootPart then
		Logger:Error("Failed to get character components", {
			hasHumanoid = humanoid ~= nil,
			hasRootPart = rootPart ~= nil
		})
		return
	end
	
	-- Verify R6 character (system requirement)
	if not ValidationHelper.IsR6Avatar(character) then
		Logger:Warning("Character is not R6, combat system may not work correctly")
	end
	
	-- Update internal references
	self._character = character
	self._humanoid = humanoid
	self._rootPart = rootPart
	
	-- Listen for death
	local diedConnection = humanoid.Died:Connect(function()
		self:_OnCharacterDied()
	end)
	table.insert(self._connections, diedConnection)
	
	-- Notify callback
	if self._onCharacterAddedCallback then
		self._onCharacterAddedCallback(character)
	end
	
	Logger:Info("Character loaded successfully", {character = character.Name})
end

function CharacterManager:_OnCharacterDied()
	Logger:Info("Character died")
	
	-- Notify callback
	if self._onCharacterDiedCallback then
		self._onCharacterDiedCallback()
	end
end

-- ========================================
-- GETTERS
-- ========================================

function CharacterManager:GetCharacter(): Model?
	return self._character
end

function CharacterManager:GetHumanoid(): Humanoid?
	return self._humanoid
end

function CharacterManager:GetRootPart(): BasePart?
	return self._rootPart
end

-- ========================================
-- VALIDATION
-- ========================================

function CharacterManager:IsCharacterValid(): boolean
	return ValidationHelper.IsCharacterValid(self._character)
end

function CharacterManager:ValidateComponents(): boolean
	if not self._character or not self._character.Parent then
		return false
	end
	
	if not self._humanoid or not self._humanoid.Parent then
		return false
	end
	
	if not self._rootPart or not self._rootPart.Parent then
		return false
	end
	
	return true
end

-- ========================================
-- UTILITIES
-- ========================================

function CharacterManager:UpdateReferences(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	
	if humanoid and rootPart then
		self._character = character
		self._humanoid = humanoid :: Humanoid
		self._rootPart = rootPart :: BasePart
		
		return true
	end
	
	Logger:Warning("Failed to update character references - missing components")
	return false
end

function CharacterManager:ClearReferences()
	self._character = nil
	self._humanoid = nil
	self._rootPart = nil
end

-- ========================================
-- CLEANUP
-- ========================================

function CharacterManager:Destroy()
	-- Disconnect all connections
	for _, connection in ipairs(self._connections) do
		if connection.Connected then
			connection:Disconnect()
		end
	end
	table.clear(self._connections)
	
	-- Clear references
	self:ClearReferences()
	
	-- Clear callbacks
	self._onCharacterAddedCallback = nil
	self._onCharacterDiedCallback = nil
end

return CharacterManager
