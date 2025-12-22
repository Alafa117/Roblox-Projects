--[[
	Module: NetworkEventCategories
	Type: Configuration Module
	Location: ReplicatedStorage.CombatCore.Network.NetworkEventCategories
	
	Description:
		Categorizes network events as Critical or Non-Critical.
		Determines which events should use UnreliableRemoteEvent vs RemoteEvent.
		
		Critical events: Use RemoteEvent (guaranteed delivery)
		Non-Critical events: Use UnreliableRemoteEvent (lower latency)
	
	Usage:
		if NetworkEventCategories.IsVFXEvent(eventType) then
			NetworkServer:BroadcastVFX(eventType, data)
		else
			NetworkServer:SendToAllClients(eventType, data)
		end
	
	Performance: TODO #9
	
	Author: Professional Roblox Scripter
	Created: December 21, 2025
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
