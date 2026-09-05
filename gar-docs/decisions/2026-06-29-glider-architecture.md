<!-- Synced from the Obsidian vault (02 - Glide-A-Rot) on 2026-09-05. gar-docs/ is the in-repo source of truth for engineering docs. -->

# Glider Architecture Decision

**Decided:** 2026-06-29 (logged retroactively)

## Question

Should [Glide-A-Rot](../_index.md) have 3–4 distinct hangglider types, or a single glider that upgrades linearly?

## Decision

**3–4 distinct types.** Beginner and Advanced are live in `GliderConfig`; Elite exists as a commented template.

## Why

Three arguments, in order of weight:

**Progression depth.** Each unlock feels categorically different rather than a stat bump. Advanced isn't just "Beginner +10 speed" — it has a shallower glide angle (better fuel efficiency per stud), a faster turn rate, and a *lower* turn decay that makes it carve longer and demand more anticipation. That's a different aircraft, not a better one.

**Monetization surface.** Distinct types mean you can sell a specific glider, or a skin pack per type, instead of one linear upgrade path where every purchase is interchangeable with the next. See [GAR Monetization](../systems/monetization.md).

**Social legibility.** [GAR Social Mechanic](../systems/social-mechanic.md) depends on players recognizing what others are flying at a glance. Silhouette differences between distinct gliders carry that signal; a single reskinned glider wouldn't.

## Trade-off accepted

A single upgradeable glider would have been faster to build and easier to balance. Judged not worth the progression and monetization depth lost.

## Consequences

- `GliderConfig` is the single stat registry — no flight values live anywhere else.
- Adding a tier is three steps: copy an entry, add the key to `CreatureDictionary`, place the model in `ReplicatedStorage/GliderModels`.
- Opened a follow-on question that is still unresolved: do slot counts vary by tier? See [GAR Open Questions](../open-questions.md) #2.

## Affects

[GAR Glider Types](../systems/glider-types.md) · [GAR Flight Mechanics](../systems/flight-mechanics.md) · [GAR Inventory and Equipment](../systems/inventory-and-equipment.md)
