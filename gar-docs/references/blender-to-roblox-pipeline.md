<!-- Synced from the Obsidian vault (02 - Glide-A-Rot) on 2026-09-05. gar-docs/ is the in-repo source of truth for engineering docs. -->

# Blender to Roblox Pipeline

Getting a model out of Blender and into Roblox Studio for [Glide-A-Rot](../_index.md), with the constraints that actually bite. For general Blender technique see Blender Workflow Reference.

---

## What to model in Blender vs. build in Studio

| Blender | Studio parts |
|---|---|
| Organic shapes — gnarled trees, mossy arches, irregular boulders, twisted roots | Flat platforms, walls, floor planes |
| Hero props the player looks at closely | Anything boxy |
| **The hangglider** — the one asset that defines the game's look | Ring geometry (a cylinder is fine) |

**Never model a whole segment in Blender.** Iteration is far too slow. Hero props only.

---

## Poly budget

Under **5,000 triangles** per prop. Roblox is a mobile-first platform and a streamed corridor holds several sections of geometry live at once — see [GAR ProcGen Corridor](../systems/proc-gen.md). Every prop is cloned per section, so a heavy mesh multiplies.

---

## Export from Blender

1. **Apply all transforms** — `Ctrl+A` → All Transforms. Skipping this is the number-one cause of imports that behave strangely under scaling and rotation.
2. **Set the origin at the base** of the model, not its center. Makes positioning in Studio predictable — you place a tree by its trunk, not its middle.
3. `File → Export → FBX (.fbx)`
   - Scale: `1.00`
   - Apply Transform: ✅
   - Include: Mesh only (no armatures for static props)

---

## Import into Studio

1. `Home → Import 3D`, or Asset Manager → right-click → Import 3D
2. Studio brings it in as a `MeshPart` in Workspace
3. Drag it into the target folder (e.g. a segment's `Geometry/`)
4. `Anchored = true`
5. **Rescale.** FBX imports routinely land at the wrong size — Roblox reads FBX in cm. A large tree should sit around 20–40 studs tall
6. Sanity-check by placing a standard Roblox character (~5 studs) beside it

**Mesh health tint:** green in Studio means the mesh imported cleanly, red means a problem. Check before building on top of it.

---

## Known open issues on the hangglider

Two unresolved problems on the Blender hangglider import, both blocking [GAR Glider Types](../systems/glider-types.md) from being testable:

- **UV stretching on the left wing.** Almost always an unapplied scale transform or a bad seam. Re-check `Ctrl+A → All Transforms` first, then look at the UV layout directly.
- **Alpha = 0 on the wing material.** The wing renders invisible. Usually a material transparency setting surviving the FBX round-trip, or a Roblox `SurfaceAppearance` picking up an alpha channel it shouldn't.

Neither is exotic. Both are worth a focused hour with the Blender MCP's `get_screenshot_of_area_as_image` on the UV editor — visual diagnosis beats guessing.

`ReplicatedStorage/GliderModels` still needs `GliderBeginner` and `GliderAdvanced` placed. **No models means no playtest**, which makes this a higher-priority blocker than it currently reads on the board.

---

## Related

[GAR Glider Types](../systems/glider-types.md) · [Forest Segment Authoring Guide](forest-segment-authoring.md) · [Art Sourcing Strategy](../decisions/2026-06-29-art-sourcing-strategy.md) · Room Model Blender Workflow
