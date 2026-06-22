# Claude Code Project Guidelines - Roblox Crate Spinner

## Critical Workflow Rules (UI & Layout)
- **Bring Your Own UI (BYOUI):** NEVER programmatically create UI elements (e.g., do not use `Instance.new("Frame")`, `Instance.new("TextLabel")`, etc.). Assume all visual assets, viewports, and screens are entirely pre-made by the user inside Roblox Studio.
- **Hands-Off Aesthetics:** Do not inject default styling properties like fonts, text colors, background colors, UICorners, or UIStrokes unless explicitly directed. Leave all visual adjustments completely to the user's manual design.
- **Configuration-First Design:** Always place mathematical variables, offsets, scale multipliers, base speeds, and bounding dimensions inside a clearly documented `Config` table at the absolute top of every script file for easy tuning.

## Technical Architecture & Code Style
- **Language:** Roblox Luau. Write clean, modular, and optimized scripts.
- **OOP & Decoupling:** Use strict Object-Oriented Programming principles. Keep visual layout rendering states completely decoupled from data-driven reward and cash state machines.
- **Memory Safety:** Ensure all active thread handles, `RenderStepped` loops, `RemoteEvents`, and `Tweens` are explicitly disconnected or garbage collected when a spin sequence finishes to prevent memory leaks.

## Viewport & Math Guidelines
- **Auto-Framing Math:** Use `model:GetBoundingBox()` to dynamically evaluate the center and spatial bounds of any 3D asset placed inside a ViewportFrame. 
- **Model Orientation:** Ensure cameras look directly at the front of the model. Apply a 180-degree (math.pi) offset rotation vector if models default to facing away from the camera.
- **Uniform Scaling:** Use the native `Model:ScaleTo()` system to scale 3D models uniformly down to miniature proportions for stand placements without distorting nested mesh sizes.
- **Trigonometric Layouts:** Use robust math.sin and math.cos loop paths driven by frame rate delta-time to achieve smooth, infinite isometric circular/elliptical layouts.