# Combat System - R6 Only

Professional combat system for Roblox with AI testing support.

## Core Mechanics

### Light Attack (M1)
- **Combo**: 6-hit chain (hits 1-5 → finisher on 6th)
- **Damage**: 8 per hit
- **Finisher**: Ragdoll + knockback
- **Cooldown**: 0.5s (applies after finisher)
- **Range**: 10 studs

### Strong Attack (M2)
- **Damage**: 20
- **Effect**: Heavy knockback + 2s ragdoll
- **Block Breaking**: Breaks opponent's block → 1.8s stun
- **Cooldown**: 2.5s
- **Range**: 15 studs

### Dash (Q)
- **Speed**: 60 studs/s
- **Duration**: 0.45s
- **Distance**: ~30 studs
- **Cooldown**: 2s
- **Cancels**: M1, M2, Slide (NOT Block)

### Slide (C)
- **Speed**: 45 studs/s
- **Duration**: 0.6s
- **Distance**: ~27 studs
- **Cooldown**: 2.5s
- **Cancels**: M1, M2, Dash (NOT Block)

### Block (F)
- **Damage Reduction**: 65%
- **Duration**: Hold to maintain
- **Break Punishment**: 1.8s stun when broken by M2
- **Perfect Block**: 98% reduction (first 0.5s)
- **Cannot Cancel**: Other actions cannot interrupt block

## Action Rules

| Action | Can Use During | Cannot Use During |
|--------|---------------|-------------------|
| M1 | Idle, Attacking (combo) | Dashing, Sliding, Blocking |
| M2 | Idle | Attacking, Dashing, Sliding, Blocking |
| Dash | Idle, Attacking, Dashing, Sliding | Blocking |
| Slide | Idle, Attacking, Dashing, Sliding | Blocking |
| Block | Idle, Blocking | Attacking, Dashing, Sliding |

## Testing with NPCs

### Quick Setup
1. Create `Workspace/NPCs/` folder
2. Insert 3 R6 Rigs: `Dummy_M1`, `Dummy_M2`, `Dummy_Block`
3. Set their MaxHealth to 500+ HP
4. Play game

### NPC Types
| Name | Behavior | Test Purpose |
|------|----------|-------------|
| `Dummy_M1` / `*_Light` | Stationary target | M1 combo chains |
| `Dummy_M2` / `*_Strong` | Stationary target | M2 knockback/ragdoll |
| `Dummy_Block` / `*_Shield` | Constantly blocks | Block reduction (65%) & breaking |

### Expected Results
- **M1 on Dummy_Block**: ~3 damage (65% reduction)
- **M2 on Dummy_Block**: Block breaks → 1.8s stun → full damage
- **NPCs**: Don't move, don't attack (stationary training dummies)

## File Structure

```
src/
├── client/CombatFramework/
│   ├── CombatController.luau    # Main controller
│   ├── InputHandler.luau        # Input processing
│   ├── StateManager.luau        # State transitions
│   └── ActionHandler.luau       # Action execution
├── server/
│   ├── CombatHandler/
│   │   ├── CombatService.luau       # Main service
│   │   ├── ActionProcessor.luau     # Action logic
│   │   ├── DamageCalculator.luau    # Damage system
│   │   └── PlayerDataManager.luau   # Data tracking
│   └── Testing/
│       ├── SimpleNPCAI.server.luau  # AI system
│       └── NPCCombatHelper.luau     # NPC utilities
└── shared/CombatCore/
    ├── Core/
    │   ├── Config.luau          # All settings
    │   ├── Types.luau           # Type definitions
    │   └── Enums.luau           # Constants
    ├── Mechanics/
    │   ├── LightAttack.luau
    │   ├── StrongAttack.luau
    │   ├── Dash.luau
    │   ├── Slide.luau
    │   └── Block.luau
    └── Network/
        └── NetworkManager.luau
```

## Configuration

### Basic Settings
Edit `src/shared/CombatCore/Core/Config.luau`:

```lua
CombatConfig.LightAttack = {
    Damage = 8,
    MaxComboCount = 6,
    ComboWindow = 1.5,
    Cooldown = 0.5,
    Range = 10,
    HitboxSize = Vector3.new(6, 6, 6)
}

CombatConfig.StrongAttack = {
    Damage = 20,
    Cooldown = 2.5,
    Knockback = 25,
    StunDuration = 1.2,
    RagdollDuration = 2.0,
    Range = 15,
    HitboxSize = Vector3.new(8, 8, 8)
}

CombatConfig.Block = {
    DamageReduction = 0.65,        -- 65%
    PerfectBlockWindow = 0.5,      -- First 0.5s
    PerfectBlockReduction = 0.98,  -- 98%
    BlockBreakStunDuration = 1.8,
    Cooldown = 0.5
}

CombatConfig.Dash = {
    Speed = 60,
    Duration = 0.45,
    Cooldown = 2.0,
    Distance = 30,
    FrictionMultiplier = 0.3
}

CombatConfig.Slide = {
    Speed = 45,
    Duration = 0.6,
    Cooldown = 2.5,
    Distance = 27,
    FrictionMultiplier = 0.4
}
```

### Animation IDs
```lua
CombatConfig.Animations = {
    LightAttack = {
        Combo1 = "rbxassetid://YOUR_ID",
        Combo2 = "rbxassetid://YOUR_ID",
        -- ... up to Combo6
    },
    StrongAttack = {
        Charge = "rbxassetid://YOUR_ID",
        Release = "rbxassetid://YOUR_ID"
    },
    Block = {
        Start = "rbxassetid://YOUR_ID",
        Hold = "rbxassetid://YOUR_ID",
        End = "rbxassetid://YOUR_ID",
        Break = "rbxassetid://YOUR_ID"
    },
    Dash = {
        Forward = "rbxassetid://YOUR_ID",
        -- Backward, Left, Right
    },
    Slide = {
        Start = "rbxassetid://YOUR_ID"
    }
}
```

### Debug Settings
```lua
CombatConfig.Debug = {
    Enabled = false,        -- Enable debug logging
    ShowHitboxes = false,   -- Visualize hitboxes
    LogLevel = "Warning"    -- "All", "Info", "Warning", "Error"
}
```

## Troubleshooting

### NPCs not working
- Verify R6 rigs (NOT R15)
- Check NPC names contain keywords: `Block`, `M1`, `M2`
- Look for registration logs: `[NPC AI] Registered NPC...`

### No damage to NPCs
- Ensure within range (10 studs for M1, 15 for M2)
- Check NPC has Humanoid with Health > 0
- Verify hitbox detection (enable debug mode)

### Block not reducing damage
- Config uses `DamageReduction`, not `BlockDamageReduction`
- Check NPC blocking state in logs
- Verify `NPCCombatHelper.IsNPCBlocking()` returns true

### M2 not appearing after M1
- M2 can only execute from Idle state
- State resets to Idle 0.4s after M1
- Check cooldown is separate (M1 ≠ M2)

## Debug Mode

Enable in Config.luau:
```lua
Debug = {
    Enabled = true,
    ShowHitboxes = true,
    LogLevel = "All"
}
```

Shows:
- Red hitbox visualizations
- Damage numbers
- Combat logs in Output
- Action execution details

## Requirements

- **Avatars**: R6 ONLY (R15 not supported)
- **Rojo**: Version 7+
- **Engine**: Luau type checking enabled

## Version

**1.0** - December 14, 2025
