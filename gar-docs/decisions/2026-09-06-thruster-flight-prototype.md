# Thruster flight prototype

Date: 2026-09-06. User-selected direction, pending feel validation in Studio.

## Intent

Karson wants clearer visibility and an interactive distance-based obstacle run, with creatures still awarded at the end. He is considering thrusters and future roguelike elements. This prototype addresses movement, camera and fog; obstacle rules and run upgrades are separate design work.

## Selected controls

- Mouse aims a direction; the character follows with momentum. This was explicitly selected over a spring-centered flight stick.
- Hold W to thrust; release to coast. This was explicitly selected over automatic forward thrust.
- S airbrakes, E ends the run, and F engages while airborne. Double jump remains available for getting off the starting platform.

## Prototype implementation

Replace the prone wing presentation with a compact local twin-thruster pack. Use a moderate forward body lean, bank-dependent limb offsets, and small procedural sway. Write Transform after Animator evaluation on both Motor6D and AnimationConstraint joints; do not replace or disable rig joints.

Aim, facing, velocity and camera are separate states. Mouse delta changes aim once per rendered frame without another dt multiplication. Facing follows a bounded turn rate. Thrust adds acceleration; quadratic drag reduces speed while coasting; sideslip damping turns existing momentum gradually. Residual sink is an arcade tuning parameter rather than a full aerodynamic simulation.

The follow camera sits 5 studs above and 18 behind instead of 24 above and 16 behind. Aim follows the mouse, the horizon has no roll, camera collision uses a raycast, and speed gently expands FOV. Mouse lock and the cursor are restored on stop, fuel depletion and respawn; menus temporarily release capture.

Forest atmosphere changes from Density 0.40 / Haze 2.6 to Density 0.18 / Haze 0.75. Lower fog may reveal existing corridor generation or asset-loading boundaries; no LOD claim is made.

## Scope and compatibility

- Keep `GliderConfig`, `Gliders`, Beginner/Advanced keys and the existing equip remote so gear selection and server run bookkeeping remain compatible. Display names can say thrusters; the internal protocol is not renamed.
- The June distinct-gear decision is only revised in propulsion/presentation for this prototype. Tier unlocks, slot counts and final thruster assets remain open.
- Preserve +Z corridor progress, with aim bounded to 80 degrees either side. Launch/corridor coupling and multiplayer ownership are not resolved here.
- Keep existing server fuel drain as a run budget, including while coasting. No client fuel writes or throttle-based economy change is introduced.
- Keep current server distance measurement and creature award chain. Its anti-cheat limits are unchanged.
- Thruster visuals and procedural pose are local prototype presentation, not a completed multiplayer replicated cosmetic system.

## Verify in Studio

Test mouse-right and mouse-up, thrust/coast/brake, fast alternating turns, low/high graphics settings, approaching a wall with the camera, Escape/menu return, E, fuel depletion, death/respawn and a second run. Confirm the avatar sits below the aim reference and the camera does not look steeply down at its back. Numerical/compilation checks cannot establish these outcomes.

## References

- [Cobblemon riding](https://wiki.cobblemon.com/index.php/Mounts): acceleration and turning are independent riding characteristics; inspiration rather than a claim of matching a specific mount implementation.
- [Roblox camera](https://create.roblox.com/docs/workspace/camera): Scriptable camera and per-frame Focus.
- [Mouse input](https://create.roblox.com/docs/reference/engine/classes/UserInputService): locked rendered-frame mouse delta.
- [AnimationConstraint](https://create.roblox.com/docs/reference/engine/classes/AnimationConstraint): Transform and upgraded joint compatibility.
