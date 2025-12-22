--[[
	Module: RagdollManager
	Type: Server Physics State Manager
	Location: ServerScriptService.CombatHandler.Physics.RagdollManager
	Path: src/server/CombatHandler/Physics/RagdollManager.luau
	
	Description:
		Manages ragdoll state for all characters (Players and NPCs).
		Encapsulates state management separate from physics calculations.
		Server-authoritative to prevent client manipulation.
		
		Extracted from PhysicsHelper for proper separation of concerns:
		- PhysicsHelper: Pure physics calculations (stateless)
		- RagdollManager: State management and lifecycle (stateful)
	
	Phase 4 Refactoring:
		- Extracted from shared/CombatCore/Core/PhysicsHelper.luau
		- Now manages RagdollData state table
		- Coordinates physics operations with state tracking
		- Provides clean API for ragdoll lifecycle
	
	Dependencies:
		- ReplicatedStorage.CombatCore.Core.PhysicsHelper (for physics operations)
		- ReplicatedStorage.CombatCore.Core.Logger
	
	Author: Professional Roblox Scripter
	Created: December 17, 2025
--]]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Module Imports
local CombatSystem = ReplicatedStorage:WaitForChild("CombatCore")

local PhysicsHelper = require(CombatSystem.Helpers.PhysicsHelper)
local Logger = require(CombatSystem.Logging.Logger).GetInstance()

-- Ragdoll Manager Module
local RagdollManager = {}
RagdollManager.__index = RagdollManager

-- Singleton Instance
local ManagerInstance: RagdollManager? = nil

-- ========================================
-- TYPES
-- ========================================

type RagdollData = {
	OriginalCollisionStates: {[BasePart]: boolean},
	Thread: thread?,
	-- Array of constraint data
	[number]: {
		Motor: Motor6D,
		Socket: BallSocketConstraint,
		Att0: Attachment,
		Att1: Attachment,
	}
}

type RagdollManager = {
	_activeRagdolls: {[Model]: RagdollData},
}

-- ========================================
-- CONSTRUCTOR
-- ========================================

function RagdollManager.new(): RagdollManager
	local self = setmetatable({}, RagdollManager)
	
	self._activeRagdolls = {}
	
	Logger:Info("RagdollManager created")
	
	return self
end

-- ========================================
-- SINGLETON
-- ========================================

function RagdollManager.GetInstance(): RagdollManager
	if not ManagerInstance then
		ManagerInstance = RagdollManager.new()
	end
	return ManagerInstance
end

-- ========================================
-- RAGDOLL LIFECYCLE
-- ========================================

function RagdollManager:ApplyRagdoll(character: Model, duration: number)
	-- Validate character
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		Logger:Warning("Cannot apply ragdoll - no humanoid", {character = character.Name})
		return
	end
	
	-- Remove existing ragdoll if any
	if self._activeRagdolls[character] then
		self:RemoveRagdoll(character)
	end
	
	-- Set character to ragdoll state
	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	
	-- Initialize ragdoll data
	local ragdollData: RagdollData = {
		OriginalCollisionStates = {},
		Thread = nil,
	}
	self._activeRagdolls[character] = ragdollData
	
	-- Prepare body parts for ragdoll physics
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			-- Store original collision state
			ragdollData.OriginalCollisionStates[part] = part.CanCollide
			
			-- Enable collision for natural ragdoll physics
			part.CanCollide = true
			
			-- Zero velocities to start fresh
			part.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
			part.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
			
			-- Remove any existing BodyMovers
			for _, child in ipairs(part:GetChildren()) do
				if child:IsA("BodyVelocity") or child:IsA("BodyPosition") or child:IsA("BodyGyro") then
					child:Destroy()
				end
			end
		end
	end
	
	-- Break all Motor6D joints and replace with BallSocketConstraints
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("Motor6D") then
			local part0 = descendant.Part0
			local part1 = descendant.Part1
			
			if not part0 or not part1 then
				continue
			end
			
			-- Create attachments at Motor6D positions
			local att0 = Instance.new("Attachment")
			local att1 = Instance.new("Attachment")
			
			att0.CFrame = descendant.C0
			att1.CFrame = descendant.C1
			att0.Parent = part0
			att1.Parent = part1
			
			-- Create BallSocketConstraint for natural joint movement
			local socket = Instance.new("BallSocketConstraint")
			socket.Attachment0 = att0
			socket.Attachment1 = att1
			
			-- Configure limits for natural ragdoll (more freedom)
			socket.LimitsEnabled = true
			socket.UpperAngle = 90 -- Increased for natural movement
			socket.TwistLimitsEnabled = true
			socket.TwistLowerAngle = -90
			socket.TwistUpperAngle = 90
			
			socket.Parent = part0
			
			-- Store motor data for restoration (before destroying)
			local motorData = {
				Motor = descendant,
				Part0 = descendant.Part0,
				Part1 = descendant.Part1,
				C0 = descendant.C0,
				C1 = descendant.C1,
				Socket = socket,
				Att0 = att0,
				Att1 = att1,
			}
			table.insert(ragdollData, motorData)
			
			-- CRITICAL: Destroy Motor6D parent to fully disconnect
			-- Setting Parent to nil disconnects the joint while preserving the instance
			descendant.Parent = nil
		end
	end
	
	-- Schedule automatic ragdoll removal
	local thread = task.delay(duration, function()
		if character and character.Parent and self._activeRagdolls[character] then
			self:RemoveRagdoll(character)
		end
	end)
	
	-- Store thread for cleanup
	ragdollData.Thread = thread
	
	Logger:Debug("Ragdoll applied", {character = character.Name, duration = duration})
end

function RagdollManager:RemoveRagdoll(character: Model)
	local ragdollData = self._activeRagdolls[character]
	if not ragdollData then
		return
	end
	
	-- Cancel pending thread if exists
	if ragdollData.Thread then
		pcall(function()
			task.cancel(ragdollData.Thread)
		end)
		ragdollData.Thread = nil
	end
	
	-- Restore humanoid state
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
	
	-- Restore original collision states
	for part, originalState in pairs(ragdollData.OriginalCollisionStates) do
		if part and part.Parent then
			part.CanCollide = originalState
		end
	end
	
	-- Restore all Motor6Ds and remove constraints
	for _, data in ipairs(ragdollData) do
		-- Restore Motor6D by reparenting (reconnects the joint)
		if data.Motor and data.Part0 and data.Part0.Parent then
			data.Motor.Parent = data.Part0
		end
		-- Cleanup constraints and attachments
		if data.Socket then
			data.Socket:Destroy()
		end
		if data.Att0 then
			data.Att0:Destroy()
		end
		if data.Att1 then
			data.Att1:Destroy()
		end
	end
	
	-- Remove from active ragdolls
	self._activeRagdolls[character] = nil
	
	Logger:Debug("Ragdoll removed", {character = character.Name})
end

-- ========================================
-- STATE QUERIES
-- ========================================

function RagdollManager:IsRagdolled(character: Model): boolean
	return self._activeRagdolls[character] ~= nil
end

function RagdollManager:GetActiveRagdollCount(): number
	local count = 0
	for _ in pairs(self._activeRagdolls) do
		count += 1
	end
	return count
end

-- ========================================
-- CLEANUP
-- ========================================

function RagdollManager:CleanupCharacter(character: Model)
	if self._activeRagdolls[character] then
		self:RemoveRagdoll(character)
	end
end

function RagdollManager:CleanupAll()
	local characters = {}
	for character in pairs(self._activeRagdolls) do
		table.insert(characters, character)
	end
	
	for _, character in ipairs(characters) do
		self:RemoveRagdoll(character)
	end
	
	Logger:Info("All ragdolls cleaned up")
end

return RagdollManager
