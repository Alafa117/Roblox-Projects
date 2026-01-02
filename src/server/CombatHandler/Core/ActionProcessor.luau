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
local RagdollManager = require(script.Parent.Parent.Physics.RagdollManager).GetInstance()

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
		-- FIXED: Reject M1 if ragdolled (December 28, 2025)
		-- Bug: Players can attack during ragdoll
		local character = player.Character
		if character and RagdollManager:IsRagdolled(character) then
			Logger:Debug("LightAttack rejected - player is ragdolled", {
				player = player.Name,
				reason = "Cannot attack while ragdolled"
			})
			return {Success = false, ErrorCode = "RAGDOLLED", ErrorMessage = "Cannot attack while ragdolled"}
		end
		
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
		
		-- FIXED: Reject M1 if in the middle of another action (December 29, 2025)
		-- Bug: Pressing Block during M2 then M1 allows M1 to execute during M2
		-- FIXED: Allow M1 during Dashing/Sliding for cancels (December 30, 2025)
		local currentState = PlayerDataManager:GetPlayerState(player)
		
		-- FIXED: Prevent Dash/Slide cancel if M1 is on cooldown (December 30, 2025)
		-- Only applies after M1 finisher (6th hit) which has a 3s cooldown
		if (currentState == Enums.CombatState.Dashing or currentState == Enums.CombatState.Sliding) then
			local playerData = PlayerDataManager:GetPlayerData(player)
			if playerData then
				local m1Cooldown = playerData.Cooldowns.M1 or 0
				local cooldownRemaining = m1Cooldown - os.clock()
				
				if cooldownRemaining > 0 then
					Logger:Debug("LightAttack rejected - cooldown active during Dash/Slide", {
						player = player.Name,
						cooldownRemaining = string.format("%.2fs", cooldownRemaining)
					})
					return {Success = false, ErrorCode = "COOLDOWN", ErrorMessage = "Attack on cooldown"}
				end
			end
		end
		
		if currentState ~= Enums.CombatState.Idle 
			and currentState ~= Enums.CombatState.LightAttacking 
			and currentState ~= Enums.CombatState.Dashing 
			and currentState ~= Enums.CombatState.Sliding then
			Logger:Debug("LightAttack rejected - invalid state", {
				player = player.Name,
				currentState = currentState,
				reason = "Cannot attack during other actions"
			})
			-- FIXED: Return server combo count for client sync (December 30, 2025)
			local serverCombo = PlayerDataManager:GetComboCount(player)
			return {
				Success = false, 
				ErrorCode = "INVALID_STATE", 
				ErrorMessage = "Cannot attack during other actions",
				ServerComboCount = serverCombo
			}
		end
		
		-- Update player state
		PlayerDataManager:SetPlayerState(player, Enums.CombatState.LightAttacking)
		
		-- FIXED: Only set cooldown for finisher hits (December 30, 2025)
		-- Regular combo hits (1-5) don't have cooldown validation on server
		-- This prevents hitbox loss due to timing precision issues
		-- Client handles animation timing, server only validates finisher cooldown
		local playerData = PlayerDataManager:GetPlayerData(player)
		local currentCombo = playerData.ComboCount or 0
		
		-- Only set cooldown AFTER getting current combo, before incrementing
		-- This ensures we check the NEXT hit number (after increment)
		if currentCombo + 1 == Config.LightAttack.MaxComboCount then
			-- This will be the finisher hit, set cooldown
			PlayerDataManager:SetCooldown(player, Enums.ActionType.M1, os.clock())
		end
		-- For hits 1-5, no cooldown is set on server
		
		-- Handle combo (reuse playerData from above)
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
	
	-- Only use PlayerDataManager for actual Players
	if isPlayer then
		-- FIXED: Reject M2 if ragdolled (December 29, 2025)
		-- Bug: Players can attack during ragdoll
		local character = player.Character
		if character and RagdollManager:IsRagdolled(character) then
			Logger:Debug("StrongAttack rejected - player is ragdolled", {
				player = player.Name,
				reason = "Cannot attack while ragdolled"
			})
			return {Success = false, ErrorCode = "RAGDOLLED", ErrorMessage = "Cannot attack while ragdolled"}
		end
		
		-- FIXED: Reject M2 if stunned (December 28, 2025)
		-- Bug 2: Players can attack during stun
		if PlayerDataManager:IsStunned(player) then
			Logger:Debug("StrongAttack rejected - player is stunned", {
				player = player.Name,
				reason = "Cannot attack while stunned"
			})
			return {Success = false, ErrorCode = "STUNNED", ErrorMessage = "Cannot attack while stunned"}
		end
		
		-- FIXED: Reject M2 if blocking (December 28, 2025)
		-- Prevents desync bug where server IsBlocking=true but client thinks it's off
		if PlayerDataManager:IsBlocking(player) then
			Logger:Debug("StrongAttack rejected - player is blocking", {
				player = player.Name,
				reason = "Cannot attack while blocking"
			})
			return {Success = false, ErrorCode = "BLOCKING", ErrorMessage = "Cannot attack while blocking"}
		end
		
		-- FIXED: Reject M2 if in the middle of another action (December 29, 2025)
		-- Only allow M2 when in Idle state
		-- FIXED: Allow M2 during Dashing/Sliding for cancels (December 30, 2025)
		local currentState = PlayerDataManager:GetPlayerState(player)
		
		-- FIXED: Prevent Dash/Slide cancel if M2 is on cooldown (December 30, 2025)
		-- M2 has a 3s cooldown after execution
		if (currentState == Enums.CombatState.Dashing or currentState == Enums.CombatState.Sliding) then
			local playerData = PlayerDataManager:GetPlayerData(player)
			if playerData then
				local m2Cooldown = playerData.Cooldowns.M2 or 0
				local cooldownRemaining = m2Cooldown - os.clock()
				
				if cooldownRemaining > 0 then
					Logger:Debug("StrongAttack rejected - cooldown active during Dash/Slide", {
						player = player.Name,
						cooldownRemaining = string.format("%.2fs", cooldownRemaining)
					})
					return {Success = false, ErrorCode = "COOLDOWN", ErrorMessage = "Attack on cooldown"}
				end
			end
		end
		
		if currentState ~= Enums.CombatState.Idle 
			and currentState ~= Enums.CombatState.Dashing 
			and currentState ~= Enums.CombatState.Sliding then
			Logger:Debug("StrongAttack rejected - invalid state", {
				player = player.Name,
				currentState = currentState,
				reason = "Cannot attack during other actions"
			})
			return {Success = false, ErrorCode = "INVALID_STATE", ErrorMessage = "Cannot attack during other actions"}
		end
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
		-- FIXED: Reject Dash if ragdolled (December 28, 2025)
		-- Bug: Players can dash during ragdoll
		local character = player.Character
		if character and RagdollManager:IsRagdolled(character) then
			Logger:Debug("Dash rejected - player is ragdolled", {
				player = player.Name,
				reason = "Cannot dash while ragdolled"
			})
			return {Success = false, ErrorCode = "RAGDOLLED", ErrorMessage = "Cannot dash while ragdolled"}
		end
		
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
		
		-- FIXED: Reject Dash if in the middle of another action (December 29, 2025)
		-- Only allow Dash when in Idle state
		local currentState = PlayerDataManager:GetPlayerState(player)
		if currentState ~= Enums.CombatState.Idle then
			Logger:Debug("Dash rejected - invalid state", {
				player = player.Name,
				currentState = currentState,
				reason = "Cannot dash during other actions"
			})
			return {Success = false, ErrorCode = "INVALID_STATE", ErrorMessage = "Cannot dash during other actions"}
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
		-- FIXED: Reject Slide if ragdolled (December 28, 2025)
		-- Bug: Players can slide during ragdoll
		local character = player.Character
		if character and RagdollManager:IsRagdolled(character) then
			Logger:Debug("Slide rejected - player is ragdolled", {
				player = player.Name,
				reason = "Cannot slide while ragdolled"
			})
			return {Success = false, ErrorCode = "RAGDOLLED", ErrorMessage = "Cannot slide while ragdolled"}
		end
		
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
		
		-- FIXED: Reject Slide if in the middle of another action (December 29, 2025)
		-- Only allow Slide when in Idle state
		local currentState = PlayerDataManager:GetPlayerState(player)
		if currentState ~= Enums.CombatState.Idle then
			Logger:Debug("Slide rejected - invalid state", {
				player = player.Name,
				currentState = currentState,
				reason = "Cannot slide during other actions"
			})
			return {Success = false, ErrorCode = "INVALID_STATE", ErrorMessage = "Cannot slide during other actions"}
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
	
	-- FIXED: Reject Block if ragdolled (December 28, 2025)
	-- Bug: Players can block during ragdoll
	local character = player.Character
	if character and RagdollManager:IsRagdolled(character) then
		Logger:Debug("Block rejected - player is ragdolled", {
			player = player.Name,
			reason = "Cannot block while ragdolled"
		})
		return {Success = false, ErrorCode = "RAGDOLLED", ErrorMessage = "Cannot block while ragdolled"}
	end
	
	-- Check if stunned
	if PlayerDataManager:IsStunned(player) then
		return {Success = false, ErrorCode = "STUNNED"}
	end
	
	-- FIXED: Bug 1 - Allow block deactivation anytime, only restrict activation (December 28, 2025)
	-- Releasing F (IsBlocking=false) should always work, even during attacks
	-- Only block ACTIVATION (IsBlocking=true) requires Idle or Blocking state
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
		
		-- FIXED: Bug 2 - Require F release after block break (December 28, 2025)
		-- Player must release F and press again to reactivate block after break
		local playerData = PlayerDataManager:GetPlayerData(player)
		if playerData then
			-- Check if block break cooldown is active
			if playerData.BlockBreakCooldown and os.clock() < playerData.BlockBreakCooldown then
				-- If F was already held when block broke, reject activation
				if playerData.BlockInputHeld then
					Logger:Debug("Block rejected - must release F after block break", {
						player = player.Name,
						reason = "Release F and press again"
					})
					return {Success = false, ErrorCode = "BLOCK_INPUT_HELD", ErrorMessage = "Release F and press again"}
				end
				
				local remaining = playerData.BlockBreakCooldown - os.clock()
				Logger:Debug("Block rejected - block break cooldown active", {
					player = player.Name,
					remainingCooldown = string.format("%.2fs", remaining)
				})
				return {Success = false, ErrorCode = "BLOCK_BREAK_COOLDOWN", ErrorMessage = "Cannot block after block break"}
			end
			
			-- Mark that F is now held
			playerData.BlockInputHeld = true
		end
	else
		-- FIXED: Mark F as released (December 28, 2025)
		-- This allows block to be reactivated after block break
		local playerData = PlayerDataManager:GetPlayerData(player)
		if playerData then
			playerData.BlockInputHeld = false
			Logger:Debug("Block input released", {
				player = player.Name
			})
		end
	end
	
	-- FIXED: Update blocking state IMMEDIATELY (December 30, 2025)
	-- SetBlocking now handles state transitions to Idle automatically
	-- This must happen before any state checks to ensure SetBlocking removes highlight
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
