# GAR Conventions

## Naming
- Scripts: PascalCase.lua (ModuleScripts) or descriptive.server.lua / descriptive.client.lua
- Commit scopes: flight, rot, crate, inventory, social, economy, ui, data, glider, map, monetization
- Rot internal names: match CreatureDictionary keys exactly (used across DataStore, events, tool names)
- Holdable tool naming: `{InternalName}_{RarityName}` (e.g. `TungTungSahur_Legendary`)

## File structure
```
src/
├── ReplicatedStorage/       ← shared ModuleScripts (GliderConfig, RarityDistribution, CreatureDictionary, CreatureModels)
├── ServerScriptService/     ← server Scripts + ModuleScripts (PlayerData, CrateSystem, GliderHandler, EquipmentHandler, GameManager, GameEvents)
├── StarterPlayerScripts/    ← client LocalScripts (Client.client.lua = flight controller)
├── StarterGui/              ← UI LocalScripts (InventoryUI, CrateUI, GliderTestUI)
└── Workspace/               ← in-world prefabs and scripts (CreatureSlotPrefab)
```

## Architecture decisions
- **3–4 distinct hangglider types** (not one upgradeable type) — Beginner and Advanced already in GliderConfig; Elite template commented in for future
- **Rarity-tier income baked at roll time** — rot.Income = species.IncomeRate × rarity.multiplier, stored on the rot object; no live stat lookup needed
- **DataStore V4** — rot inventory stores objects {Species, Rarity, Income}; V3 string entries auto-migrated on load
- **Distance-based rarity** — RarityDistribution.lua; MAX_DISTANCE=5000 studs; tune with map design
- **Monetization philosophy** — acceleration-not-gatekeeping; free players can progress, paid speeds it up (cooldown reduction, crate timers, cosmetic skins)

## Code style
- Server authority on all economy changes; client fires RemoteEvents, server validates + writes DataStore
- Guards first in event handlers: type check → range check → ownership check → then act
- Use `warn()` for rejected/suspicious client requests; `print()` for normal lifecycle logs
- `.server.lua` suffix for Server Scripts, `.client.lua` for LocalScripts, no suffix for ModuleScripts

## Rojo / GitHub pipeline
- Repo: github.com/karsonf1/glide-a-rot (main branch)
- Sync via Rojo; .rbxlx file tracked but diffs are binary — script changes go through .lua files
- Both PC (`C:\Users\karso\Desktop\Glide-A-Rot!`) and laptop share same repo via git pull
