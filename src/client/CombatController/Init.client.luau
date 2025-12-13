--[[
	Script: Init
	Type: Client Initialization Script
	Location: StarterPlayer.StarterPlayerScripts.CombatController.Init
	Path: src/client/CombatController/Init.client.luau
	
	Description:
		Entry point for the client-side Combat System.
		Initializes the CombatController when the player spawns.
		Ensures proper setup and error handling.
	
	Author: Professional Roblox Scripter
	Created: December 10, 2025
--]]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Module Imports
local RS = ReplicatedStorage
local CombatSystem = RS:WaitForChild("Combat_System")
local Core = CombatSystem:WaitForChild("Core")

local Logger = require(Core.Logger).GetInstance()

-- Get CombatController from parent folder (CombatController folder)
local CombatController = require(script.Parent.CombatController)

-- ========================================
-- INITIALIZATION
-- ========================================

local function Initialize()
	Logger:Info("Initializing Combat System Client")
	
	-- Create controller instance
	local controller = CombatController.new()
	
	-- Initialize controller
	local success, errorMessage = pcall(function()
		controller:Initialize()
	end)
	
	if not success then
		Logger:Critical("Failed to initialize CombatController", {error = errorMessage})
		return
	end
	
	Logger:Info("Combat System Client initialized successfully")
end

-- ========================================
-- START
-- ========================================

Initialize()
