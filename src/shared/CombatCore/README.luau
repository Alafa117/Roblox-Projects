--[[
	Module: README
	Type: Documentation Module
	Location: ReplicatedStorage.CombatCore.README
	Path: src/shared/CombatCore/README.luau
	
	Description:
		Quick reference documentation for the Combat System.
		This module returns documentation strings for in-game help.
	
	Author: Professional Roblox Scripter
	Created: December 11, 2025
--]]

local README = {}

README.SYSTEM_INFO = [[
===========================================
      COMBAT SYSTEM v1.0
===========================================

A professional, scalable combat system for R6 Roblox games.

FEATURES:
- Light Attack (M1) with 4-hit combo system
- Strong Attack (M2) with charge mechanic
- Dash (Q) with directional movement
- Slide (C) for evasive maneuvers
- Block (F) with perfect block timing
- Server-authoritative validation
- Rate limiting and anti-exploit
- Comprehensive logging system
- Modular and scalable architecture

CONTROLS:
- M1 (Left Click): Light Attack
- M2 (Right Click Hold): Strong Attack
- Q: Dash (direction based on WASD)
- C: Slide
- F (Hold): Block

DOCUMENTATION:
See CombatCore_GUIDE.md for full setup instructions.
]]

README.ARCHITECTURE = [[
SYSTEM ARCHITECTURE:

Client Side:
- InputHandler: Detects player input
- InputBuffering: Buffers inputs during actions
- CombatController: Main client controller
- AnimationManager: Handles all animations

Server Side:
- CombatService: Main server service
- PlayerDataManager: Manages player combat data
- Mechanics: LightAttack, StrongAttack, Dash, Slide, Block

Shared:
- Config: All combat parameters
- Enums: Type-safe constants
- Types: Type definitions
- Logger: Advanced logging
- Utility: Helper functions
- NetworkManager: Client-server communication
]]

README.CONFIGURATION = [[
QUICK CONFIGURATION:

1. Edit Config.luau in CombatCore/Core/Config
2. Replace animation IDs (search for "rbxassetid://0")
3. Adjust damage, cooldowns, ranges as needed
4. Enable debug mode for testing:
   CombatConfig.System.EnableDebugMode = true

5. Test in Play mode with multiple players

ANIMATION REQUIREMENTS:
- Must be R6 compatible
- Upload to Roblox and get Asset IDs
- Replace placeholder IDs in Config.Animations

COMMON SETTINGS:
- LightAttack.Damage: Base damage (default 10)
- LightAttack.Cooldown: Time between attacks (default 0.5s)
- StrongAttack.ChargeTime: Time to fully charge (default 0.8s)
- Dash.Speed: Movement speed (default 100)
- Block.DamageReduction: Damage blocked (default 70%)
]]

README.DEBUGGING = [[
DEBUGGING TIPS:

1. Check Output window for initialization messages
2. Look for errors in red
3. Enable debug mode in Config
4. Access global instances:
   - _G.CombatController (client)
   - _G.CombatService (server)

5. View logs:
   local Logger = require(game.ReplicatedStorage.CombatCore.Core.Logger).GetInstance()
   print(Logger:GetHistory())

6. Check player data (server):
   local dataManager = require(ServerScriptService.CombatService.PlayerDataManager).GetInstance()
   local data = dataManager:GetPlayerData(player)
   print(data.CurrentState, data.ComboCount)

COMMON ISSUES:
- No animations: Check IDs aren't "rbxassetid://0"
- No damage: Verify multiple players, correct range
- Rate limiting: Normal if spamming, increase limit if needed
- R15 avatars: System designed for R6 only
]]

README.API_EXAMPLES = [[
API USAGE EXAMPLES:

-- Get combat controller (client)
local controller = _G.CombatController
local state = controller:GetCurrentState()
local combo = controller:GetComboCount()

-- Disable combat temporarily (client)
controller:SetEnabled(false)
task.wait(5)
controller:SetEnabled(true)

-- Apply custom damage (server)
local service = _G.CombatService
service:ApplyDamage(attacker, victim, 50)

-- Manage player state (server)
local dataManager = require(ServerScriptService.CombatService.PlayerDataManager).GetInstance()
dataManager:SetStunned(player, true, 2.0)
dataManager:SetInvulnerable(player, true)

-- Access logs
local Logger = require(game.ReplicatedStorage.CombatCore.Core.Logger).GetInstance()
local errors = Logger:GetHistory(4)  -- Errors only
]]

README.EXTENDING_SYSTEM = [[
EXTENDING THE COMBAT SYSTEM:

To add a new combat mechanic:

1. Create new module in CombatCore/Mechanics/
2. Follow pattern from existing mechanics (LightAttack, etc.)
3. Implement Execute() and Validate() methods
4. Add configuration to Config.luau
5. Register in CombatService:_LoadMechanics()
6. Add animation IDs if needed
7. Create network event in Enums if needed

Example Structure:
- Execute(player, data): Main logic
- Validate(player, data): Validation
- _DetectHits(): Hitbox detection
- _ApplyDamage(): Damage application
- _BroadcastAction(): Client sync

BEST PRACTICES:
- Always validate on server
- Use Config for all parameters
- Log important events
- Follow existing naming conventions
- Keep mechanics decoupled
- Test thoroughly with multiple players
]]

README.PERFORMANCE_NOTES = [[
PERFORMANCE OPTIMIZATIONS:

Implemented optimizations:
✓ Region3 and OverlapParams for hitbox detection
✓ Singleton pattern for managers
✓ Object pooling for BodyVelocity instances
✓ Rate limiting to prevent spam
✓ Efficient callback/handler lookups
✓ Task.spawn for non-blocking callbacks
✓ Auto-cleanup of connections
✓ Minimal network traffic

If experiencing lag:
- Increase NetworkUpdateRate in Config
- Disable debug mode and visualization
- Reduce hitbox sizes
- Lower max combo count
- Decrease animation complexity

TARGET PERFORMANCE:
- <1ms per attack action
- <0.5ms network latency
- <5 MB memory footprint
- Supports 50+ concurrent players
]]

function README.Print(section: string?)
	if not section then
		print(README.SYSTEM_INFO)
		return
	end
	
	local content = README[section:upper()]
	if content then
		print(content)
	else
		warn("Invalid section:", section)
		print("Available sections: SYSTEM_INFO, ARCHITECTURE, CONFIGURATION, DEBUGGING, API_EXAMPLES, EXTENDING_SYSTEM, PERFORMANCE_NOTES")
	end
end

return README
