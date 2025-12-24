# CombatHandler Organization

## 📁 Folder Structure

```
CombatHandler/
├── Init.server.luau          # Entry point
├── Core/                     # Core services
│   ├── CombatService.luau
│   ├── ActionProcessor.luau
│   └── PlayerDataManager.luau
├── Systems/                  # Support systems
│   ├── CooldownManager.luau
│   └── DamageCalculator.luau
├── Mechanics/                # Combat mechanics
│   ├── BaseAttack.luau
│   ├── LightAttack.luau
│   └── StrongAttack.luau
├── Helpers/                  # Helper utilities
│   └── AttackHelper.luau
└── Physics/                  # Physics systems
    └── RagdollManager.luau
```

---

## 🎯 Core/

**Purpose:** Main combat system services and logic

- **CombatService.luau** - Singleton service that manages the entire combat system
- **ActionProcessor.luau** - Processes and validates combat actions
- **PlayerDataManager.luau** - Manages player combat state and data

---

## ⚙️ Systems/

**Purpose:** Support systems for combat functionality

- **CooldownManager.luau** - Handles action cooldowns (server-side tracking)
- **DamageCalculator.luau** - Calculates damage with modifiers and blocking

---

## 🥊 Mechanics/

**Purpose:** Individual combat mechanics implementations

- **BaseAttack.luau** - Base class for attack mechanics
- **LightAttack.luau** - Light attack mechanic (M1)
- **StrongAttack.luau** - Strong attack mechanic (M2)

---

## 🛠️ Helpers/

**Purpose:** Utility helpers for combat operations

- **AttackHelper.luau** - Helper functions for attack processing and validation

---

## 🎭 Physics/

**Purpose:** Physics-related combat systems

- **RagdollManager.luau** - Manages ragdoll effects for combat hits

---

**Last Updated:** December 23, 2025
**Organization:** Modular folder structure for better maintainability
