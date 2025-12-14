--[[
	Module: ActionProcessor
	Type: Server Action Handler
	Location: ServerScriptService.CombatHandler.ActionProcessor
	Path: src/server/CombatHandler/ActionProcessor.luau
	
	Description:
		Processes all combat actions (attacks, movement, blocking).
		Handles state transitions, combo logic, and action execution.
		Separated from CombatService for better maintainability.
		Manages task scheduling and cancellation for actions.
	
	Dependencies:
		- ReplicatedStorage.CombatCore.Core (Config, Enums, Logger, DebugLogger)
		- ServerScriptService.CombatHandler.PlayerDataManager
	
	Author: Professional Roblox Scripter
	Created: December 13, 2025
--]]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Module Imports
local RS = ReplicatedStorage
local CombatSystem = RS:WaitForChild("CombatCore")
local Core = CombatSystem:WaitForChild("Core")

local Config = require(Core.Config)
local Enums = require(Core.Enums)
local Logger = require(Core.Logger).GetInstance()
local DebugLogger = require(Core.DebugLogger)

local PlayerDataManager = require(script.Parent.PlayerDataManager).GetInstance()

-- Action Processor Module
local ActionProcessor = {}
ActionProcessor.__index = ActionProcessor

-- ========================================
-- TYPES
-- ========================================

type ActionProcessor = {
	_mechanics: {[string]: any},
	_activeTasks: {[Player]: {[string]: thread}},
}

-- ========================================
-- INITIALIZATION
-- ========================================

function ActionProcessor.new(): ActionProcessor
	local self = setmetatable({}, ActionProcessor)
	
	self._mechanics = {}
	self._activeTasks = {}
	
	return self
end

function ActionProcessor:SetMechanics(mechanics: {[string]: any})
	self._mechanics = mechanics
end

-- ========================================
-- TASK MANAGEMENT
-- ========================================

function ActionProcessor:_ScheduleStateTransition(player: Player, targetState: string, delay: number, fromState: string?)
	local taskId = tostring(player.UserId) .. "_" .. targetState .. "_" .. os.clock()
	
	local thread = task.delay(delay, function()
		-- Verify task wasn't cancelled
		if not self._activeTasks[player] or not self._activeTasks[player][taskId] then
			return
		end
		
		-- Only transition if player is still in expected state
		if fromState then
			local currentState = PlayerDataManager:GetPlayerState(player)
			if currentState ~= fromState then
				return
			end
		end
		
		PlayerDataManager:SetPlayerState(player, targetState)
		
		-- Clean up task
		if self._activeTasks[player] then
			self._activeTasks[player][taskId] = nil
		end
	end)
	
	-- Track task for cleanup
	if not self._activeTasks[player] then
		self._activeTasks[player] = {}
	end
	self._activeTasks[player][taskId] = thread
end

function ActionProcessor:CancelPlayerTasks(player: Player)
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

function ActionProcessor:ProcessLightAttack(player: Player, data: {[string]: any}): {[string]: any}
	local isPlayer = typeof(player) == "Instance" and player:IsA("Player")
	local comboCount = 1 -- Default for NPCs
	
	-- Only use PlayerDataManager for actual Players
	if isPlayer then
		-- Update player state
		PlayerDataManager:SetPlayerState(player, Enums.CombatState.Attacking)
		PlayerDataManager:SetCooldown(player, Enums.ActionType.M1, os.clock())
		
		-- Handle combo
		local playerData = PlayerDataManager:GetPlayerData(player)
		local timeSinceLastAttack = os.clock() - (playerData.LastAttackTime or 0)
		
		if timeSinceLastAttack > Config.LightAttack.ComboWindow then
			PlayerDataManager:ResetCombo(player)
		end
		
		PlayerDataManager:IncrementCombo(player, Config.LightAttack.MaxComboCount)
		comboCount = PlayerDataManager:GetComboCount(player)
	end
	
	-- Check if attack cancelled movement
	local cancelledMovement = data.CancelledMovement or false
	if cancelledMovement then
		local entityName = if isPlayer then player.Name else "NPC"
		DebugLogger.ServerMechanicExecution("LightAttack", entityName, "Cancelled movement for attack")
	end
	
	-- Execute attack mechanic (works for both Players and NPCs)
	local mechanic = self._mechanics.LightAttack
	if mechanic then
		mechanic:Execute(player, {ComboCount = comboCount})
	else
		local entityName = if isPlayer then player.Name else "NPC"
		Logger:Error("LightAttack mechanic not loaded", {entity = entityName})
	end
	
	-- Only handle finisher and state transitions for Players
	if isPlayer then
		-- Check if finisher
		if comboCount == 6 then
			local finisherExtraCooldown = Config.LightAttack.FinisherCooldown - Config.LightAttack.Cooldown
			PlayerDataManager:SetCooldown(player, Enums.ActionType.M1, os.clock() + finisherExtraCooldown)
			PlayerDataManager:ResetCombo(player)
		end
		
		-- Return to idle after animation
		local animationDuration = if comboCount == 6 then Config.LightAttack.FinisherCooldown else Config.LightAttack.Cooldown
		self:_ScheduleStateTransition(player, Enums.CombatState.Idle, animationDuration, Enums.CombatState.Attacking)
	end
	
	return {Success = true, ComboCount = comboCount}
end

-- ========================================
-- STRONG ATTACK PROCESSING
-- ========================================

function ActionProcessor:ProcessStrongAttack(player: Player, data: {[string]: any}): {[string]: any}
	local isPlayer = typeof(player) == "Instance" and player:IsA("Player")
	local entityName = if isPlayer then player.Name else "NPC"
	
	DebugLogger.ServerRequest(entityName, "StrongAttack", "Instant")
	
	-- Check if attack cancelled movement
	local cancelledMovement = data.CancelledMovement or false
	if cancelledMovement then
		DebugLogger.ServerMechanicExecution("StrongAttack", entityName, "Cancelled movement for attack")
	end
	
	-- Only use PlayerDataManager for actual Players
	if isPlayer then
		-- Update player state
		PlayerDataManager:SetPlayerState(player, Enums.CombatState.Attacking)
		PlayerDataManager:SetCooldown(player, Enums.ActionType.M2, os.clock())
		PlayerDataManager:ResetCombo(player)
	end
	
	-- Execute attack mechanic (works for both Players and NPCs)
	local mechanic = self._mechanics.StrongAttack
	if mechanic then
		mechanic:Execute(player, {})
	else
		Logger:Error("StrongAttack mechanic not loaded", {entity = entityName})
	end
	
	-- Only handle state transitions for Players
	if isPlayer then
		self:_ScheduleStateTransition(player, Enums.CombatState.Idle, Config.StrongAttack.StunDuration + 0.3, Enums.CombatState.Attacking)
	end
	
	return {Success = true}
end

-- ========================================
-- DASH PROCESSING
-- ========================================

function ActionProcessor:ProcessDash(player: Player, data: {[string]: any}): {[string]: any}
	local isPlayer = typeof(player) == "Instance" and player:IsA("Player")
	
	-- Only use PlayerDataManager for actual Players
	if isPlayer then
		-- Update player state
		PlayerDataManager:SetPlayerState(player, Enums.CombatState.Dashing)
		PlayerDataManager:SetCooldown(player, Enums.ActionType.Q, os.clock())
		
		-- Enable invulnerability frames
		PlayerDataManager:SetInvulnerable(player, true)
	end
	
	-- Execute dash mechanic (works for both Players and NPCs)
	local mechanic = self._mechanics.Dash
	if mechanic then
		mechanic:Execute(player, {Direction = data.Direction})
	else
		local entityName = if isPlayer then player.Name else "NPC"
		Logger:Error("Dash mechanic not loaded", {entity = entityName})
	end
	
	-- Only handle invulnerability and state transitions for Players
	if isPlayer then
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
	end
	
	return {Success = true}
end

-- ========================================
-- SLIDE PROCESSING
-- ========================================

function ActionProcessor:ProcessSlide(player: Player, data: {[string]: any}): {[string]: any}
	local isPlayer = typeof(player) == "Instance" and player:IsA("Player")
	local entityName = if isPlayer then player.Name else "NPC"
	
	DebugLogger.ServerRequest(entityName, "Slide", data.Direction or "Forward")
	
	-- Only use PlayerDataManager for actual Players
	if isPlayer then
		-- Update player state
		PlayerDataManager:SetPlayerState(player, Enums.CombatState.Sliding)
		PlayerDataManager:SetCooldown(player, Enums.ActionType.C, os.clock())
	end
	
	-- Execute slide mechanic (works for both Players and NPCs)
	local mechanic = self._mechanics.Slide
	if mechanic then
		mechanic:Execute(player, {Direction = data.Direction})
	else
		Logger:Error("Slide mechanic not loaded", {entity = entityName})
	end
	
	-- Only handle state transitions for Players
	if isPlayer then
		self:_ScheduleStateTransition(player, Enums.CombatState.Idle, Config.Slide.Duration, Enums.CombatState.Sliding)
	end
	
	return {Success = true}
end

-- ========================================
-- BLOCK PROCESSING
-- ========================================

function ActionProcessor:ProcessBlock(player: Player, data: {[string]: any}, networkManager: any): {[string]: any}
	local isPlayer = typeof(player) == "Instance" and player:IsA("Player")
	
	-- Block only works for Players (NPCs don't block)
	if not isPlayer then
		return {Success = false, ErrorCode = "NPC_NO_BLOCK"}
	end
	
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
	networkManager:SendToClient(player, Enums.NetworkEvent.StateChanged, {
		State = isBlocking and Enums.CombatState.Blocking or Enums.CombatState.Idle
	})
	
	return {Success = true}
end

-- ========================================
-- DASH/SLIDE CANCELLATION
-- ========================================

function ActionProcessor:HandleCancelDash(player: Player): {[string]: any}
	DebugLogger.ServerRequest(player.Name, "CancelDash", nil)
	
	local mechanic = self._mechanics.Dash
	if mechanic and mechanic.CancelDash then
		mechanic:CancelDash(player)
		DebugLogger.ServerMechanicExecution("Dash", player.Name, "Cancelled")
	end
	
	return {Success = true}
end

function ActionProcessor:HandleCancelSlide(player: Player): {[string]: any}
	DebugLogger.ServerRequest(player.Name, "CancelSlide", nil)
	
	local mechanic = self._mechanics.Slide
	if mechanic and mechanic.CancelSlide then
		mechanic:CancelSlide(player)
		DebugLogger.ServerMechanicExecution("Slide", player.Name, "Cancelled")
	end
	
	return {Success = true}
end

return ActionProcessor
