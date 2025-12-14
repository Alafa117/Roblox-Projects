# 🎯 Combat System - NPC Testing Guide

## Quick Setup for Testing

### Create 3 Test NPCs (Stationary Dummies)

Create exactly **3 NPCs** in `Workspace/NPCs/` folder:

1. **Dummy_M1** - Tests Light Attack combos
2. **Dummy_M2** - Tests Strong Attack + knockback
3. **Dummy_Block** - Tests Block mechanics (damage reduction + block breaking)

### NPC Naming Rules

| Name Contains | Behavior | What to Test |
|---------------|----------|--------------|
| `M1` or `Light` | Stands still, no attacks | Your M1 combos on stationary target |
| `M2` or `Strong` or `Heavy` | Stands still, no attacks | Your M2 heavy attack + knockback |
| `Block` or `Shield` or `Defend` | Stands still, blocks constantly | Block damage reduction (65%), block breaking with M2 |

**Important:** NPCs are **STATIONARY** - they don't move or attack. They're training dummies.

## Step-by-Step Setup

### 1. Create NPCs Folder
```
Workspace/
└── NPCs/  ← Create this folder
```

### 2. Insert 3 R6 Rigs

In Roblox Studio:
- **Model** → **Rig Builder** → **R6** (NOT R15!)
- Insert 3 times
- Place them in `Workspace/NPCs/`

### 3. Rename the Rigs

- Rig 1 → `Dummy_M1`
- Rig 2 → `Dummy_M2`
- Rig 3 → `Dummy_Block`

### 4. Position Them

Spread them out so you can test individually:
```
Spawn Point
    ↓
[Dummy_M1]  ←→  [Dummy_M2]  ←→  [Dummy_Block]
  (5 studs apart from each other)
```

### 5. Play Game

Press **Play** in Studio - the NPCs will be ready for testing.

## Testing Each NPC

### 🥊 Dummy_M1 (Light Attack Testing)

**What it does:**
- Stands completely still
- Takes damage from your attacks
- Does NOT attack back
- Does NOT move

**What YOU test:**
1. Get close to Dummy_M1
2. Press **M1** (Click) 6 times rapidly
3. **Expected:**
   - Hits 1-5: Small damage, quick hits
   - Hit 6 (Finisher): BIG damage + ragdoll + knockback
4. Check combo resets if you wait too long (1.5s)
5. Check damage numbers appear

### 💥 Dummy_M2 (Strong Attack Testing)

**What it does:**
- Stands completely still
- Takes damage from your attacks
- Does NOT attack back
- Does NOT move

**What YOU test:**
1. Get close to Dummy_M2
2. **Hold M2** (Hold Click)
3. **Expected:**
   - Heavy damage (20 HP)
   - Strong knockback
   - Ragdoll effect (2 seconds)
   - NPC flies backward
4. Check cooldown works (2.5 seconds)
5. Check hitbox visualization (if debug enabled)

### 🛡️ Dummy_Block (Block Testing)

**What it does:**
- Stands completely still
- **Constantly blocking** (shield up)
- Takes reduced damage when blocking
- Does NOT attack back
- Does NOT move

**What YOU test:**

**Test 1: Damage Reduction (65%)**
1. Attack Dummy_Block with **M1**
2. **Expected:**
   - Damage is reduced to 35% (8 damage → ~3 damage)
   - Block animation plays
   - Damage numbers show reduced amount

**Test 2: Block Breaking**
1. Use **M2** (Hold Click) on Dummy_Block
2. **Expected:**
   - Block BREAKS
   - NPC gets stunned (1.8 seconds)
   - Takes full damage during stun
   - You can attack freely during stun window
3. After stun, block reactivates automatically

**Test 3: Block Cooldown**
1. Break block with M2
2. Wait for cooldown
3. Block becomes active again

## What NPCs DON'T Do

- ❌ Don't move or walk
- ❌ Don't chase the player
- ❌ Don't rotate to face you
- ❌ Don't attack you
- ❌ Don't use any abilities on you

## What NPCs DO

- ✅ Stand perfectly still
- ✅ Take damage from your attacks
- ✅ React to hits (animations, knockback)
- ✅ Dummy_Block maintains blocking stance
- ✅ Show health reduction
- ✅ Die when health reaches 0

## Expected Damage Values

| Your Attack | No Block | With Block (65% reduction) |
|-------------|----------|---------------------------|
| M1 Hit 1-5 | 8 damage | ~3 damage |
| M1 Finisher (6th) | 8 damage | ~3 damage |
| M2 Strong | 20 damage | ~7 damage (if not broken) |
| M2 vs Block | 20 damage | **Block BREAKS** → Full damage |

## Console Output

When NPCs register, you'll see:
```
[NPC AI] Registered NPC: Dummy_M1 (R6) - Action: LightAttack ONLY
[NPC AI] Registered NPC: Dummy_M2 (R6) - Action: StrongAttack ONLY
[NPC AI] Registered NPC: Dummy_Block (R6) - Action: Block ONLY
[NPC AI] Dummy_Block started blocking
```

## Troubleshooting

### NPCs are moving around
- ✅ Check NPC names contain correct keywords
- ✅ Make sure SimpleNPCAI is properly configured
- ✅ Check console for registration messages

### Dummy_Block not blocking
- ✅ Verify name contains "Block", "Shield", or "Defend"
- ✅ Check console: should say "started blocking"
- ✅ Look for block animation playing

### No damage numbers showing
- ✅ Enable debug mode in Config.luau
- ✅ Set `ShowHitboxes = true`
- ✅ Check combat logs in Output

### NPCs die too fast
- ✅ Increase Humanoid.MaxHealth (default 100)
- ✅ Set to 500+ for training dummies
- ✅ Or adjust damage in Config.luau

### Block not reducing damage
- ✅ Verify block state is active (check animation)
- ✅ Check DamageCalculator is processing block
- ✅ Ensure NPCCombatHelper.StartBlock() was called

## Configuration

### NPC Health (Recommended)
```lua
Dummy_M1: 300 HP (survives ~37 M1 hits)
Dummy_M2: 500 HP (survives ~25 M2 hits)
Dummy_Block: 1000 HP (survives longer with block)
```

To change: Select NPC → Properties → Humanoid → MaxHealth

### Damage Values
Edit `src/shared/CombatCore/Core/Config.luau`:
```lua
Config.LightAttack.Damage = 8
Config.StrongAttack.Damage = 20
Config.Block.DamageReduction = 0.65  -- 65% reduction
```

## File Structure

```
ServerScriptService/
└── Testing/
    ├── SimpleNPCAI.server.luau      ← AI system (stationary mode)
    ├── NPCCombatHelper.luau         ← NPC action functions
    └── EXAMPLE_NPCTestScript.server.luau

Workspace/
└── NPCs/                            ← Your test dummies
    ├── Dummy_M1
    ├── Dummy_M2
    └── Dummy_Block
```

## Testing Checklist

### Light Attack (M1) - Dummy_M1
- [ ] Hit 1-5 deal 8 damage each
- [ ] Hit 6 (finisher) deals 8 damage + ragdoll
- [ ] Combo resets after 1.5s delay
- [ ] Damage numbers appear
- [ ] Knockback works on finisher

### Strong Attack (M2) - Dummy_M2
- [ ] Deals 20 damage
- [ ] Strong knockback pushes NPC back
- [ ] Ragdoll lasts ~2 seconds
- [ ] Cooldown is 2.5 seconds
- [ ] Hitbox visualizes (if debug on)

### Block - Dummy_Block
- [ ] Block animation plays constantly
- [ ] M1 damage reduced to ~35% (~3 damage)
- [ ] M2 breaks block
- [ ] NPC stunned 1.8s after block break
- [ ] Full damage during stun
- [ ] Block reactivates after cooldown

### General
- [ ] NPCs don't move from spawn position
- [ ] NPCs don't attack player
- [ ] NPCs take damage correctly
- [ ] Health bars update
- [ ] Death works properly
- [ ] Respawn works (if enabled)

## Debug Mode

Enable in `Config.luau`:
```lua
Debug = {
    Enabled = true,
    ShowHitboxes = true,
    LogLevel = "All"
}
```

This shows:
- Hitbox visualizations (red boxes)
- Damage numbers
- Combat state logs
- Action execution logs

## Tips

1. **Test One Mechanic at a Time** - Focus on one dummy
2. **Increase Health** - Set MaxHealth to 500-1000 for longer testing
3. **Use Debug Mode** - See exactly what's happening
4. **Check Output** - Look for error messages or logs
5. **Distance** - Stand within 10 studs for M1, 15 for M2
6. **R6 Only** - System doesn't support R15 avatars

## Common Issues

**Issue:** NPC not taking damage
- ✅ Verify you're in range (10 studs)
- ✅ Check hitbox is detecting (debug mode)
- ✅ Ensure NPC has Humanoid with Health > 0

**Issue:** Block not working
- ✅ Verify NPC name has "Block" in it
- ✅ Check console for "started blocking" message
- ✅ Look for block animation playing
- ✅ Test with M1 to see reduced damage

**Issue:** Can't break block
- ✅ Use M2 (Strong Attack), not M1
- ✅ Check M2 is executing properly
- ✅ Verify you're in range (15 studs)

---

**Version:** 1.0  
**Last Updated:** December 14, 2025  
**Supported Avatars:** R6 Only
