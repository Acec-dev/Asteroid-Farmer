# Asteroid Farmer - Part 1: Game Overview & Design Philosophy

> **The definitive reference guide to Asteroid Farmer.**
> This is Part 1 of 7. See the [Table of Contents](./README.md) for all parts.

---

## Premise

Asteroid Farmer is an arcade space game built in **Godot 4.5**. The player pilots a ship through an asteroid field, destroying asteroids to collect minerals, selling those minerals at dynamically fluctuating market prices, and spending credits on ship upgrades. The game layers an economic simulation on top of classic Asteroids-style action gameplay.

The core loop is:

```
MINE asteroids --> COLLECT minerals --> SELL at market --> UPGRADE ship --> repeat
```

As time passes, asteroid difficulty automatically escalates. The player must balance between staying in the field to farm minerals and returning to base to manage drones, voyages, and financial instruments.

---

## Design Philosophy

### Black & White with Limited Color

The entire visual identity is built around a **monochrome palette**. The vast majority of the game is rendered in pure black and white:

- **Background**: Solid black (`Color(0, 0, 0, 1)` as the default clear color).
- **Player ship**: White polyline triangle drawn procedurally via `_draw()`.
- **Asteroids**: White outlined irregular polygons drawn procedurally.
- **Projectiles**: White shapes (bullets, rockets, mines).
- **UI panels**: Black backgrounds with gray borders (`Color(0.6, 0.6, 0.6)`).
- **Text**: White on black, using the DM Mono font family exclusively.

**Color is used sparingly and deliberately** to draw attention to specific information:

| Color | Where It Appears | Purpose |
|-------|-----------------|---------|
| Red flash `(1.5, 0.5, 0.5)` | Player ship on damage | Immediate danger feedback |
| Red `(0.9, 0.3, 0.3)` | Cargo label when over-encumbered | Warning state |
| Yellow-gold `(0.9, 0.8, 0.3)` | Section headers in upgrade panel | Category labeling |
| Green `(0.3, 0.8, 0.3)` | "MAX" / "READY" labels, vault balance | Positive/complete state |
| Cyan `(0.2, 0.8, 1.0)` | Railgun beam and charge visual | High-tier weapon identity |
| Red beam `(1.0, 0.3, 0.3)` | Laser beam | Weapon identity |
| Blue `(0.4, 0.7, 1.0)` | Expedition UI, exotic minerals, expedition drones | Expedition system identity |
| Purple `(0.7, 0.5, 1.0)` | Drone upgrades panel title | Drone upgrade system identity |
| Mine blink (white to red) | Mine about to detonate | Urgency feedback |

### Straight Lines & Sharp Edges

Every visual element uses **sharp geometry with zero corner radius**:

- All `StyleBoxFlat` instances use `set_corner_radius_all(0)`.
- Ships and drones are drawn as angular polyline triangles.
- Asteroids are irregular polygons, not circles.
- UI panels are perfect rectangles with 1-2px borders.
- No gradients, no shadows, no rounded elements anywhere.
- Separators are 1px flat lines.

### Procedural Drawing

Nothing in the game uses sprite sheets or bitmap textures for gameplay elements. Everything is drawn in code using Godot's `_draw()` API:

- **Player ship**: Triangle polyline in `player.gd`
- **Docked ship**: Triangle polyline via inner class `_ShipDrawer` in `base.gd`
- **Drones**: Smaller triangle polylines via `_DroneDrawer` / `_ExpeditionDroneDrawer`
- **Rockets**: Polygon with tail fins in `rocket.gd`
- **Mines**: Circle with 8 spike lines in `mine.gd`
- **Railgun beam**: `Line2D` node with fade animation
- **Laser beam**: `draw_line()` with glow layers
- **Progress bars**: Custom `_draw()` override in `_VoyageProgressBar`
- **Asteroids**: Procedural polygon via `asteroid_visuals.gd`

The only bitmap images are used for the **base scene** planet graphics and the **start menu** — everything in active gameplay is vector.

### Font

The game uses **DM Mono** (Regular, Medium, and Light weights) as its sole font. This monospace typeface reinforces the terminal/HUD aesthetic. Font sizes typically range from 10-18px for UI elements. The Kenney Future font is available in assets but DM Mono is the standard.

---

## Target Platforms

Export presets are configured for:

- Windows (x86_64)
- macOS (x86_64 + ARM64)

---

## Technical Foundation

| Property | Value |
|----------|-------|
| Engine | Godot 4.5 |
| Renderer | GL Compatibility |
| Resolution | 1920 x 1080 |
| Gravity | 0 (space) |
| Language | GDScript |
| Total scripts | ~45 files |
| Total lines of code | ~6,400 |

---

## Project File Structure

```
Asteroid-Farmer/
├── Assets/              Fonts, audio, images, themes
├── Scenes/              .tscn scene files
├── Scripts/
│   ├── components/      Modular gameplay components
│   └── weapons/         Weapon system implementation
├── docs/                This documentation
├── project.godot        Main Godot configuration
└── export_presets.cfg   Build targets
```

---

## Input Controls

| Action | Key / Input | Notes |
|--------|------------|-------|
| Move | W/A/S/D | WASD movement |
| Aim | Mouse position / Right stick | Dual-stick gamepad support |
| Fire primary | Left click (held) | Auto-fires at fire rate |
| Fire laser | Right mouse button (held) | Continuous beam, requires unlock |
| Fire railgun | R key | Single shot, long cooldown |
| Toggle menus | TAB | Opens upgrade panel + graphs panel |
| Toggle inventory | TAB | Same as menu toggle |

Rockets and mines fire automatically once unlocked — no manual input required.

---

## Physics Layers

| Layer | Bit | Name | Used By |
|-------|-----|------|---------|
| 1 | 1 | World | General collision |
| 2 | 2 | Player pickup | Mineral collection area |
| 4 | 4 | Player hurt | Damage to player |
| 8 | 8 | Projectiles | Bullets, rockets, beams |
| 16 | 16 | Asteroids | Asteroid bodies |
| 32 | 32 | Minerals | Dropped mineral pickups |

---

## Node Groups

| Group | Purpose |
|-------|---------|
| `player` | Player ship node |
| `player_pickup` | Player's collection area |
| `asteroids` | All active asteroids |
| `rockets` | Active rocket projectiles |
| `falling_mineral` | Minerals still falling/moving |
| `mineral` | Collectible minerals on field |

---

*Next: [Part 2 - Architecture & Autoloads](./PART2_ARCHITECTURE.md)*
