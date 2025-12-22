--[[
	Module: Slide
	Type: Combat Mechanic Module (Server)
	Location: ReplicatedStorage.CombatCore.Movement.Slide
	Path: src/shared/CombatCore/Movement/Slide.luau
	
	Description:
		Implements the Slide (C) movement mechanic.
		Lower movement that maintains momentum with friction.
		Server-authoritative physics for consistency.
		Useful for dodging high attacks and repositioning.
	
	Phase 4 Refactoring:
		Consolidated duplicate validation code into MovementMechanicBase.
		Reduced from ~120 lines to ~90 lines (-25%).
	
	Dependencies:
		- ReplicatedStorage.CombatCore.Logging (Logger)
		- ReplicatedStorage.CombatCore.Movement (MovementMechanicBase)
	
	Author: Professional Roblox Scripter
	Created: December 11, 2025
--]]

-- Services
local RunService = game:GetService("RunService")

-- Module Imports
local Logger = require(script.Parent.Parent.Logging.Logger).GetInstance()
local Config = require(script.Parent.Parent.Config.Config)

local MovementMechanicBase = require(script.Parent.MovementMechanicBase)

-- Slide Module
local Slide = {}

-- ========================================
-- CONSTANTS
-- ========================================

local IS_SERVER = RunService:IsServer()

-- Anti-exploit tracking
local SlideStartPositions = {} -- {[player] = {Position = Vector3, Time = number, Thread = thread}}

-- ========================================
-- EXECUTE METHOD
-- ========================================

function Slide:Execute(player: Player, _data: {[string]: any})
	if not IS_SERVER then
		Logger:Warning("Slide can only be executed on server")
		return
	end
	
	-- Phase 4: Use consolidated initialization from MovementMechanicBase
	local humanoidRootPart = MovementMechanicBase.InitializeMovement(
		player,
		SlideStartPositions,
		"Slide",
		Config.Slide.Duration,
		function(p) self:_ValidateSlideDistance(p) end
	)
	
	if not humanoidRootPart then
		return -- Initialization failed (character invalid or no HumanoidRootPart)
	end
	
	-- Broadcast to clients for VFX
	self:_BroadcastSlide(player)
end

function Slide:CancelSlide(player: Player)
	Logger:Debug("Slide cancel requested", {player = player.Name})
	MovementMechanicBase.CancelMovement(player, SlideStartPositions)
end

-- ========================================
-- ANTI-EXPLOIT VALIDATION
-- ========================================

function Slide:_ValidateSlideDistance(player: Player)
	local startData = SlideStartPositions[player]
	MovementMechanicBase.ValidateMovementDistance(
		player,
		startData,
		SlideStartPositions,
		"Slide",
		Config.Slide.Distance,
		Config.Slide.Speed
	)
end

-- ========================================
-- CLIENT BROADCASTING
-- ========================================

function Slide:_BroadcastSlide(player: Player)
	MovementMechanicBase.BroadcastMovement(player, "Slide", "SlideTrail", nil)
end

return Slide
