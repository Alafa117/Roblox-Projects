--[[
	Module: ActionProcessor
	Type: Server Action Handler
	Location: ServerScriptService.CombatHandler.Core.ActionProcessor
	Path: src/server/CombatHandler/Core/ActionProcessor.luau
	
	Description:
		Processes all combat actions (attacks, movement, blocking).
		Handles state transitions, combo logic, and action execution.
		Separated from CombatService for better maintainability and single responsibility.
		Manages task scheduling and cancellation for all timed actions.
	
	Dependencies:
		- ReplicatedStorage.CombatCore.Core (Config, Enums, Logger, DebugLogger)
		- CombatHandler.Core (PlayerDataManager)
		- CombatHandler.Mechanics (LightAttack, StrongAttack via dynamic loading)
	
	Author: Professional Roblox Scripter
	Created: December 13, 2025
	Reorganized: December 23, 2025 - Moved to Core/ subfolder
--]]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Module Imports
local RS = ReplicatedStorage
local CombatSystem = RS:WaitForChild("CombatCore")

local Config = require(CombatSystem.Config.Config)
local Enums = require(CombatSystem.Data.Enums)
local Logger = require(CombatSystem.Logging.Logger).GetInstance()

local PlayerDataManager = require(script.Parent.PlayerDataManager).GetInstance()
local CooldownManager = require(script.Parent.Parent.Systems.CooldownManager).GetInstance()

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
		-- FIXED: Reject M1 if stunned (December 28, 2025)
		-- Bug 2: Players can attack during stun
		if PlayerDataManager:IsStunned(player) then
			Logger:Debug("LightAttack rejected - player is stunned", {
				player = player.Name,
				reason = "Cannot attack while stunned"
			})
			return {Success = false, ErrorCode = "STUNNED", ErrorMessage = "Cannot attack while stunned"}
		end
		
		-- FIXED: Reject M1 if blocking (December 28, 2025)
		-- Prevents desync bug where server IsBlocking=true but client thinks it's off
		if PlayerDataManager:IsBlocking(player) then
			Logger:Debug("LightAttack rejected - player is blocking", {
				player = player.Name,
				reason = "Cannot attack while blocking"
			})
			return {Success = false, ErrorCode = "BLOCKING", ErrorMessage = "Cannot attack while blocking"}
		end
		
		-- Update player state
		PlayerDataManager:SetPlayerState(player, Enums.CombatState.LightAttacking)
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
		Logger:ServerMechanicExecution("LightAttack", entityName, "Cancelled movement for attack")
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
		
		-- Return to idle after animation (NOT cooldown duration)
		-- Finisher animation is ~0.8s, then player can use other actions
		-- M1 cooldown (3.0s) blocks only M1, not other actions
		local animationDuration = if comboCount == 6 then 0.8 else Config.LightAttack.Cooldown
		self:_ScheduleStateTransition(player, Enums.CombatState.Idle, animationDuration, Enums.CombatState.LightAttacking)
	end
	
	return {Success = true, ComboCount = comboCount}
end

-- ========================================
-- STRONG ATTACK PROCESSING
-- ========================================

function ActionProcessor:ProcessStrongAttack(player: Player, data: {[string]: any}): {[string]: any}
	local isPlayer = typeof(player) == "Instance" and player:IsA("Player")
	local entityName = if isPlayer then player.Name else "NPC"
	
	Logger:ServerRequest(entityName, "StrongAttack", "Instant")
	
	-- FIXED: Reject M2 if stunned (December 28, 2025)
	-- Bug 2: Players can attack during stun
	if isPlayer and PlayerDataManager:IsStunned(player) then
		Logger:Debug("StrongAttack rejected - player is stunned", {
			player = player.Name,
			reason = "Cannot attack while stunned"
		})
		return {Success = false, ErrorCode = "STUNNED", ErrorMessage = "Cannot attack while stunned"}
	end
	
	-- FIXED: Reject M2 if blocking (December 28, 2025)
	-- Prevents desync bug where server IsBlocking=true but client thinks it's off
	if isPlayer and PlayerDataManager:IsBlocking(player) then
		Logger:Debug("StrongAttack rejected - player is blocking", {
			player = player.Name,
			reason = "Cannot attack while blocking"
		})
		return {Success = false, ErrorCode = "BLOCKING", ErrorMessage = "Cannot attack while blocking"}
	end
	
	-- Check if attack cancelled movement
	local cancelledMovement = data.CancelledMovement or false
	if cancelledMovement then
		Logger:ServerMechanicExecution("StrongAttack", entityName, "Cancelled movement for attack")
	end
	
	-- Only use PlayerDataManager for actual Players
	if isPlayer then
		-- Update player state
		PlayerDataManager:SetPlayerState(player, Enums.CombatState.StrongAttacking)
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
		self:_ScheduleStateTransition(player, Enums.CombatState.Idle, Config.StrongAttack.StunDuration + 0.3, Enums.CombatState.StrongAttacking)
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
		-- FIXED: Reject Dash if stunned (December 28, 2025)
		-- Bug 2: Players can dash during stun
		if PlayerDataManager:IsStunned(player) then
			Logger:Debug("Dash rejected - player is stunned", {
				player = player.Name,
				reason = "Cannot dash while stunned"
			})
			return {Success = false, ErrorCode = "STUNNED", ErrorMessage = "Cannot dash while stunned"}
		end
		
		-- FIXED: Reject Dash if blocking (December 28, 2025)
		-- Prevents desync bug where server IsBlocking=true but client thinks it's off
		if PlayerDataManager:IsBlocking(player) then
			Logger:Debug("Dash rejected - player is blocking", {
				player = player.Name,
				reason = "Cannot dash while blocking"
			})
			return {Success = false, ErrorCode = "BLOCKING", ErrorMessage = "Cannot dash while blocking"}
		end
		
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
	
	Logger:ServerRequest(entityName, "Slide", data.Direction or "Forward")
	
	-- Only use PlayerDataManager for actual Players
	if isPlayer then
		-- FIXED: Reject Slide if stunned (December 28, 2025)
		-- Bug 2: Players can slide during stun
		if PlayerDataManager:IsStunned(player) then
			Logger:Debug("Slide rejected - player is stunned", {
				player = player.Name,
				reason = "Cannot slide while stunned"
			})
			return {Success = false, ErrorCode = "STUNNED", ErrorMessage = "Cannot slide while stunned"}
		end
		
		-- FIXED: Reject Slide if blocking (December 28, 2025)
		-- Prevents desync bug where server IsBlocking=true but client thinks it's off
		if PlayerDataManager:IsBlocking(player) then
			Logger:Debug("Slide rejected - player is blocking", {
				player = player.Name,
				reason = "Cannot slide while blocking"
			})
			return {Success = false, ErrorCode = "BLOCKING", ErrorMessage = "Cannot slide while blocking"}
		end
		
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
	
	-- FIXED: Prevent blocking during actions (December 28, 2025)
	-- Block can only activate when in Idle state or when already Blocking
	if isBlocking then
		local currentState = PlayerDataManager:GetPlayerState(player)
		if currentState ~= Enums.CombatState.Idle and currentState ~= Enums.CombatState.Blocking then
			Logger:Debug("Block rejected - not in valid state", {
				player = player.Name,
				currentState = currentState,
				reason = "Must be Idle or Blocking to activate block"
			})
			return {Success = false, ErrorCode = "INVALID_STATE", ErrorMessage = "Cannot block during actions"}
		end
		
		-- FIXED: Prevent reactivating block immediately after block break (December 28, 2025)
		-- Bug 3: Spamming Block during hit evades block break effect
		-- Check if player has block break cooldown active
		local playerData = PlayerDataManager:GetPlayerData(player)
		if playerData and playerData.BlockBreakCooldown and os.clock() < playerData.BlockBreakCooldown then
			local remaining = playerData.BlockBreakCooldown - os.clock()
			Logger:Debug("Block rejected - block break cooldown active", {
				player = player.Name,
				remainingCooldown = string.format("%.2fs", remaining)
			})
			return {Success = false, ErrorCode = "BLOCK_BREAK_COOLDOWN", ErrorMessage = "Cannot block after block break"}
		end
	else
		-- FIXED: Force state synchronization when disabling block (December 28, 2025)
		-- When client releases F, ensure server state matches by forcing Idle
		-- This prevents desync where server thinks IsBlocking=true but client is Idle
		local currentState = PlayerDataManager:GetPlayerState(player)
		if currentState == Enums.CombatState.Blocking then
			PlayerDataManager:SetPlayerState(player, Enums.CombatState.Idle)
			Logger:Debug("Block disabled - forcing Idle state", {
				player = player.Name,
				previousState = "Blocking"
			})
		end
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
	Logger:ServerRequest(player.Name, "CancelDash", nil)
	
	local mechanic = self._mechanics.Dash
	if mechanic and mechanic.CancelDash then
		mechanic:CancelDash(player)
		Logger:ServerMechanicExecution("Dash", player.Name, "Cancelled")
	end
	
	return {Success = true}
end

function ActionProcessor:HandleCancelSlide(player: Player): {[string]: any}
	Logger:ServerRequest(player.Name, "CancelSlide", nil)
	
	local mechanic = self._mechanics.Slide
	if mechanic and mechanic.CancelSlide then
		mechanic:CancelSlide(player)
		Logger:ServerMechanicExecution("Slide", player.Name, "Cancelled")
	end
	
	return {Success = true}
end

return ActionProcessor
