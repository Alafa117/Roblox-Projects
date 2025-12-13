# Combat System - Setup & Configuration Guide

## 📋 Table of Contents
1. [Installation](#installation)
2. [Configuration](#configuration)
3. [Animation Setup](#animation-setup)
4. [Testing](#testing)
5. [Troubleshooting](#troubleshooting)
6. [API Reference](#api-reference)

---

## 🚀 Installation

The Combat System is already integrated into your project structure. All files are located in:

```
ReplicatedStorage/
└── Combat_System/
    ├── Core/           (Config, Types, Enums, Logger, Utility)
    ├── Animations/     (AnimationManager)
    ├── Mechanics/      (LightAttack, StrongAttack, Dash, Slide, Block)
    └── Network/        (NetworkManager)

ServerScriptService/
└── CombatService/      (CombatService, PlayerDataManager, Init.server)

StarterPlayer/StarterPlayerScripts/
└── CombatController/   (CombatController, InputHandler, InputBuffering, Init.client)
```

**No additional setup required** - The system will initialize automatically when you start the game.

---

## ⚙️ Configuration

### Step 1: Configure Combat Parameters

Edit `src/shared/Combat_System/Core/Config.luau`:

```lua
-- Example: Modify Light Attack
CombatConfig.LightAttack = {
    Damage = 15,              -- Change from 10 to 15
    Cooldown = 0.4,           -- Change from 0.5 to 0.4 (faster)
    ComboWindow = 1.5,        -- Change from 1.2 to 1.5 (easier combos)
    MaxComboCount = 5,        -- Change from 4 to 5 (longer combos)
    Range = 10,               -- Change from 8 to 10 (longer reach)
    -- ... etc
}
```

**Key Configuration Sections:**
- `LightAttack` - M1 parameters
- `StrongAttack` - M2 parameters
- `Block` - F defense parameters
- `Dash` - Q movement parameters
- `Slide` - C movement parameters
- `System` - Debug and performance settings

### Step 2: Enable Debug Mode

```lua
CombatConfig.System = {
    EnableDebugMode = true,     -- Set to true for testing
    HitboxVisualization = true, -- Shows hitboxes (useful for debugging)
}
```

---

## 🎬 Animation Setup

### Step 1: Upload Your Animations to Roblox

1. Create or purchase combat animations
2. Upload them to Roblox (Create > Development Items > Animation)
3. Copy the Asset IDs

### Step 2: Configure Animation IDs

Edit `src/shared/Combat_System/Core/Config.luau`:

```lua
CombatConfig.Animations = {
    LightAttack = {
        [1] = "rbxassetid://YOUR_COMBO1_ID",
        [2] = "rbxassetid://YOUR_COMBO2_ID",
        [3] = "rbxassetid://YOUR_COMBO3_ID",
        [4] = "rbxassetid://YOUR_COMBO4_ID",
    },
    StrongAttack = {
        Charge = "rbxassetid://YOUR_CHARGE_ID",
        Release = "rbxassetid://YOUR_RELEASE_ID",
    },
    Block = {
        Start = "rbxassetid://YOUR_BLOCK_START_ID",
        Hold = "rbxassetid://YOUR_BLOCK_HOLD_ID",
        End = "rbxassetid://YOUR_BLOCK_END_ID",
        Break = "rbxassetid://YOUR_BLOCK_BREAK_ID",
    },
    Dash = {
        Forward = "rbxassetid://YOUR_DASH_FORWARD_ID",
        Backward = "rbxassetid://YOUR_DASH_BACKWARD_ID",
        Left = "rbxassetid://YOUR_DASH_LEFT_ID",
        Right = "rbxassetid://YOUR_DASH_RIGHT_ID",
    },
    Slide = {
        Start = "rbxassetid://YOUR_SLIDE_ID",
    },
    Hit = {
        Light = "rbxassetid://YOUR_HIT_LIGHT_ID",
        Heavy = "rbxassetid://YOUR_HIT_HEAVY_ID",
        Blocked = "rbxassetid://YOUR_HIT_BLOCKED_ID",
    },
}
```

**Note:** The system will skip placeholder animations (rbxassetid://0) without errors.

### Step 3: Configure Sounds (Optional)

```lua
CombatConfig.Sounds = {
    LightAttack = {
        Swing = "rbxassetid://YOUR_SWING_SOUND",
        Hit = "rbxassetid://YOUR_HIT_SOUND",
    },
    -- ... etc
}
```

---

## 🧪 Testing

### Quick Test Checklist

1. **Start Test Server**
   - Open Roblox Studio
   - Press F5 (or click Test > Play)
   - Wait for both client and server to initialize

2. **Check Output Window**
   - Look for: `[CombatSystem] Combat System Server initialized successfully`
   - Look for: `[CombatSystem] Combat System Client initialized successfully`

3. **Test Each Action**

| Action | Input | Expected Behavior |
|--------|-------|-------------------|
| Light Attack | Left Click | Character attacks, combo counter increases |
| Strong Attack | Hold Right Click (0.8s) → Release | Charged attack with knockback |
| Dash | Press Q + Direction (WASD) | Quick dash in direction |
| Slide | Press C | Low slide forward |
| Block | Hold F | Character enters block stance |

4. **Test Combat Interactions**
   - Spawn 2+ players in test server
   - Attack another player
   - Verify damage is applied
   - Test blocking reduces damage
   - Test combos work correctly

### Debug Commands

Access the global instances for debugging:

```lua
-- In Command Bar (View > Command Bar)
print(_G.CombatService)      -- Server combat service
print(_G.CombatController)   -- Client combat controller

-- Check player data
local Players = game:GetService("Players")
local player = Players:GetChildren()[1]
local service = _G.CombatService
print(service._playerData)
```

### Viewing Logs

The Logger system tracks all events:

```lua
-- Get logger instance
local Logger = require(game.ReplicatedStorage.Combat_System.Core.Logger).GetInstance()

-- View log history
local logs = Logger:GetHistory()
for _, log in ipairs(logs) do
    print(log.Level, log.Message, log.Context)
end

-- Filter by level (Error only)
local errors = Logger:GetHistory(4) -- 4 = Error level
```

---

## 🔧 Troubleshooting

### Common Issues

**Issue: Combat actions don't work**
- ✅ Check Output for initialization messages
- ✅ Verify character is R6 (system designed for R6)
- ✅ Check that you're not in a blocked state (stunned/dead)
- ✅ Verify RemoteEvents exist in ReplicatedStorage.Combat_System.Network

**Issue: Animations don't play**
- ✅ Verify animation IDs are correct (not rbxassetid://0)
- ✅ Check that animations are R6 compatible
- ✅ Verify Animator exists on character Humanoid
- ✅ Check Output for animation loading errors

**Issue: Damage isn't applied**
- ✅ Verify you're testing with multiple players (not solo)
- ✅ Check that target is within range (8 studs for M1)
- ✅ Verify target is in front of attacker (120° angle)
- ✅ Check that target isn't invulnerable

**Issue: Cooldowns too long/short**
- ✅ Modify values in Config.luau
- ✅ Remember: Config is frozen, restart game after changes
- ✅ Check server-side cooldowns in CombatService

**Issue: Rate limiting triggered**
- ✅ Normal if spamming inputs too fast
- ✅ Adjust MAX_REQUESTS_PER_WINDOW in NetworkManager if needed
- ✅ Check Output for "Rate limit exceeded" warnings

### Performance Issues

If experiencing lag:

1. **Reduce Update Frequency**
```lua
-- In Config.luau
CombatConfig.System.NetworkUpdateRate = 0.1  -- Increase from 0.05
```

2. **Disable Debug Features**
```lua
CombatConfig.System.EnableDebugMode = false
CombatConfig.System.HitboxVisualization = false
```

3. **Optimize Hitbox Detection**
```lua
-- Use smaller hitbox sizes
CombatConfig.LightAttack.HitboxSize = Vector3.new(5, 5, 5)  -- Smaller = faster
```

---

## 📚 API Reference

### Client API (CombatController)

```lua
local controller = _G.CombatController

-- Get current state
local state = controller:GetCurrentState()  -- "Idle", "Attacking", etc.

-- Get combo count
local combo = controller:GetComboCount()    -- 0-4

-- Enable/Disable
controller:SetEnabled(false)                -- Disable combat system
controller:SetEnabled(true)                 -- Re-enable

-- Check if enabled
local isEnabled = controller:IsEnabled()
```

### Server API (CombatService)

```lua
local service = _G.CombatService

-- Apply damage manually
local hitData = service:ApplyDamage(attacker, victim, 50)

-- Access player data
local ServerScriptService = game:GetService("ServerScriptService")
local PlayerDataManager = require(ServerScriptService.CombatService.PlayerDataManager)
local dataManager = PlayerDataManager.GetInstance()

local data = dataManager:GetPlayerData(player)
print(data.CurrentState, data.ComboCount)

-- Set player state
dataManager:SetPlayerState(player, "Stunned")

-- Apply status effects
dataManager:SetInvulnerable(player, true)
dataManager:SetStunned(player, true, 2.0)  -- 2 second stun
dataManager:SetBlocking(player, true)
```

### Logger API

```lua
local Logger = require(game.ReplicatedStorage.Combat_System.Core.Logger).GetInstance()

-- Log at different levels
Logger:Debug("Debug message", {data = "value"})
Logger:Info("Info message")
Logger:Warning("Warning message")
Logger:Error("Error message")
Logger:Critical("Critical error")

-- Get logs
local allLogs = Logger:GetHistory()
local errors = Logger:GetHistory(4)  -- Errors only

-- Clear history
Logger:ClearHistory()

-- Flush logs
Logger:Flush()

-- Configure
Logger:SetMinLevel(2)  -- Info and above only
Logger:SetEnabled(false)
```

---

## 🎯 Next Steps

1. **Replace Animation IDs** - Upload and configure your animations
2. **Tune Combat Feel** - Adjust damage, cooldowns, ranges in Config
3. **Add VFX/SFX** - Implement visual and sound effects (currently placeholder)
4. **Extend System** - Add new mechanics by following existing patterns
5. **Test Thoroughly** - Test with multiple players in various scenarios

---

## 📝 Notes

- System is **server-authoritative** - client cannot cheat
- **R6 avatars only** - R15 support would require modifications
- **Rate limiting** protects against exploits (20 requests/second)
- **Combo system** auto-resets after 1.2 seconds
- **Perfect blocks** work within 0.2 seconds of blocking
- **I-frames** during dash prevent all damage for 0.15s

---

**System created by: Professional Roblox Scripter**
**Date: December 11, 2025**
**Version: 1.0**
