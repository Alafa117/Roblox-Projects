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
	
	-- Store original Motor6D data
	local characterRagdollData = {}
	RagdollData[character] = characterRagdollData
	
	-- Break all joints to create ragdoll effect
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("Motor6D") then
			local socket = Instance.new("BallSocketConstraint")
			local att0 = Instance.new("Attachment")
			local att1 = Instance.new("Attachment")
			
			-- Position attachments at Motor6D positions to maintain limb structure
			att0.CFrame = descendant.C0
			att1.CFrame = descendant.C1
			
			att0.Parent = descendant.Part0
			att1.Parent = descendant.Part1
			
			-- Configure socket for natural movement
			socket.Attachment0 = att0
			socket.Attachment1 = att1
			socket.LimitsEnabled = true
			socket.UpperAngle = 45 -- Limit rotation to prevent unnatural bending
			socket.TwistLimitsEnabled = true
			socket.TwistLowerAngle = -45
			socket.TwistUpperAngle = 45
			socket.Parent = descendant.Parent
			
			-- Store data for restoration
			table.insert(characterRagdollData, {
				Motor = descendant,
				Socket = socket,
				Att0 = att0,
				Att1 = att1,
			})
			
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
		task.cancel(characterRagdollData.Thread)
	end
	
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
	
	-- Restore all Motor6Ds
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

return PhysicsHelper
