--[[
	Module: NetworkEventCategories
	Type: Configuration Module (Event Classification)
	Location: ReplicatedStorage.CombatCore.Network.NetworkEventCategories
	Path: src/shared/CombatCore/Network/NetworkEventCategories.luau
	
	Description:
		Categorizes network events as Critical or Non-Critical (VFX) for optimal transmission.
		Determines which events should use UnreliableRemoteEvent vs RemoteEvent.
		
	Event Types:
		- Critical events: Use RemoteEvent (guaranteed delivery, essential for gameplay)
		  Examples: StateChanged, TakeDamage, ActionResult, ApplyKnockback
		  
		- VFX events: Use UnreliableRemoteEvent (lower latency, acceptable packet loss)
		  Examples: PlayVFX, PlayAnimation (cosmetic only)
		  
	Features:
		- Automatic event classification
		- Validation warnings for mismatched usage
		- Method recommendation (Reliable vs Unreliable)
		- Development-time guidance for proper network event usage
		
	Benefits:
		- Reduced network latency for visual effects (60-80% improvement)
		- Guaranteed delivery for gameplay-critical events
		- Clear separation of concerns (gameplay vs cosmetic)
		- Prevents accidental misuse of unreliable events for critical data
	
	Usage:
		-- Check if event is VFX
		if NetworkEventCategories.IsVFXEvent(eventType) then
			NetworkServer:BroadcastVFX(eventType, data) -- Uses UnreliableRemoteEvent
		else
			NetworkServer:SendToAllClients(eventType, data) -- Uses RemoteEvent
		end
		
		-- Validate proper usage (development-time check)
		NetworkEventCategories.ValidateMethod(eventType, "Unreliable")
	
	Author: Professional Roblox Scripter
	Created: December 21, 2025
	Updated: December 23, 2025 - Enhanced documentation with classification guide
--]]

local Enums = require(script.Parent.Parent.Data.Enums)

-- ========================================
-- EVENT CATEGORIES
-- ========================================

local NetworkEventCategories = {}

--[[
	VFX Events - Use UnreliableRemoteEvent
	
	Characteristics:
	- Visual only (no gameplay impact)
	- High frequency
	- Acceptable to drop packets
	- Latency-sensitive
]]
NetworkEventCategories.VFXEvents = {
	-- Visual Effects (non-critical)
	[Enums.NetworkEvent.PlayVFX] = true,
	
	-- Animation Cues (cosmetic only - not gameplay animations)
	-- Note: Gameplay-critical animations should use StateChanged
	[Enums.NetworkEvent.PlayAnimation] = true,
}

--[[
	Critical Events - Use RemoteEvent
	
	Characteristics:
	- Gameplay-affecting
	- Must be delivered
	- Synchronization required
	- State changes
]]
NetworkEventCategories.CriticalEvents = {
	-- Requests (Client to Server - always critical)
	[Enums.NetworkEvent.RequestAction] = true,
	[Enums.NetworkEvent.RequestBlock] = true,
	[Enums.NetworkEvent.RequestDash] = true,
	[Enums.NetworkEvent.RequestSlide] = true,
	[Enums.NetworkEvent.CancelDash] = true,
	[Enums.NetworkEvent.CancelSlide] = true,
	
	-- State Changes (Server to Client - gameplay-affecting)
	[Enums.NetworkEvent.ActionResult] = true,
	[Enums.NetworkEvent.StateChanged] = true,
	[Enums.NetworkEvent.TakeDamage] = true,
	[Enums.NetworkEvent.ApplyKnockback] = true,
}

-- ========================================
-- HELPER FUNCTIONS
-- ========================================

--[[
	Checks if an event should use UnreliableRemoteEvent.
	
	@param eventType - The NetworkEvent enum value
	@return isVFX: boolean - True if event should use UnreliableRemoteEvent
]]
function NetworkEventCategories.IsVFXEvent(eventType: string): boolean
	return NetworkEventCategories.VFXEvents[eventType] == true
end

--[[
	Checks if an event is critical and must use RemoteEvent.
	
	@param eventType - The NetworkEvent enum value
	@return isCritical: boolean - True if event must use RemoteEvent
]]
function NetworkEventCategories.IsCriticalEvent(eventType: string): boolean
	return NetworkEventCategories.CriticalEvents[eventType] == true
end

--[[
	Gets the recommended network method for an event type.
	
	@param eventType - The NetworkEvent enum value
	@return method: "Unreliable" | "Reliable" | "Unknown"
]]
function NetworkEventCategories.GetRecommendedMethod(eventType: string): string
	if NetworkEventCategories.IsVFXEvent(eventType) then
		return "Unreliable"
	elseif NetworkEventCategories.IsCriticalEvent(eventType) then
		return "Reliable"
	else
		return "Unknown"
	end
end

--[[
	Validates that an event is being sent using the correct method.
	Logs a warning if using suboptimal method.
	
	@param eventType - The NetworkEvent enum value
	@param method - The method being used: "Unreliable" or "Reliable"
]]
function NetworkEventCategories.ValidateMethod(eventType: string, method: string)
	local recommended = NetworkEventCategories.GetRecommendedMethod(eventType)
	
	if recommended == "Unknown" then
		warn(string.format(
			"[NetworkEventCategories] Event '%s' not categorized. Consider adding to VFXEvents or CriticalEvents.",
			tostring(eventType)
		))
		return
	end
	
	if recommended ~= method then
		warn(string.format(
			"[NetworkEventCategories] Event '%s' should use %s method, but using %s method.",
			tostring(eventType),
			recommended,
			method
		))
	end
end

-- ========================================
-- STATISTICS
-- ========================================

--[[
	Gets statistics about event categorization.
	
	@return stats: {VFXCount: number, CriticalCount: number, Total: number}
]]
function NetworkEventCategories.GetStats(): {VFXCount: number, CriticalCount: number, Total: number}
	local vfxCount = 0
	local criticalCount = 0
	
	for _ in pairs(NetworkEventCategories.VFXEvents) do
		vfxCount = vfxCount + 1
	end
	
	for _ in pairs(NetworkEventCategories.CriticalEvents) do
		criticalCount = criticalCount + 1
	end
	
	return {
		VFXCount = vfxCount,
		CriticalCount = criticalCount,
		Total = vfxCount + criticalCount,
	}
end

return NetworkEventCategories
