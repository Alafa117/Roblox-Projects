--[[
	Module: NPCCombatHelper
	Type: Server NPC Helper Module
	Location: ServerScriptService.NPCs.NPCCombatHelper
	Path: src/server/NPCs/NPCCombatHelper.luau
	
	Description:
		Helper module for using the Combat System with NPCs/Test Rigs.
		Provides simple functions to make NPCs perform combat actions.
		NPCs don't use PlayerDataManager or state tracking - they just execute actions.
		
		This module provides NPC integration with the Combat System.
		Used primarily by SimpleNPCAI and NPC-based gameplay features.
		
		Usage Example:
			local NPCHelper = require(ServerScriptService.NPCs.NPCCombatHelper)
			local rig = workspace.Rig
			
			-- Make NPC attack
			NPCHelper.PerformLightAttack(rig)
			NPCHelper.PerformStrongAttack(rig)
			NPCHelper.PerformDash(rig, "Forward")
			NPCHelper.PerformSlide(rig, "Backward")
			NPCHelper.StartBlock(rig)
			NPCHelper.StopBlock(rig)
	
	Dependencies:
		- ServerScriptService.CombatHandler.Core.ActionProcessor
		- ReplicatedStorage.CombatCore.Core.Enums
	
	Author: Professional Roblox Scripter
	Created: December 13, 2025
	Updated: December 14, 2025 - Moved to Testing folder
	Updated: December 23, 2025 - Reorganized to NPCs folder
--]]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Module Imports
local CombatCore = ReplicatedStorage:WaitForChild("CombatCore")
local Enums = require(CombatCore.Data.Enums)

-- ActionProcessor is in CombatHandler (core system)
local CombatHandler = ServerScriptService:WaitForChild("CombatHandler")
local ActionProcessorModule = require(CombatHandler.Core:WaitForChild("ActionProcessor"))

-- NPC Combat Helper
local NPCCombatHelper = {}

-- Create a single ActionProcessor instance for NPCs
local npcActionProcessor = ActionProcessorModule.new()

-- Track blocking state for NPCs (since PlayerDataManager only handles Players)
local npcBlockingState = {} -- [Model] = {IsBlocking: boolean, BlockStartTime: number}

-- ========================================
-- INITIALIZATION
-- ========================================

function NPCCombatHelper.Initialize(mechanics: {[string]: any})
	-- Set mechanics from main CombatService
	npcActionProcessor:SetMechanics(mechanics)
end

-- ========================================
-- NPC BLOCKING STATE (for Combat System integration)
-- ========================================

function NPCCombatHelper.IsNPCBlocking(npc: Model): boolean
	if not npc or not npcBlockingState[npc] then
		return false
	end
	return npcBlockingState[npc].IsBlocking or false
end

function NPCCombatHelper.GetNPCBlockDuration(npc: Model): number
	if not npc or not npcBlockingState[npc] or not npcBlockingState[npc].BlockStartTime then
		return 0
	end
	return os.clock() - npcBlockingState[npc].BlockStartTime
end

-- ========================================
-- LIGHT ATTACK
-- ========================================

function NPCCombatHelper.PerformLightAttack(npc: Model, comboCount: number?): {[string]: any}
	if not npc or not npc:IsA("Model") then
		warn("NPCCombatHelper: Invalid NPC model")
		return {Success = false, ErrorCode = "INVALID_NPC"}
	end
	
	-- Execute light attack with specified combo count (default 1)
	return npcActionProcessor:ProcessLightAttack(npc, {
		ComboCount = comboCount or 1,
		CancelledMovement = false
	})
end

-- ========================================
-- STRONG ATTACK
-- ========================================

function NPCCombatHelper.PerformStrongAttack(npc: Model): {[string]: any}
	if not npc or not npc:IsA("Model") then
		warn("NPCCombatHelper: Invalid NPC model")
		return {Success = false, ErrorCode = "INVALID_NPC"}
	end
	
	-- Execute strong attack
	return npcActionProcessor:ProcessStrongAttack(npc, {
		CancelledMovement = false
	})
end

-- ========================================
-- DASH
-- ========================================

function NPCCombatHelper.PerformDash(npc: Model, direction: string?): {[string]: any}
	if not npc or not npc:IsA("Model") then
		warn("NPCCombatHelper: Invalid NPC model")
		return {Success = false, ErrorCode = "INVALID_NPC"}
	end
	
	-- Execute dash
	return npcActionProcessor:ProcessDash(npc, {
		Direction = direction or Enums.Direction.Forward
	})
end

-- ========================================
-- SLIDE
-- ========================================

function NPCCombatHelper.PerformSlide(npc: Model, direction: string?): {[string]: any}
	if not npc or not npc:IsA("Model") then
		warn("NPCCombatHelper: Invalid NPC model")
		return {Success = false, ErrorCode = "INVALID_NPC"}
	end
	
	-- Execute slide
	return npcActionProcessor:ProcessSlide(npc, {
		Direction = direction or Enums.Direction.Forward
	})
end

-- ========================================
-- BLOCK
-- ========================================

function NPCCombatHelper.StartBlock(npc: Model): {[string]: any}
	if not npc or not npc:IsA("Model") then
		warn("NPCCombatHelper: Invalid NPC model")
		return {Success = false, ErrorCode = "INVALID_NPC"}
	end
	
	-- Initialize blocking state for this NPC
	if not npcBlockingState[npc] then
		npcBlockingState[npc] = {
			IsBlocking = false,
			BlockStartTime = 0
		}
	end
	
	-- Set blocking state
	npcBlockingState[npc].IsBlocking = true
	npcBlockingState[npc].BlockStartTime = os.clock()
	
	-- Execute block start
	return npcActionProcessor:ProcessBlock(npc, {
		IsBlockStart = true
	})
end

function NPCCombatHelper.StopBlock(npc: Model): {[string]: any}
	if not npc or not npc:IsA("Model") then
		warn("NPCCombatHelper: Invalid NPC model")
		return {Success = false, ErrorCode = "INVALID_NPC"}
	end
	
	-- Clear blocking state
	if npcBlockingState[npc] then
		npcBlockingState[npc].IsBlocking = false
		npcBlockingState[npc].BlockStartTime = 0
	end
	
	-- Execute block stop
	return npcActionProcessor:ProcessBlock(npc, {
		IsBlockStart = false
	})
end

-- ========================================
-- CANCEL ACTIONS
-- ========================================

function NPCCombatHelper.CancelDash(npc: Model): {[string]: any}
	if not npc or not npc:IsA("Model") then
		warn("NPCCombatHelper: Invalid NPC model")
		return {Success = false, ErrorCode = "INVALID_NPC"}
	end
	
	return npcActionProcessor:HandleCancelDash(npc)
end

function NPCCombatHelper.CancelSlide(npc: Model): {[string]: any}
	if not npc or not npc:IsA("Model") then
		warn("NPCCombatHelper: Invalid NPC model")
		return {Success = false, ErrorCode = "INVALID_NPC"}
	end
	
	return npcActionProcessor:HandleCancelSlide(npc)
end

return NPCCombatHelper
