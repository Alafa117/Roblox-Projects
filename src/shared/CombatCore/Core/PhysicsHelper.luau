--[[
	Module: PhysicsHelper
	Type: Physics Utility Module
	Location: ReplicatedStorage.CombatCore.Core.PhysicsHelper
	Path: src/shared/CombatCore/Core/PhysicsHelper.luau
	
	Description:
		Handles all physics-related operations like knockback and ragdoll.
		Separated from Utility for better organization and maintainability.
	
	Author: Professional Roblox Scripter
	Created: December 11, 2025
--]]

-- PhysicsHelper Module
local PhysicsHelper = {}

-- Internal storage for ragdoll data
local RagdollData = {}

-- ========================================
-- KNOCKBACK
-- ========================================

function PhysicsHelper.ApplyKnockback(character: Model, direction: Vector3, force: number)
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart or not rootPart:IsA("BasePart") then
		return
	end
	
	-- Create temporary body velocity
	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.MaxForce = Vector3.new(1, 1, 1) * math.huge
	bodyVelocity.Velocity = direction.Unit * force
	bodyVelocity.Parent = rootPart
	
	-- Remove after 0.1 seconds with safety check
	local thread = task.delay(0.1, function()
		if bodyVelocity and bodyVelocity.Parent then
			bodyVelocity:Destroy()
		end
	end)
	
	-- Cancel thread if bodyVelocity is destroyed early
	bodyVelocity.Destroying:Connect(function()
		task.cancel(thread)
	end)
end

-- ========================================
-- RAGDOLL
-- ========================================

function PhysicsHelper.ApplyRagdoll(character: Model, duration: number)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	
	-- Set character to ragdoll state
	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	
	-- Store original Motor6D data and part properties
	local characterRagdollData = {}
	characterRagdollData.OriginalCollisionStates = {}
	RagdollData[character] = characterRagdollData
	
	-- Prepare body parts for ragdoll physics
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			-- Store original collision state
			characterRagdollData.OriginalCollisionStates[part] = part.CanCollide
			
			-- Disable collision to prevent getting stuck
			part.CanCollide = false
			
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
			
			-- Store data for restoration
			table.insert(characterRagdollData, {
				Motor = descendant,
				Socket = socket,
				Att0 = att0,
				Att1 = att1,
			})
			
			-- CRITICAL: Disable Motor6D to allow BallSocketConstraint to work
			descendant.Enabled = false
		end
	end
	
	-- Schedule ragdoll removal with safety check
	local thread = task.delay(duration, function()
		if character and character.Parent then
			PhysicsHelper.RemoveRagdoll(character)
		end
	end)
	
	-- Store thread for cleanup
	characterRagdollData.Thread = thread
end

function PhysicsHelper.RemoveRagdoll(character: Model)
	local characterRagdollData = RagdollData[character]
	if not characterRagdollData then
		return
	end
	
	-- Cancel pending thread if exists
	if characterRagdollData.Thread then
		pcall(function()
			task.cancel(characterRagdollData.Thread)
		end)
		-- Ignore errors - thread may have already completed
		characterRagdollData.Thread = nil
	end
	
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
	
	-- Restore original collision states
	if characterRagdollData.OriginalCollisionStates then
		for part, originalState in pairs(characterRagdollData.OriginalCollisionStates) do
			if part and part.Parent then
				part.CanCollide = originalState
			end
		end
	end
	
	-- Restore all Motor6Ds and remove constraints
	for _, data in ipairs(characterRagdollData) do
		if data.Motor then
			data.Motor.Enabled = true
		end
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
	
	RagdollData[character] = nil
end

-- ========================================
-- RAGDOLL STATE CHECK
-- ========================================

function PhysicsHelper.IsRagdolled(character: Model): boolean
	return RagdollData[character] ~= nil
end

return PhysicsHelper
