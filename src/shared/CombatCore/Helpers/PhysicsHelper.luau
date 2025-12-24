--[[
	Module: PhysicsHelper
	Type: Physics Utility Module (Pure Functions)
	Location: ReplicatedStorage.CombatCore.Helpers.PhysicsHelper
	Path: src/shared/CombatCore/Helpers/PhysicsHelper.luau
	
	Description:
		Provides stateless physics calculation functions for combat knockback.
		Uses modern Roblox physics APIs (AssemblyLinearVelocity) for optimal performance.
		Ragdoll-aware: respects HumanoidStateType.Physics to prevent interference.
		
	Features:
		- Modern AssemblyLinearVelocity API (replaces deprecated BodyVelocity)
		- Ragdoll state detection to prevent velocity reset during ragdoll
		- Automatic velocity cleanup after 0.1s (only if not ragdolled)
		- Server-side and client-side knockback support
		
	Phase 4 Refactoring:
		- Removed ragdoll state management (moved to server/CombatHandler/Physics/RagdollManager)
		- Now only contains stateless physics calculations
	
	Ragdoll Operations (Server-Only):
		For ragdoll operations, use RagdollManager on server:
		- RagdollManager:ApplyRagdoll(character, duration, knockbackDirection?, knockbackForce?)
		- RagdollManager:RemoveRagdoll(character)
		- RagdollManager:IsRagdolled(character)
	
	Author: Professional Roblox Scripter
	Created: December 11, 2025
	Updated: December 17, 2025 - Phase 4: Extracted RagdollManager
	Updated: December 21, 2025 - Removed deprecated ragdoll functions
	Updated: December 21, 2025 - Security Fix: Replaced BodyVelocity with AssemblyLinearVelocity
	Updated: December 23, 2025 - Added ragdoll-aware velocity reset logic
--]]

-- PhysicsHelper Module
local PhysicsHelper = {}

-- ========================================
-- KNOCKBACK
-- ========================================

---Applies knockback force to a character using modern physics API
---@param character Model The character to apply knockback to
---@param direction Vector3 Direction vector (will be normalized)
---@param force number Knockback force magnitude
function PhysicsHelper.ApplyKnockback(character: Model, direction: Vector3, force: number)
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart or not rootPart:IsA("BasePart") then
		return
	end
	
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	
	-- Apply knockback using modern AssemblyLinearVelocity (server-authoritative)
	-- Replaces deprecated BodyVelocity for better security and performance
	rootPart.AssemblyLinearVelocity = direction.Unit * force
	
	-- Only reset velocity if character is NOT in ragdoll state
	-- If ragdolled, the RagdollManager will handle physics
	local isRagdolled = humanoid:GetState() == Enum.HumanoidStateType.Physics
	
	if not isRagdolled then
		-- Reset velocity after 0.1 seconds for normal knockback
		task.delay(0.1, function()
			if rootPart and rootPart.Parent and humanoid and humanoid:GetState() ~= Enum.HumanoidStateType.Physics then
				rootPart.AssemblyLinearVelocity = Vector3.zero
			end
		end)
	end
end

return PhysicsHelper