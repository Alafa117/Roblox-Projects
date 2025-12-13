--[[
	Script: Init
	Type: Server Initialization Script
	Location: ServerScriptService.CombatService.Init
	Path: src/server/CombatService/Init.server.luau
	
	Description:
		Entry point for the server-side Combat System.
		Initializes the CombatService on server start.
		Ensures proper setup and error handling.
	
	Author: Professional Roblox Scripter
	Created: December 11, 2025
--]]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Module Imports
local RS = ReplicatedStorage
local CombatSystem = RS:WaitForChild("Combat_System")
local Core = CombatSystem:WaitForChild("Core")

local Logger = require(Core.Logger).GetInstance()

-- Get CombatService from parent folder (CombatService folder)
local CombatService = require(script.Parent.CombatService)

-- ========================================
-- INITIALIZATION
-- ========================================

local function Initialize()
	Logger:Info("Initializing Combat System Server")
	
	-- Get service instance
	local service = CombatService.GetInstance()
	
	-- Initialize service
	local success, errorMessage = pcall(function()
		service:Initialize()
	end)
	
	if not success then
		Logger:Critical("Failed to initialize CombatService", {error = errorMessage})
		warn("[CombatSystem] Critical error during initialization:", errorMessage)
		return
	end
	
	Logger:Info("Combat System Server initialized successfully")
	
	-- Store in module for debugging if needed
	-- Note: Access via require() instead of global scope
	-- _G.CombatService = service -- Disabled: Non-idiomatic pattern
end

-- ========================================
-- START
-- ========================================

Initialize()
