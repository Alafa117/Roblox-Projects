--[[
	Module: SystemConfig
	Type: Configuration Module
	Location: ReplicatedStorage.CombatCore.Config.SystemConfig
	Path: src/shared/CombatCore/Config/SystemConfig.luau
	
	Description:
		System-level configuration settings.
		Contains global toggles and system-wide parameters.
		
		Phase 3 Refactoring - Extracted from Config.luau
	
	Author: Professional Roblox Scripter
	Created: December 18, 2025 (Phase 3 - Task 1)
--]]

local SystemConfig = {}

-- ========================================
-- DEBUG SETTINGS
-- ========================================

SystemConfig.EnableDebugMode = false -- Global debug toggle

-- ========================================
-- VALIDATION SETTINGS
-- ========================================

-- Enable runtime type validation
-- true = Validation enabled (development/testing)
-- false = Validation disabled (production - 0 overhead)
--
-- Benefits of disabling in production:
-- - 0 performance overhead (validators not called)
-- - Smaller script size (validation code eliminated by optimizer)
-- - Faster execution (no type checking)
--
-- ⚠️ PRODUCTION SETTING ⚠️
-- Set to true ONLY during development/testing
-- Set to false for production builds (recommended)
SystemConfig.EnableTypeValidation = false -- Toggle runtime validation

return table.freeze(SystemConfig)
