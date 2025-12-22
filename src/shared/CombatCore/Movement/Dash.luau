--[[
	Module: Dash
	Type: Combat Mechanic Module (Server)
	Location: ReplicatedStorage.CombatCore.Movement.Dash
	Path: src/shared/CombatCore/Movement/Dash.luau
	
	Description:
		Implements the Dash (Q) movement mechanic.
		Quick directional movement with invulnerability frames.
		Server-authoritative physics with client prediction support.
		Directional dash based on player input (Forward, Backward, Left, Right).
	
	Phase 4 Refactoring:
		Consolidated duplicate validation code into MovementMechanicBase.
		Reduced from ~120 lines to ~90 lines (-25%).
	
	Dependencies:
		- ReplicatedStorage.CombatCore.Data (Enums)
		- ReplicatedStorage.CombatCore.Logging (Logger)
		- ReplicatedStorage.CombatCore.Movement (MovementMechanicBase)
	
	Author: Professional Roblox Scripter
	Created: December 11, 2025
--]]

-- Services
local RunService = game:GetService("RunService")

-- Module Imports
local Enums = require(script.Parent.Parent.Data.Enums)
local Logger = require(script.Parent.Parent.Logging.Logger).GetInstance()

local Config = require(script.Parent.Parent.Config.Config)
local MovementMechanicBase = require(script.Parent.MovementMechanicBase)

-- Dash Module
local Dash = {}

-- ========================================
-- CONSTANTS
-- ========================================

local IS_SERVER = RunService:IsServer()

-- Anti-exploit tracking
local DashStartPositions = {} -- {[player] = {Position = Vector3, Time = number, Thread = thread}}

-- ========================================
-- EXECUTE METHOD
-- ========================================

function Dash:Execute(player: Player, data: {[string]: any})
	if not IS_SERVER then
		Logger:Warning("Dash can only be executed on server")
		return
	end
	
	local direction = data.Direction or Enums.Direction.Forward
	
	-- Phase 4: Use consolidated initialization from MovementMechanicBase
	local humanoidRootPart = MovementMechanicBase.InitializeMovement(
		player,
		DashStartPositions,
		"Dash",
		Config.Dash.Duration,
		function(p) self:_ValidateDashDistance(p) end
	)
	
	if not humanoidRootPart then
		return -- Initialization failed (character invalid or no HumanoidRootPart)
	end
	
	-- Broadcast to clients for VFX
	self:_BroadcastDash(player, direction)
end

function Dash:CancelDash(player: Player)
	Logger:Debug("Dash cancel requested", {player = player.Name})
	MovementMechanicBase.CancelMovement(player, DashStartPositions)
end

-- ========================================
-- ANTI-EXPLOIT VALIDATION
-- ========================================

function Dash:_ValidateDashDistance(player: Player)
	local startData = DashStartPositions[player]
	MovementMechanicBase.ValidateMovementDistance(
		player,
		startData,
		DashStartPositions,
		"Dash",
		Config.Dash.Distance,
		Config.Dash.Speed
	)
end

-- ========================================
-- CLIENT BROADCASTING
-- ========================================

function Dash:_BroadcastDash(player: Player, direction: string)
	MovementMechanicBase.BroadcastMovement(player, "Dash", "DashTrail", direction)
end

return Dash
