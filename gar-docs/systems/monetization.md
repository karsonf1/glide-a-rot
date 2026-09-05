<!-- Synced from the Obsidian vault (02 - Glide-A-Rot) on 2026-09-05. gar-docs/ is the in-repo source of truth for engineering docs. -->

# GAR Monetization

**Status:** 🔴 no code · philosophy locked

## The philosophy — acceleration, not gatekeeping

Free players can fully progress through **every** system in [Glide-A-Rot](../_index.md) given enough time. Paid options only speed that up. This is a project-wide constraint, not just a rule for this system — it shapes crate timers, glider unlocks, and the whole economy. See [Monetization Philosophy](../decisions/2026-06-29-monetization-philosophy.md).

Some pay-to-win is intentional and fine. What's not permitted: a purchase being the *only* path to any content.

## Why this over pay-to-win

Long-term player trust and retention matter more for a solo-dev game relying on organic growth and word-of-mouth than short-term revenue extraction does. A gatekeeping model would monetize a smaller number of players harder while suppressing the population the [GAR Social Mechanic](social-mechanic.md) depends on — which, in a game where server population improves everyone's rolls, is actively self-defeating.

## Planned levers

| Lever | Type | Fits philosophy because |
|---|---|---|
| Crate cooldown reduction | Developer product | Free players get every crate, just slower |
| Fuel / timer skips | Developer product | Consumable convenience, not access |
| Glider type unlocks | Game pass | Gliders also earnable; purchase is a shortcut |
| Cosmetic skins | Game pass | Monetizes expression, not power |

Crate cooldown is the primary lever — see [GAR Crate System](crate-system.md).

## Implementation requirements when this lands

`MarketplaceService:PromptProductPurchase()` for consumables, `PromptGamePassPurchase()` for permanent unlocks. **All grants server-side through `ProcessReceipt`.**

The dangerous part is `ProcessReceipt` (SE-3 in [GAR Roblox Playbook](../roblox-playbook.md)):

- Grant the item **first**, then return `Enum.ProductPurchaseDecision.PurchaseGranted`.
- If the grant fails for any reason, return `NotProcessedYet` so Roblox retries.
- Make every grant **idempotent** — Roblox will re-deliver receipts, and a non-idempotent grant means duplicate items or lost purchases.

This is also the point at which the raw-DataStore exposure (SE-1) stops being a theoretical risk and starts being a refund liability. **Migrate to ProfileService before monetization ships, not after.**

## Sequencing

Week 3 of the MVP sprint, after rot/rarity integration. Deliberately sequenced late: monetize a game that already works rather than building monetization into an unproven loop.

## Related

[GAR Sprint Plan](../sprint-plan.md) · [GAR Glider Types](glider-types.md) · [GAR Open Questions](../open-questions.md)
