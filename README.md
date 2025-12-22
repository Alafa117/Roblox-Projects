# Combat System - Roblox R6

Sistema de combate profesional para Roblox con arquitectura modular y optimizada.

## 🎮 Características

- ✅ **Light Attack (M1)** - Sistema de combos de 6 golpes
- ✅ **Strong Attack (M2)** - Ataque pesado con ragdoll
- ✅ **Dash (Q)** - Movimiento direccional con i-frames
- ✅ **Slide (C)** - Deslizamiento evasivo
- ✅ **Block (F)** - Reducción de daño y perfect block
- ✅ **Server-Authoritative** - Validación anti-exploit
- ✅ **Network Optimized** - Rate limiting y validación
- ✅ **Performance Optimized** - 79% frame budget disponible

## 📚 Documentación

Toda la documentación está organizada en la carpeta [`docs/`](docs/):

### Guías Principales
- **[README.md](docs/README.md)** - Descripción completa del proyecto
- **[COMBAT_SYSTEM_GUIDE.md](docs/COMBAT_SYSTEM_GUIDE.md)** - Guía completa del sistema (~600 líneas)
- **[NPC_TESTING_GUIDE.md](docs/NPC_TESTING_GUIDE.md)** - Guía de testing con NPCs

### Guías Técnicas
- **[TYPE_VALIDATION_GUIDE.md](docs/TYPE_VALIDATION_GUIDE.md)** - Runtime validation con biblioteca 't'
- **[LUALS_ANNOTATIONS_GUIDE.md](docs/LUALS_ANNOTATIONS_GUIDE.md)** - Anotaciones LuaLS para IntelliSense
- **[PERFORMANCE_REPORT.md](docs/PERFORMANCE_REPORT.md)** - Análisis de performance y optimizaciones
- **[TESTS_README.md](docs/TESTS_README.md)** - Documentación de unit tests (50 tests)

## 🚀 Quick Start

1. **Clonar el repositorio:**
   ```bash
   git clone https://github.com/Alafa117/Roblox-Projects.git
   ```

2. **Instalar dependencias:**
   ```bash
   wally install
   ```

3. **Abrir en Roblox Studio:**
   - Abrir `default.project.json` con Rojo
   - Sincronizar con Roblox Studio

4. **Configurar (opcional):**
   - Ajustar valores en `src/shared/CombatCore/Config/`

## 📁 Estructura

```
src/
├── client/                    # Scripts del cliente
│   └── CombatFramework/      # Framework de combate cliente
├── server/                    # Scripts del servidor
│   ├── CombatHandler/        # Handler principal de combate
│   └── Testing/              # NPCs de testing
└── shared/                    # Módulos compartidos
    └── CombatCore/           # Sistema de combate core
        ├── Animations/       # Sistema de animaciones
        ├── Config/           # Configuración
        ├── Data/             # Types y Enums
        ├── Debugging/        # Performance profiler
        ├── Helpers/          # Helpers (Physics, Spatial, etc.)
        ├── Logging/          # Sistema de logging
        ├── Movement/         # Dash y Slide
        ├── Network/          # Client/Server networking
        └── Validation/       # Validación y type checking
```

## 🧪 Testing

El proyecto incluye **50 unit tests** ejecutables en Roblox Studio con TestEZ:

```lua
-- Script en ServerScriptService:
local TestEZ = require(game.ReplicatedStorage.Packages.TestEZ)
TestEZ.TestBootstrap:run({ game.ReplicatedStorage.tests })
```

Ver [TESTS_README.md](docs/TESTS_README.md) para más detalles.

## 📊 Performance

**Todas las mecánicas superan los objetivos de performance:**

| Mechanic | Tiempo | Target | Margen |
|----------|--------|--------|---------|
| Light Attack | 0.320ms | <0.5ms | **36% mejor** |
| Strong Attack | 0.405ms | <0.6ms | **33% mejor** |
| Dash | 0.195ms | <0.3ms | **35% mejor** |
| Slide | 0.190ms | <0.3ms | **37% mejor** |
| Block | 0.085ms | <0.1ms | **15% mejor** |

**Frame Budget:** 79% disponible - Ver [PERFORMANCE_REPORT.md](docs/PERFORMANCE_REPORT.md)

## 🎯 Estado del Proyecto

- ✅ Sistema de combate completo y funcional
- ✅ Architecture refactorizada y optimizada
- ✅ 50 unit tests implementados
- ✅ Documentación profesional completa
- ✅ Performance excepcional (5/5 ⭐)
- ✅ **Production-Ready**

## 📝 Licencia

Este proyecto es parte del portafolio de desarrollo de Roblox.

## 👤 Autor

**Alafa117** - [GitHub](https://github.com/Alafa117)

---

Para más información, consulta la [documentación completa](docs/).
