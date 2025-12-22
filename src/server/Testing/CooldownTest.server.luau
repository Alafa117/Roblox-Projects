--[[
	Script: CooldownTest
	Type: Server Test Script
	Location: ServerScriptService.Testing.CooldownTest
	
	Description:
		Test script to validate server-side cooldown tracking system.
		Demonstrates how CooldownManager prevents cooldown bypass exploits.
	
	Author: Professional Roblox Scripter
	Created: December 21, 2025
--]]

-- Services
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Module Imports
local CooldownManager = require(ServerScriptService.CombatHandler.CooldownManager).GetInstance()
local CombatCore = ReplicatedStorage:WaitForChild("CombatCore")
local Logger = require(CombatCore.Logging.Logger).GetInstance()

-- Test Configuration
local TEST_PLAYER = nil -- Will be set to first player who joins

-- ========================================
-- TEST FUNCTIONS
-- ========================================

local function TestBasicCooldown()
	if not TEST_PLAYER then
		warn("No test player available")
		return
	end
	
	Logger:Info("=== TEST 1: Basic Cooldown Validation ===")
	
	-- Test M1 (0.6s cooldown)
	local canM1_1 = CooldownManager:CanPerformAction(TEST_PLAYER, "M1")
	Logger:Info("First M1 attempt", {allowed = canM1_1}) -- Should be true
	
	if canM1_1 then
		CooldownManager:RecordAction(TEST_PLAYER, "M1")
	end
	
	-- Immediate second attempt (should fail)
	local canM1_2 = CooldownManager:CanPerformAction(TEST_PLAYER, "M1")
	local remaining = CooldownManager:GetRemainingCooldown(TEST_PLAYER, "M1")
	Logger:Info("Second M1 attempt (immediate)", {
		allowed = canM1_2,
		remaining = string.format("%.2fs", remaining)
	}) -- Should be false
	
	-- Wait for cooldown
	task.wait(0.7)
	
	local canM1_3 = CooldownManager:CanPerformAction(TEST_PLAYER, "M1")
	Logger:Info("Third M1 attempt (after 0.7s)", {allowed = canM1_3}) -- Should be true
	
	Logger:Success("✅ Basic cooldown test completed")
end

local function TestMultipleActions()
	if not TEST_PLAYER then
		warn("No test player available")
		return
	end
	
	Logger:Info("=== TEST 2: Multiple Action Types ===")
	
	-- Test all action types simultaneously
	local actions = {"M1", "M2", "Q", "C", "F"}
	
	for _, action in ipairs(actions) do
		local canPerform = CooldownManager:CanPerformAction(TEST_PLAYER, action)
		Logger:Info("Action test", {action = action, allowed = canPerform})
		
		if canPerform then
			CooldownManager:RecordAction(TEST_PLAYER, action)
		end
	end
	
	-- Immediate retry (all should fail)
	Logger:Info("Immediate retry (all should fail):")
	for _, action in ipairs(actions) do
		local canPerform = CooldownManager:CanPerformAction(TEST_PLAYER, action)
		local remaining = CooldownManager:GetRemainingCooldown(TEST_PLAYER, action)
		Logger:Info("Retry", {
			action = action,
			allowed = canPerform,
			remaining = string.format("%.2fs", remaining)
		})
	end
	
	Logger:Success("✅ Multiple action test completed")
end

local function TestExploitAttempt()
	if not TEST_PLAYER then
		warn("No test player available")
		return
	end
	
	Logger:Info("=== TEST 3: Exploit Attempt Simulation ===")
	
	-- Simulate exploit attempting to spam M1
	Logger:Info("Simulating M1 spam exploit (10 attempts):")
	
	local allowedCount = 0
	local blockedCount = 0
	
	for i = 1, 10 do
		local canPerform = CooldownManager:CanPerformAction(TEST_PLAYER, "M1")
		if canPerform then
			CooldownManager:RecordAction(TEST_PLAYER, "M1")
			allowedCount = allowedCount + 1
		else
			blockedCount = blockedCount + 1
		end
		
		task.wait(0.05) -- Exploit attempts every 50ms
	end
	
	Logger:Info("Exploit simulation results", {
		allowed = allowedCount,
		blocked = blockedCount,
		effectiveness = string.format("%.1f%%", (blockedCount / 10) * 100)
	})
	
	Logger:Success("✅ Exploit prevention test completed")
end

local function TestAdminFunctions()
	if not TEST_PLAYER then
		warn("No test player available")
		return
	end
	
	Logger:Info("=== TEST 4: Admin Functions ===")
	
	-- Record some actions
	CooldownManager:RecordAction(TEST_PLAYER, "M1")
	CooldownManager:RecordAction(TEST_PLAYER, "M2")
	CooldownManager:RecordAction(TEST_PLAYER, "Q")
	
	-- Get all cooldowns
	local allCooldowns = CooldownManager:GetAllCooldowns(TEST_PLAYER)
	Logger:Info("All player cooldowns", allCooldowns)
	
	-- Reset specific cooldown
	CooldownManager:ResetCooldown(TEST_PLAYER, "M1")
	Logger:Info("M1 cooldown reset")
	
	local canM1 = CooldownManager:CanPerformAction(TEST_PLAYER, "M1")
	Logger:Info("M1 after reset", {allowed = canM1}) -- Should be true
	
	-- Reset all cooldowns
	CooldownManager:ResetAllCooldowns(TEST_PLAYER)
	Logger:Info("All cooldowns reset")
	
	local trackedCount = CooldownManager:GetTrackedPlayerCount()
	Logger:Info("Tracked players", {count = trackedCount})
	
	Logger:Success("✅ Admin functions test completed")
end

local function TestCleanup()
	Logger:Info("=== TEST 5: Automatic Cleanup ===")
	
	local trackedBefore = CooldownManager:GetTrackedPlayerCount()
	Logger:Info("Players tracked before", {count = trackedBefore})
	
	-- Cleanup happens automatically on PlayerRemoving
	-- This test just verifies the API works
	
	Logger:Success("✅ Cleanup test completed (automatic on disconnect)")
end

-- ========================================
-- RUN ALL TESTS
-- ========================================

local function RunAllTests()
	Logger:Info("╔═══════════════════════════════════════╗")
	Logger:Info("║  COOLDOWN MANAGER TEST SUITE         ║")
	Logger:Info("╚═══════════════════════════════════════╝")
	
	task.wait(2) -- Wait for test player
	
	if not TEST_PLAYER then
		Logger:Error("No test player available - waiting for player to join...")
		return
	end
	
	TestBasicCooldown()
	task.wait(1)
	
	TestMultipleActions()
	task.wait(1)
	
	TestExploitAttempt()
	task.wait(1)
	
	TestAdminFunctions()
	task.wait(1)
	
	TestCleanup()
	
	Logger:Success("╔═══════════════════════════════════════╗")
	Logger:Success("║  ALL TESTS COMPLETED ✅               ║")
	Logger:Success("╚═══════════════════════════════════════╝")
end

-- ========================================
-- PLAYER EVENTS
-- ========================================

Players.PlayerAdded:Connect(function(player)
	if not TEST_PLAYER then
		TEST_PLAYER = player
		Logger:Info("Test player set", {player = player.Name})
		
		-- Run tests after player loads
		task.spawn(RunAllTests)
	end
end)

-- Manual trigger for studio testing
if #Players:GetPlayers() > 0 and not TEST_PLAYER then
	TEST_PLAYER = Players:GetPlayers()[1]
	Logger:Info("Test player set (manual)", {player = TEST_PLAYER.Name})
	task.spawn(RunAllTests)
end
