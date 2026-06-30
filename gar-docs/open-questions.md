# Open Questions
_Move items to decisions/ once resolved, with a dated decision file._

- [ ] **Social mechanic design** — cooperative vs. competitive? per-session vs. persistent? (Claude rec: cooperative + per-session — simplest to implement, lowest grief risk, easier to balance for MVP)
- [ ] **Rot slots per glider** — fixed number or variable by glider tier? (e.g. Beginner=3 slots, Advanced=6 slots). Directly affects GliderConfig schema and inventory hotbar logic.
- [ ] **Glider 3D model** — is the Blender hangglider import fully resolved? (UV stretching on left wing, Alpha=0 material issue on wing material)
- [ ] **Passive income ticker** — how often does it tick? per-second in-game, or time-based even while offline? Income value is already baked on each rot (`rot.Income`), so the ticker just needs a formula and a last-seen timestamp in DataStore.
- [ ] **Inventory cap** — 81 slots currently hardcoded in PlayerData.lua; is this the right number?
- [ ] **Rot rarity → flight speed?** — currently rarity only affects income, not flight speed. Should equipped rot rarity also multiply glider speed? Would reinforce the collection loop; needs balance thought before committing.
- [ ] **Creature stats: per-instance variance?** — currently all rots of the same species+rarity have identical Income (baked deterministically). Should there be any per-roll variance on top of rarity tier? (Claude rec: no, keep it deterministic — simpler DataStore, no confusion from two "Legendary TungTungSahur" having different stats)
