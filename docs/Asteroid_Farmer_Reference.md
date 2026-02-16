# Asteroid Farmer — Complete Reference Bible

> The definitive, centralized reference for the entire Asteroid Farmer project.
> Premise, design philosophy, architecture, every system, every script, every function — all in one document.

---

# Table of Contents

1. [Game Overview & Design Philosophy](#1-game-overview--design-philosophy)
2. [Architecture & Autoloads](#2-architecture--autoloads)
3. [Weapons System](#3-weapons-system)
4. [Economy & Market System](#4-economy--market-system)
5. [Upgrade System](#5-upgrade-system)
6. [Entities & World Systems](#6-entities--world-systems)
7. [Script-by-Script Reference](#7-script-by-script-reference)

---

# 1. Game Overview & Design Philosophy

## Premise

Asteroid Farmer is an arcade space game built in **Godot 4.5**. The player pilots a ship through an asteroid field, destroying asteroids to collect minerals, selling those minerals at dynamically fluctuating market prices, and spending credits on ship upgrades. The game layers an economic simulation on top of classic Asteroids-style action gameplay.

The core loop:

```
MINE asteroids → COLLECT minerals → SELL at market → UPGRADE ship → repeat
```

As time passes, asteroid difficulty automatically escalates. The player must balance between staying in the field to farm minerals and returning to base to manage drones, voyages, and financial instruments.

## Quick Facts

| Property | Value |
|----------|-------|
| Engine | Godot 4.5 (GL Compatibility) |
| Language | GDScript |
| Resolution | 1920 × 1080 |
| Gravity | 0 (space) |
| Scripts | ~45 files, ~6,400 lines |
| Scenes | 26 .tscn files |
| Autoloads | 6 singletons |
| Weapons | 5 |
| Mineral Types | 4 standard + 4 exotic |
| Difficulty Levels | 5 (Easy through Extreme) |

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
- UI panels are perfect rectangles with 1–2px borders.
- No gradients, no shadows, no rounded elements anywhere.
- Separators are 1px flat lines.

### Procedural Drawing

Nothing in the game uses sprite sheets or bitmap textures for gameplay elements. Everything is drawn in code using Godot's `_draw()` API:

| Element | How Drawn |
|---------|-----------|
| Player ship | Triangle polyline in `player.gd` |
| Docked ship | Triangle polyline via inner class `_ShipDrawer` in `base.gd` |
| Drones | Smaller triangle polylines via `_DroneDrawer` / `_ExpeditionDroneDrawer` |
| Rockets | Polygon with tail fins in `rocket.gd` |
| Mines | Circle with 8 spike lines in `mine.gd` |
| Railgun beam | `Line2D` node with fade animation |
| Laser beam | `draw_line()` with glow layers |
| Progress bars | Custom `_draw()` override in `_VoyageProgressBar` |
| Asteroids | Procedural polygon via `asteroid_visuals.gd` |

The only bitmap images are used for the **base scene** planet graphics and the **start menu** — everything in active gameplay is vector.

### Font

The game uses **DM Mono** (Regular, Medium, and Light weights) as its sole font. This monospace typeface reinforces the terminal/HUD aesthetic. Font sizes typically range from 10–18px for UI elements.

## Project File Structure

```
Asteroid-Farmer/
├── Assets/              Fonts, audio, images, themes
├── Scenes/              .tscn scene files
├── Scripts/
│   ├── components/      Modular gameplay components
│   └── weapons/         Weapon system implementation
├── docs/                Documentation
├── project.godot        Main Godot configuration
└── export_presets.cfg   Build targets
```

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

## Physics Layers

| Layer | Bit | Name | Used By |
|-------|-----|------|---------|
| 1 | 1 | World | General collision |
| 2 | 2 | Player pickup | Mineral collection area |
| 4 | 4 | Player hurt | Damage to player |
| 8 | 8 | Projectiles | Bullets, rockets, beams |
| 16 | 16 | Asteroids | Asteroid bodies |
| 32 | 32 | Minerals | Dropped mineral pickups |

## Node Groups

| Group | Purpose |
|-------|---------|
| `player` | Player ship node |
| `player_pickup` | Player's collection area |
| `asteroids` | All active asteroids |
| `rockets` | Active rocket projectiles |
| `falling_mineral` | Minerals still falling/moving |
| `mineral` | Collectible minerals on field |

## Target Platforms

Windows (x86_64), macOS (x86_64 + ARM64), Linux (x86_64), Web (HTML5), Mobile (Android, iOS).

---

# 2. Architecture & Autoloads

## Architectural Pattern

Asteroid Farmer uses a **singleton + component** architecture:

- **Singletons (Autoloads)** hold global state and provide services accessible from any script.
- **Components** are modular nodes attached to entities (e.g., `ShieldComponent` on the player, `AsteroidSpawner` on the main scene).
- **Weapons** follow a class hierarchy: `WeaponBase` (abstract) → specific weapons, managed by `WeaponManager`.

Communication between systems is primarily through **signals**. GameState is the central signal hub — most UI and gameplay systems connect to its signals rather than polling.

## Scene Flow

```
start_menu.tscn  →  main.tscn  ↔  base.tscn
                         |               |
                         ↓               ↓
                    GameOver.tscn    bank.tscn
```

- **start_menu.tscn**: Entry point. Simple start button.
- **main.tscn**: Core gameplay. Player, asteroids, UI panels. This is where mining happens.
- **base.tscn**: Space station. Drone management, voyages, expeditions, drone upgrades.
- **bank.tscn**: Banking interface. Vault deposits, bonds, fuel futures.
- **GameOver.tscn**: Shown when shields reach 0.

Transition between main and base uses a 5-second countdown ("Traveling to base...").

---

## Autoload Singletons

### 2.1 GameState (`Scripts/game_state.gd`)

**The central state manager.** Every piece of persistent game data lives here.

**Responsibilities:** Stores player credits, minerals, exotic minerals. Holds the entire upgrade registry (weapons, shield, radar, cargo, tractor beam, spawner). Manages bank balance, bonds, fuel futures. Tracks drone counts (voyage + expedition). Manages cargo capacity and encumbrance. Emits signals when any state changes.

**Key Signals:**

| Signal | Payload | Fired When |
|--------|---------|------------|
| `credits_changed` | `new_credits: int` | Credits are added or spent |
| `inventory_changed` | (none) | Mineral counts change |
| `new_pickup` | (none) | Player picks up a mineral |
| `shield_changed` | `current: float, maximum: float` | Shield takes damage or regenerates |
| `prices_changed` | (none) | Market prices update |
| `upgrades_changed` | (none) | Any upgrade is purchased |
| `cargo_full` | (none) | Total minerals reach cargo capacity |
| `over_encumbered` | `is_encumbered: bool` | Player crosses the encumbrance threshold |
| `voyage_drones_changed` | `new_count: int` | Voyage drone count changes |
| `expedition_drones_changed` | `new_count: int` | Expedition drone count changes |
| `voyage_started` | (none) | A voyage begins |
| `voyage_completed` | `results: Dictionary` | A voyage finishes |
| `voyage_progress_updated` | `progress: float` | Voyage progress tick (0.0–1.0) |
| `expedition_started` | (none) | An expedition begins |
| `expedition_completed` | `results: Dictionary` | An expedition finishes |
| `expedition_progress_updated` | `progress: float` | Expedition progress tick |
| `exotic_minerals_changed` | (none) | Exotic mineral counts change |
| `drone_upgrades_changed` | (none) | A drone upgrade is purchased |
| `bank_balance_changed` | `new_balance: int` | Vault balance changes |
| `bank_bond_changed` | (none) | Bond bought or matured |
| `bank_upgraded` | (none) | Bank upgrade purchased |
| `fuel_futures_changed` | (none) | Futures contract bought or settled |

**Key Functions:**

| Function | Purpose |
|----------|---------|
| `add_credits(amount)` | Add or subtract credits (clamped to 0) |
| `add_mineral(kind, amount)` | Add minerals, emit signals, check cargo |
| `sell_all()` | Sell all minerals at current market prices |
| `get_total_minerals()` | Sum of all mineral counts |
| `is_over_encumbered()` | True if total minerals > cargo capacity |
| `get_speed_multiplier()` | Returns 1.0 if under capacity, scales down to 0.25 if over |
| `unlock_weapon(name)` | Unlock a weapon in the registry |
| `upgrade_weapon(name)` | Increment a weapon's level |
| `upgrade_system(system, upgrade)` | Upgrade a non-weapon system |
| `get_upgrade_value(system, upgrade)` | Read current value from upgrade registry |
| `is_weapon_unlocked(name)` | Check weapon lock state |
| `set_spawner_difficulty(level)` | Set asteroid difficulty (0–4) |
| `get_rocket_damage/speed/cooldown()` | Formula-based rocket stats |
| `get_mine_cooldown/blast_radius()` | Formula-based mine stats |
| `get_tractor_beam_range/strength()` | Formula-based tractor stats |
| `buy_voyage_drone()` | Purchase a voyage drone for 75 credits |
| `buy_expedition_drone()` | Purchase an expedition drone for 75 credits |
| `add_exotic_mineral(kind, amount)` | Add exotic minerals |
| `buy_drone_upgrade(name)` | Purchase drone upgrade with exotic minerals |
| `bank_deposit(amount)` | Deposit credits into vault |
| `bank_withdraw(amount)` | Withdraw credits from vault |
| `buy_bond(tier_key)` | Purchase a bond ("short", "medium", "long") |
| `buy_fuel_future(tier_key, is_long)` | Purchase a fuel futures contract |

**The `_process(delta)` Loop:** Every frame, GameState ticks three financial systems: `_bank_tick(delta)` accumulates interest on vault balance, `_bond_tick(delta)` matures bonds when their duration expires, and `_fuel_futures_tick(delta)` settles fuel futures when expired.

---

### 2.2 Market (`Scripts/Market.gd`)

**The economy engine.** Manages dynamic pricing for all minerals and fuel.

**Responsibilities:** Updates prices every 3 seconds via internal Timer. Tracks price history (last 10 data points per mineral). Each mineral uses a different pricing model. Emits `prices_changed` signal on each update.

| Function | Purpose |
|----------|---------|
| `get_price(mineral)` | Current price for a mineral type |
| `get_price_history(mineral)` | Array of last 10 prices |
| `get_fuel_price()` | Current fuel price |
| `get_fuel_price_history()` | Array of last 10 fuel prices |
| `record_nickel_sale(amount)` | Record bulk sale for supply/demand model |
| `reset_market()` | Reset all prices to defaults |

Pricing models are detailed in [Section 4](#4-economy--market-system).

---

### 2.3 ScreenUtils (`Scripts/screen_utils.gd`)

**Viewport and boundary utilities.** Used by weapons to avoid damaging off-screen targets and by the menu system to manage camera limits.

| Function | Purpose |
|----------|---------|
| `is_position_on_screen(node, pos)` | Static. Check if world position is visible |
| `is_node_on_screen(node)` | Static. Check if a Node2D is on screen |
| `get_screen_bounds_world(node)` | Static. Get screen Rect2 in world coords |
| `set_main_camera(camera)` | Store camera reference and original limits |
| `adjust_boundaries(top, bottom, left, right, duration)` | Tween camera limits for UI panels |
| `restore_boundaries(duration)` | Tween limits back to original values |

All weapon scripts call `ScreenUtils.is_node_on_screen()` before applying damage. This prevents the player from destroying asteroids they can't see.

---

### 2.4 VoyageManager (`Scripts/voyage_manager.gd`)

**Manages automated drone voyages** that gather standard minerals.

| Function | Purpose |
|----------|---------|
| `start_voyage(tier)` | Begin a voyage with all available voyage drones |
| `get_progress()` | Current progress (0.0 to 1.0) |
| `get_tier_data(tier)` | Get duration, risk, and reward for a tier |

**Voyage Tiers:**

| Tier | Duration | Break Chance | Minerals/Drone |
|------|----------|-------------|----------------|
| SHORT | 30s | 5% | 1–2 |
| MEDIUM | 45s | 20% | 2–4 |
| LONG | 60s | 35% | 4–8 |

---

### 2.5 ExpeditionManager (`Scripts/expedition_manager.gd`)

**Manages automated drone expeditions** that gather exotic minerals.

| Function | Purpose |
|----------|---------|
| `start_expedition(tier)` | Begin expedition with all expedition drones |
| `get_progress()` | Current progress (0.0 to 1.0) |
| `get_tier_data(tier)` | Get duration, risk, and reward for a tier |

**Expedition Tiers:**

| Tier | Duration | Break Chance | Exotic Minerals/Drone |
|------|----------|-------------|----------------------|
| NEAR_ORBIT | 60s | 10% | 1–2 |
| DEEP_SPACE | 120s | 25% | 2–4 |
| UNCHARTED | 180s | 40% | 4–8 |

---

### 2.6 AudioManager (`Scripts/audio_manager.gd`)

**Centralized audio playback.** Pools SFX players and provides a registry-based API.

| Function | Purpose |
|----------|---------|
| `play_sfx(key, volume_db, pitch)` | Play a sound effect (overlapping) |
| `play_sfx_queued(key, volume_db, pitch)` | Play sequentially (no overlap) |
| `play_music(key, volume_db)` | Play a music track |
| `stop_music()` | Stop current music |

**Sound Registry:**

| Key | File | Default Volume | Used For |
|-----|------|---------------|----------|
| `gun_1` | gun-1.wav | -14 dB | Primary cannon firing |
| `explode_rocket` | explode-7.wav | -10 dB | Rocket explosion |
| `explode_big` | explode-5.wav | -10 dB | Large asteroid break |
| `explode_small` | explode-2.wav | -10 dB | Small asteroid break |
| `hit_asteroid` | hit-7.wav | -10 dB | Asteroid takes hit but doesn't break |
| `collect` | collect-5.wav | -12 dB | Mineral pickup |

The SFX pool has **8 simultaneous voices**. It uses round-robin allocation — oldest sound gets replaced if all voices are in use.

---

## Signal Flow Diagram

```
Market.prices_changed
    └──> GameState._on_market_prices_changed
              └──> GameState.prices_changed
                        ├──> upgrade_panel._refresh_prices
                        └──> MineralPriceGraph (UI update)

Player picks up mineral
    └──> GameState.add_mineral()
              ├──> GameState.new_pickup
              │         └──> main._spawn_text (floating "+1 Iron")
              ├──> GameState.inventory_changed
              │         └──> upgrade_panel._refresh_inventory
              └──> GameState.cargo_full (if at capacity)
                        └──> main._on_cargo_full

Player buys upgrade
    └──> GameState.upgrade_system() / unlock_weapon()
              └──> GameState.upgrades_changed
                        ├──> WeaponManager.sync_upgrades()
                        ├──> ShieldComponent._on_upgrades_changed()
                        ├──> RadarComponent._on_upgrades_changed()
                        ├──> AsteroidSpawner._on_difficulty_changed()
                        └──> upgrade_panel._refresh_upgrade_list()
```

---

# 3. Weapons System

## Architecture

The weapon system uses a **class hierarchy with a centralized manager**:

```
WeaponBase (abstract base class)
    ├── PrimaryCannon
    ├── LaserBeam
    ├── Railgun
    ├── RocketLauncher
    └── MineLayer

WeaponManager (orchestrator)
    └── owns and updates all WeaponBase instances
```

All weapon scripts live in `Scripts/weapons/`.

---

## 3.1 WeaponBase (`Scripts/weapons/weapon_base.gd`)

**Class name:** `WeaponBase` — **Extends:** `Node2D`

The abstract base class every weapon inherits from.

**Properties:**

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `weapon_name` | String | "Unnamed Weapon" | Display name |
| `base_damage` | float | 1.0 | Starting damage value |
| `base_cooldown` | float | 1.0 | Starting cooldown in seconds |
| `energy_cost` | float | 0.0 | Reserved for future energy system |
| `enabled` | bool | false | Whether weapon can fire |
| `current_damage` | float | 1.0 | Damage after upgrades |
| `current_cooldown` | float | 1.0 | Cooldown after upgrades |
| `upgrade_level` | int | 0 | Current upgrade level |

**Lifecycle:**

1. `initialize(owner)` — Called by WeaponManager when weapon is added. Sets owner reference, calls `_ready_weapon()`.
2. `update_weapon(delta)` — Called every frame by WeaponManager. Ticks cooldown, fires if active and ready.
3. `activate()` / `deactivate()` — Called on input press/release.
4. `apply_upgrade(level, stats)` — Called when GameState upgrades change.

**Virtual Methods (Override in Subclasses):**

| Method | Purpose |
|--------|---------|
| `_ready_weapon()` | Weapon-specific initialization |
| `_execute_fire()` | **Core firing logic** — must be implemented |
| `_can_fire_custom()` | Additional firing conditions (default: true) |
| `_on_activated()` | Custom activation behavior |
| `_on_deactivated()` | Custom deactivation behavior |
| `_apply_custom_upgrade(stats)` | Handle weapon-specific upgrade data |

**Signals:** `weapon_fired` (after `_execute_fire()` completes), `stats_updated` (after `apply_upgrade()` is called).

---

## 3.2 WeaponManager (`Scripts/weapons/weapon_manager.gd`)

**Class name:** `WeaponManager` — **Extends:** `Node`

Orchestrates all weapons attached to the player.

| Function | Purpose |
|----------|---------|
| `add_weapon(weapon, slot_type)` | Register a weapon ("primary" or "secondary") |
| `remove_weapon(weapon)` | Unregister and free a weapon |
| `get_weapon(name)` | Find weapon by name string |
| `activate_weapon(name)` | Trigger a weapon's activate() |
| `deactivate_weapon(name)` | Trigger a weapon's deactivate() |
| `bind_input(action, weapon_name)` | Map an input action to a weapon |
| `sync_upgrades()` | Pull latest stats from GameState for all weapons |
| `set_weapons_enabled(enabled)` | Enable/disable all weapons (respects unlock state) |

**How Upgrades Flow:**

```
GameState.upgrades_changed signal
    └──> WeaponManager._on_upgrades_changed()
              └──> sync_upgrades()
                        └──> For each weapon in GameState.upgrades.weapons:
                                  └──> weapon.apply_upgrade(level, stats)
```

The `_get_weapon_stats()` function translates between GameState's data format and each weapon's stats Dictionary. It handles generic `*_values` arrays, Rocket Launcher formula-based stats (`GameState.get_rocket_*()`), and Mine Layer formula-based stats (`GameState.get_mine_*()`).

---

## 3.3 Primary Cannon (`Scripts/weapons/primary_cannon.gd`)

**Class name:** `PrimaryCannon` — **Extends:** `WeaponBase` — **Always unlocked.**

Uses **dual hitscan raycasts**. On each fire: two parallel rays are cast from the player's position in the aim direction (2000 units). If a ray hits an asteroid on screen, `hit_by_projectile()` is called on it. A visual-only projectile scene is spawned for feedback. The `gun_1` sound effect plays.

The cannon fires **continuously while the fire button is held** — auto-fires at the cooldown rate.

**Stats by Level:**

| Level | Damage | Cooldown | Shots/Second |
|-------|--------|----------|-------------|
| 1 | 1.0 | 0.50s | 2.0 |
| 2 | 1.0 | 0.35s | 2.86 |
| 3 | 2.0 | 0.35s | 2.86 |
| 4 | 2.0 | 0.20s | 5.0 |

---

## 3.4 Laser Beam (`Scripts/weapons/laser_beam.gd`)

**Class name:** `LaserBeam` — **Extends:** `WeaponBase` — **Requires unlock** (right mouse button).

A **continuous damage weapon with ramping damage**. While held, a raycast fires forward every frame. If it hits an asteroid, a damage timer ticks at 0.1s intervals. Damage starts at `base_beam_damage` (2.0) and ramps up to `max_beam_damage` over `ramp_time` (3.0 seconds). Switching targets resets the ramp. The beam is drawn every frame using `_draw()` with glow layers.

**Visual Details:** Main beam is red `(1.0, 0.3, 0.3)` with increasing alpha and width as damage ramps. Outer glow is same color at 30% alpha, 4px wider. Impact circle drawn at hit point, grows with ramp progress.

**Stats by Level:**

| Level | Max Damage/Tick |
|-------|----------------|
| 1 | 50.0 |
| 2 | 75.0 |
| 3 | 100.0 |
| 4 | 150.0 |

**Key Functions:**

| Function | Purpose |
|----------|---------|
| `get_ramp_percentage()` | Returns 0.0–1.0, how far into the damage ramp |
| `_apply_damage(target)` | Calculates ramped damage, applies as integer hits |
| `_reset_target()` | Clears target tracking, resets ramp timer |

The Laser overrides `update_weapon()` to skip standard cooldown-based firing. It has no cooldown — it fires continuously while active.

---

## 3.5 Railgun (`Scripts/weapons/railgun.gd`)

**Class name:** `Railgun` — **Extends:** `WeaponBase` — **Requires unlock** (R key).

Fires a **single high-damage piercing shot**. On fire, a ray is cast forward. The ray hits the first asteroid, records the hit, then **excludes it and recasts**. This repeats until no more targets, damage falls below minimum, or max pierce count (20) is reached. All hit asteroids take damage simultaneously. A `Line2D` beam visual appears (white flash → cyan fade).

**Piercing Mechanics:**

```
Hit 1: full damage
Hit 2: damage × (1 - falloff)
Hit 3: damage × (1 - falloff)²
...continues until damage < 0.5 or max_pierce_count reached
```

**Stats by Level:**

| Level | Damage | Cooldown | Pierce Falloff |
|-------|--------|----------|---------------|
| 1 | 3.0 | 5.0s | 20% per pierce |
| 2 | 4.0 | 4.5s | 15% per pierce |
| 3 | 5.0 | 4.0s | 10% per pierce |
| 4 | 7.0 | 3.5s | 5% per pierce |

**Charge Visual:** While on cooldown, a charge buildup line appears at the ship's barrel — grows in length and brightness as cooldown progresses, pulses when fully charged (sine wave alpha), disappears on fire.

**Key Functions:**

| Function | Purpose |
|----------|---------|
| `_fire_piercing_shot(pos, dir)` | Core piercing raycast loop |
| `_apply_railgun_damage(obj, dmg)` | Tries `hit_by_railgun()` then `hit_by_projectile()` |
| `_show_beam_effect(start, end, hits)` | Draws the Line2D beam visual |
| `_update_charge_visual(progress)` | Updates charge buildup Line2D |
| `get_cooldown_progress()` | Returns 0.0–1.0 for UI/visuals |
| `get_status_text()` | "RAILGUN: READY" or "RAILGUN: 67%" |

---

## 3.6 Rocket Launcher (`Scripts/weapons/rocket_launcher.gd`)

**Class name:** `RocketLauncher` — **Extends:** `WeaponBase` — **Requires unlock** (auto-fires).

**Auto-fires** at its cooldown rate. Each fire instantiates `rocket.tscn` at the player's position with current damage and speed values.

**Rocket Behavior (`Scripts/rocket.gd`):**

- **Homing**: Queries a 500-unit radius for the nearest on-screen asteroid
- **Turning**: Rotates toward target at 3 radians/second
- **Speed**: 400 units/second (base), upgradeable
- **Lifetime**: 3 seconds, then self-destructs
- **On hit**: Deals direct damage, then splash damage in an 80-unit explosion radius
- **Visual**: White polygon triangle with tail fins, drawn via `_draw()`

**Upgrade System (Infinite, Escalating):**

| Stat | Formula | Base | Per Level |
|------|---------|------|-----------|
| Damage | `1.0 + level` | 1.0 | +1.0 |
| Speed | `400 * (1 + 0.2 * level)` | 400 | +20% |
| Cooldown | `2.0 / (1 + 0.25 * level)` | 2.0s | Decreasing |

**Cost formula:** `ceil(100 * 1.5^level)` — starts at 100, grows 50% each level.

---

## 3.7 Mine Layer (`Scripts/weapons/mine_layer.gd`)

**Class name:** `MineLayer` — **Extends:** `WeaponBase` — **Requires unlock** (auto-deploys).

**Auto-deploys mines** at the player's position at its cooldown rate.

**Mine Behavior (`Scripts/mine.gd`):**

- **Timer**: Explodes after 3 seconds (fixed)
- **Blink**: In the last 1 second, blinks white-to-red with increasing frequency
- **Explosion**: Queries a 350-unit radius (base, upgradeable) for all bodies with `hit_by_projectile()`
- **Visual**: White circle with 8 spike lines, drawn via `_draw()`
- **Particle effect**: Spawns `rocket_explode_particle.tscn` on detonation

**Upgrade System (Infinite, Escalating):**

| Stat | Formula | Base | Per Level |
|------|---------|------|-----------|
| Place Cooldown | `3.0 / (1 + 0.25 * level)` | 3.0s | Decreasing |
| Blast Radius | `350 * (1 + 0.15 * level)` | 350 | +15% |

**Cost formula:** `ceil(100 * 1.5^level)` — same as rockets.

---

## Weapon Unlock Costs

| Weapon | Unlock Cost | Upgrade Costs (Lv2 / Lv3 / Lv4) |
|--------|------------|----------------------------------|
| Primary Cannon | Free (always unlocked) | 50 / 150 / 400 |
| Laser Beam | 100 | 200 / 400 / 800 |
| Rocket Launcher | 100 | (infinite sub-upgrades) |
| Mine Layer | 100 | (infinite sub-upgrades) |
| Railgun | 150 | 300 / 600 / 1200 |

---

## Damage Pipeline

When a weapon hits an asteroid, the call chain is:

```
Weapon fires
    └──> asteroid.hit_by_projectile(shooter)
              ├──> hit_points -= 1
              ├──> if hit_points > 0:
              │         AudioManager.play_sfx("hit_asteroid")
              │         apply knockback impulse
              └──> if hit_points <= 0:
                        _is_breaking = true
                        call_deferred("_break_safe")
                              ├──> AudioManager.play_sfx("explode_big" or "explode_small")
                              ├──> _spawn_particles()
                              ├──> Drop minerals (1–3 per asteroid)
                              ├──> If big enough: split into 2 smaller asteroids
                              └──> queue_free()
```

The Railgun has a special path that tries `hit_by_railgun()` first, falling back to `hit_by_projectile()`. The Laser converts float damage to integer hits.

---

# 4. Economy & Market System

## Overview

The economy is built on four pillars: **Mineral Market** (dynamic pricing with 4 distinct models), **Banking** (vault storage with compound interest), **Bonds** (fixed-term investments with guaranteed returns), and **Fuel Futures** (speculative contracts on fuel price movement).

All pricing logic lives in `Scripts/Market.gd`. All financial state lives in `Scripts/game_state.gd`.

---

## 4.1 Mineral Types

### Standard Minerals (from asteroids and voyages)

| Mineral | Enum | Base Price | Pricing Model | Price Range |
|---------|------|-----------|---------------|-------------|
| Iron | `MineralType.IRON` | 1 | Random Walk | 1–7 |
| Nickel | `MineralType.NICKEL` | 2 | Supply/Demand | 1–7 |
| Silica | `MineralType.SILICA` | 3 | Sine Wave | 1–7 |
| Platinum | `MineralType.PLATINUM` | 5 | Boom & Bust | 2–10 |

### Exotic Minerals (from expeditions only)

| Mineral | Enum | Used For |
|---------|------|----------|
| Cobalt | `ExoticMineralType.COBALT` | Drone Armor upgrades |
| Titanium | `ExoticMineralType.TITANIUM` | Mineral Scanner upgrades |
| Xenocryst | `ExoticMineralType.XENOCRYST` | Warp Drive upgrades |
| Iridium | `ExoticMineralType.IRIDIUM` | Deep Probes upgrades |

Exotic minerals are **not sold for credits**. They are exclusively spent on drone upgrades.

---

## 4.2 Pricing Models

Prices update every **3 seconds** (configurable via `Market.update_interval`). After each update, the new price is appended to history (max 10 entries) and `prices_changed` is emitted.

### Iron — Random Walk

The simplest model. Each tick, the price moves -1, 0, or +1 randomly.

```gdscript
var change := randi() % 3 - 1  # -1, 0, or +1
market_prices[IRON] = clampi(price + change, 1, 7)
```

**Behavior**: Unpredictable, no trend. Iron is the baseline commodity. The player cannot influence iron prices.

### Nickel — Supply & Demand with Appreciation

A reactive model that punishes bulk selling and rewards patience.

**Mechanics:** `_nickel_recent_sales` tracks recent sale volume, decays at 0.15 per tick. `_nickel_appreciation` accumulates at 0.2 per tick when sales < 1.0, max 3.0. Selling resets appreciation to 0.

**Formula:**

```
base_price = 4
appreciation_bonus = floor(_nickel_appreciation)
sales_impact = floor(_nickel_recent_sales * 0.05 * base_price)
price = clamp(base_price + appreciation_bonus - sales_impact, 1, 7)
```

**Strategy**: Hold nickel and wait for appreciation to build. Selling dumps the price and resets the bonus. Sell in small batches if possible.

### Silica — Sine Wave

A completely predictable cyclical pattern.

```gdscript
_market_cycle += 1
var wave := sin(_market_cycle * 0.5) * 3
price = clampi(4 + int(wave), 1, 7)
```

**Behavior**: Price oscillates between 1 and 7 in a regular sine pattern. One full cycle takes approximately 12–13 ticks (36–39 seconds).

**Strategy**: Time sales to the peak of the wave. The graphs panel visualizes this pattern clearly.

### Platinum — Boom & Bust

Price slowly climbs until a random crash.

**Mechanics:** `_platinum_pressure` increases by `randf_range(0.1, 0.4)` each tick. Bust chance is `pressure * 0.03` — increases as pressure builds. On bust: pressure resets to 0, price crashes.

**Formula:**

```
bonus = floor(_platinum_pressure)
price = clamp(5 + bonus, 2, 10)
```

**Strategy**: Platinum starts at 5 and climbs. The longer you wait, the higher the payout — but also the higher the crash risk. Sell before the bust.

### Fuel — Mean-Reverting with Spikes

Fuel is not a mineral the player collects. It's used for the **Fuel Futures** financial system.

| Constant | Value |
|----------|-------|
| Base price | 50 |
| Min / Max price | 15 / 95 |
| Mean reversion | 0.08 |
| Volatility | 4.0 |
| Spike chance | 12% per tick |
| Spike magnitude | 12.0 |

**Formula:**

```
reversion = (50 - current_price) * 0.08
noise = randf_range(-4.0, 4.0)
if randf() < 0.12:
    noise += randf_range(-12.0, 12.0)
price += reversion + noise  (accumulated as float, applied as int)
price = clamp(price, 15, 95)
```

**Behavior**: Gravitates toward 50 but with high volatility and occasional sharp spikes.

---

## 4.3 Price History & Graphs

The game visualizes market data through line graphs rendered entirely via Godot's `_draw()` API — no chart libraries, no textures.

**Two Variants:**

| Script | Class | Style |
|--------|-------|-------|
| `MineralPriceGraph.gd` | (none) | Colored lines (cyan default), dark background, dots at each data point |
| `MineralPriceGraph.B&W.gd` | `PriceGraph` | White lines on black background, no dots — matches the game's monochrome aesthetic |

The **B&W variant** (`PriceGraph`) is the one used in-game. It uses the DM Mono font for titles, disables the grid by default, and sets `point_radius` to 0 for clean lines only.

Each graph instance tracks **one mineral type** via its `@export var mineral_type` property. On `_ready()`, the graph connects to `Market.prices_changed` and caches the last 10 prices. Every market tick (3 seconds), the graph receives the signal, updates its cache, and calls `queue_redraw()`.

**Drawing Process** (`_draw()` renders three layers): Background (black filled rectangle), Labels (mineral name + " Price History" as title, $0–$8 on Y-axis, "Time →" on X-axis), and Price line (points spread evenly, connected by `draw_line()`, Y = `price / max_price * graph_height`).

**Configurable Properties:**

| Property | Default (B&W) | Description |
|----------|--------------|-------------|
| `mineral_type` | `IRON` | Which mineral to track |
| `line_color` | `Color.WHITE` | Line and point color |
| `line_width` | 2.0 | Thickness of connecting lines |
| `point_radius` | 0.0 | Radius of dots at data points (0 = no dots) |
| `background_color` | `Color(0, 0, 0, 0.8)` | Graph background |
| `grid_color` | `Color(0.3, 0.3, 0.4, 0.5)` | Grid line color |
| `text_color` | `Color.WHITE` | Label text color |
| `show_grid` | false | Toggle grid lines |
| `show_labels` | true | Toggle title and axis labels |
| `max_price` | 8 | Y-axis ceiling |
| `margin_left/right/top/bottom` | 40/20/30/30 | Graph area padding for labels |

**Panel Container:** The graphs live inside `graphs_panel.gd` (`Scenes/graphs_panel_ui.tscn`), a `PanelContainer` that occupies the bottom 27.78% of the screen. It slides in from the left when TAB is pressed and back out on the next TAB. One graph instance per mineral type is placed side by side.

---

## 4.4 Banking System

The bank is accessed from the **base scene** (via `bank.tscn`).

### Vault

Players deposit credits into the vault for safekeeping and earn compound interest. Every `compound_speed` seconds (default 30s), interest is calculated as `floor(balance * interest_rate)`, added to balance (capped at vault capacity), and the transaction is logged.

**Vault Upgrades:**

| Upgrade | Lv0 | Lv1 | Lv2 | Lv3 | Cost to Next |
|---------|-----|-----|-----|-----|-------------|
| Vault Capacity | 500 | 2,000 | 5,000 | 15,000 | 0/200/500/1500 |
| Interest Rate | 1% | 2% | 3% | 5% | 0/300/800/2000 |
| Compound Speed | 30s | 20s | 15s | 10s | 0/250/600/1800 |

**Key Functions:**

| Function | Purpose |
|----------|---------|
| `bank_deposit(amount)` | Move credits to vault (capped at capacity) |
| `bank_withdraw(amount)` | Move credits from vault to wallet |
| `get_bank_capacity()` | Current max vault size |
| `get_bank_interest_rate()` | Current interest rate |
| `get_bank_compound_interval()` | Seconds between interest calculations |
| `buy_bank_upgrade(name)` | Purchase vault/interest/speed upgrade |

**Transaction History:** The last 20 transactions are stored in `bank_transaction_history`. Each entry:
```gdscript
{ "type": "deposit"|"withdraw"|"interest"|"upgrade"|"bond_buy"|"bond_mature"|"future_buy"|"future_settle",
  "amount": int,
  "balance": int }
```

---

## 4.5 Bond System

Bonds are fixed-term investments. You lock credits for a set duration and receive a guaranteed payout.

| Tier | Duration | Return Rate | Min Investment | Payout Example |
|------|----------|------------|----------------|---------------|
| Short | 60s | 8% | 50 cr | 50 → 54 |
| Medium | 180s | 20% | 150 cr | 150 → 180 |
| Long | 360s | 40% | 300 cr | 300 → 420 |

**How Bonds Work:** Player calls `buy_bond("short")` — costs `min_investment` credits. Bond is added to `bank_bonds` array with elapsed = 0. Every frame, `_bond_tick(delta)` increments elapsed time. When `elapsed >= duration`, the bond matures: payout is `ceil(principal * (1 + rate))`, credits are added to wallet, bond is removed, and `bank_bond_changed` signal emits.

**Risk**: None. Bonds always pay out. The only cost is opportunity — your credits are locked.

---

## 4.6 Fuel Futures System

Fuel futures are **speculative contracts** that bet on fuel price movement. Unlike bonds, **you can lose money**.

| Tier | Duration | Leverage | Cost |
|------|----------|---------|------|
| Spot | 30s | 1.0x | 25 cr |
| Standard | 90s | 2.0x | 75 cr |
| Volatile | 180s | 3.0x | 150 cr |

**Max simultaneous contracts**: 6

**How Futures Work:** Player calls `buy_fuel_future("standard", true)` — `true` for long (betting price goes up), `false` for short (betting price goes down). The **strike price** is recorded as the current fuel price at time of purchase. Every frame, `_fuel_futures_tick(delta)` increments elapsed time. When `elapsed >= duration`, the contract settles.

**Settlement formula:**

```gdscript
# For long positions (betting price goes up):
price_change = (settle_price - strike_price) / strike_price

# For short positions (betting price goes down):
price_change = (strike_price - settle_price) / strike_price

payout = floor(cost * (1.0 + price_change * leverage))
payout = max(payout, 0)  # Can lose entire investment, never goes negative
```

**Example — Standard long at strike=50, fuel settles at 60:**
```
price_change = (60 - 50) / 50 = 0.20
payout = 75 * (1.0 + 0.20 * 2.0) = 75 * 1.40 = 105 credits → Profit: 30 credits
```

**Example — Same contract but fuel drops to 40:**
```
price_change = (40 - 50) / 50 = -0.20
payout = 75 * (1.0 + (-0.20) * 2.0) = 75 * 0.60 = 45 credits → Loss: 30 credits
```

**Strategy:** Long contracts — buy when fuel is below 50 (mean reversion pulls it up). Short contracts — buy when fuel is above 50 (mean reversion pulls it down). Volatile tier — highest risk/reward with 3x leverage. Watch for **spike events** (12% chance per tick) that can swing prices 12+ points.

---

## 4.7 Selling Minerals

When the player sells (via the upgrade panel's "SELL ALL" button):

```gdscript
func sell_all() -> void:
    for each mineral type:
        total += price * count
        if nickel: Market.record_nickel_sale(count)  # affects nickel pricing
        minerals[type] = 0
    add_credits(total)
    emit inventory_changed
    clear encumbrance if was encumbered
```

**Key detail**: Selling nickel triggers `record_nickel_sale()` which adds the sold amount to `_nickel_recent_sales`, resets `_nickel_appreciation` to 0, causes nickel price to drop, and prevents appreciation until sales pressure decays.

---

## 4.8 Cargo & Encumbrance

| Property | Default | Max (Upgraded) |
|----------|---------|---------------|
| Cargo Capacity | 40 | 170 |

When total minerals exceed cargo capacity: `is_over_encumbered()` returns true, `get_speed_multiplier()` returns `capacity / total` (min 0.25), player movement speed is reduced proportionally, cargo label turns red and shows speed percentage, and `over_encumbered` signal fires.

This creates a strategic tension: stay and keep mining (but move slower and be more vulnerable) or sell and reset.

---

# 5. Upgrade System

## Overview

The upgrade system is **data-driven**. All upgrade definitions, levels, and values live in `GameState.upgrades` — a nested Dictionary that acts as the single source of truth. UI, components, and weapons all read from this registry.

Two categories: **Level-capped upgrades** (fixed number of levels with lookup tables) and **Infinite upgrades** (formulas that scale indefinitely with escalating costs).

---

## 5.1 The Upgrade Registry

Located in `GameState.upgrades`:

```
upgrades
├── weapons
│   ├── Primary Cannon    (level-capped, 4 levels)
│   ├── Laser Beam        (level-capped, 4 levels)
│   ├── Rocket Launcher   (unlock + infinite sub-upgrades)
│   ├── Mine Layer         (unlock + infinite sub-upgrades)
│   └── Railgun            (level-capped, 4 levels)
├── shield
│   ├── max_capacity       (level-capped, 5 levels)
│   ├── regen_rate         (level-capped, 5 levels)
│   └── regen_delay        (level-capped, 5 levels)
├── radar
│   └── zoom_level         (level-capped, 5 levels)
├── cargo
│   └── capacity           (level-capped, 5 levels)
├── tractor_beam
│   └── power              (infinite)
└── spawner
    └── difficulty          (0–4, auto-managed by timer)
```

---

## 5.2 Weapon Upgrades

### Primary Cannon

| Level | Damage | Cooldown | Cost |
|-------|--------|----------|------|
| 1 (default) | 1.0 | 0.50s | — |
| 2 | 1.0 | 0.35s | 50 cr |
| 3 | 2.0 | 0.35s | 150 cr |
| 4 | 2.0 | 0.20s | 400 cr |

### Laser Beam

| Level | Max Damage/Tick | Cost |
|-------|----------------|------|
| Unlock | — | 100 cr |
| 1 | 50.0 | — |
| 2 | 75.0 | 200 cr |
| 3 | 100.0 | 400 cr |
| 4 | 150.0 | 800 cr |

### Railgun

| Level | Damage | Cooldown | Pierce Falloff | Cost |
|-------|--------|----------|---------------|------|
| Unlock | — | — | — | 150 cr |
| 1 | 3.0 | 5.0s | 20% | — |
| 2 | 4.0 | 4.5s | 15% | 300 cr |
| 3 | 5.0 | 4.0s | 10% | 600 cr |
| 4 | 7.0 | 3.5s | 5% | 1200 cr |

### Rocket Launcher (Infinite Sub-Upgrades)

Unlock cost: **100 cr**. Three independent upgrade tracks:

| Track | Formula | Base Value |
|-------|---------|-----------|
| Damage | `1.0 + level` | 1.0 |
| Speed | `400 * (1 + 0.2 * level)` | 400 |
| Fire Rate (cooldown) | `2.0 / (1 + 0.25 * level)` | 2.0s |

**Cost per level**: `ceil(100 * 1.5^level)`

| Level | Cost |
|-------|------|
| 0 → 1 | 100 |
| 1 → 2 | 150 |
| 2 → 3 | 225 |
| 3 → 4 | 338 |
| 4 → 5 | 506 |
| ... | +50% each |

### Mine Layer (Infinite Sub-Upgrades)

Unlock cost: **100 cr**. Two independent upgrade tracks:

| Track | Formula | Base Value |
|-------|---------|-----------|
| Place Speed (cooldown) | `3.0 / (1 + 0.25 * level)` | 3.0s |
| Blast Radius | `350 * (1 + 0.15 * level)` | 350 |

**Cost per level**: `ceil(100 * 1.5^level)` (same formula as rockets).

---

## 5.3 Shield Upgrades

| Upgrade | Lv0 | Lv1 | Lv2 | Lv3 | Lv4 |
|---------|-----|-----|-----|-----|-----|
| Max Capacity | 100 | 150 | 200 | 300 | 500 |
| Regen Rate (per sec) | 10 | 15 | 20 | 30 | 50 |
| Regen Delay (seconds) | 3.0 | 2.5 | 2.0 | 1.5 | 1.0 |

**Costs:**

| Upgrade | Lv1 | Lv2 | Lv3 | Lv4 | Lv5 |
|---------|-----|-----|-----|-----|-----|
| Max Capacity | 50 | 100 | 250 | 500 | 1000 |
| Regen Rate | 50 | 100 | 250 | 500 | 1000 |
| Regen Delay | 75 | 150 | 350 | 700 | 1400 |

When max shield capacity increases, the player's current shield is healed proportionally (same percentage of new max).

---

## 5.4 Radar Upgrades

| Level | Zoom Value | Cost |
|-------|-----------|------|
| 0 | 1.0x | — |
| 1 | 1.2x | 50 |
| 2 | 1.5x | 100 |
| 3 | 2.0x | 200 |
| 4 | 2.5x | 400 |
| 5 | — | 800 |

> **Note**: Radar zoom is currently **disabled** in code (conflicts with the graphs panel camera zoom). The values are calculated and stored but not applied. See `RadarComponent._apply_base_zoom()`.

---

## 5.5 Cargo Upgrades

| Level | Capacity | Cost |
|-------|----------|------|
| 0 | 40 | — |
| 1 | 60 | 75 |
| 2 | 80 | 150 |
| 3 | 120 | 300 |
| 4 | 170 | 600 |
| 5 | — | 1200 |

Cargo capacity determines the encumbrance threshold. Over-capacity movement penalty scales from 100% down to 25% speed.

---

## 5.6 Tractor Beam Upgrades (Infinite)

Controls the magnet effect that pulls nearby minerals toward the player.

| Property | Formula | Base Value |
|----------|---------|-----------|
| Range | `150 * (1 + 0.20 * level)` | 150 units |
| Strength | `80 * (1 + 0.25 * level)` | 80 |

**Cost per level**: `ceil(75 * 1.4^level)`

| Level | Cost | Range | Strength |
|-------|------|-------|----------|
| 0 | — | 150 | 80 |
| 1 | 75 | 180 | 100 |
| 2 | 105 | 210 | 120 |
| 3 | 147 | 240 | 140 |
| 4 | 206 | 270 | 160 |
| ... | +40% each | +20% each | +25% each |

---

## 5.7 Spawner Difficulty (Auto-Managed)

Difficulty is **not purchased** — it auto-escalates based on elapsed time.

```gdscript
# In main.gd _process():
var target_level := clampi(1 + int(_run_time / 60.0), 0, 4)
```

| Level | Name | Timer | Spawn Interval | Count | Health | Speed Range |
|-------|------|-------|----------------|-------|--------|-------------|
| 0 | Easy | — | 3.0s | 1 | 2 HP | 150–250 |
| 1 | Normal | 0:00 | 2.0s | 1 | 2 HP | 200–300 |
| 2 | Hard | 1:00 | 1.5s | 1 | 3 HP | 250–400 |
| 3 | Very Hard | 2:00 | 1.0s | 2 | 3 HP | 300–500 |
| 4 | Extreme | 3:00 | 0.8s | 2 | 4 HP | 350–600 |

The game starts at **Normal** (level 1) and increases by one level every 60 seconds.

---

## 5.8 Drone Upgrades (Exotic Minerals)

Purchased at the base using exotic minerals (not credits).

### Drone Armor — Reduces drone break chance during voyages/expeditions.

| Level | Break Reduction | Cost |
|-------|----------------|------|
| 0 | 0% | — |
| 1 | 25% | 5 Cobalt |
| 2 | 50% | 10 Cobalt |
| 3 | 75% | 20 Cobalt |

### Mineral Scanners — Bonus minerals per surviving drone on voyages.

| Level | Bonus Minerals | Cost |
|-------|---------------|------|
| 0 | +0 | — |
| 1 | +1 | 5 Titanium |
| 2 | +2 | 10 Titanium |
| 3 | +3 | 20 Titanium |

### Warp Drive — Reduces voyage/expedition duration.

| Level | Duration Multiplier | Cost |
|-------|-------------------|------|
| 0 | 1.00x (no reduction) | — |
| 1 | 0.85x (-15%) | 3 Xenocryst |
| 2 | 0.70x (-30%) | 8 Xenocryst |
| 3 | 0.55x (-45%) | 15 Xenocryst |

### Deep Probes — Better exotic mineral yields from expeditions.

| Level | Yield Multiplier | Cost |
|-------|-----------------|------|
| 0 | 1.0x | — |
| 1 | 1.5x | 2 Iridium |
| 2 | 2.0x | 5 Iridium |
| 3 | 2.5x | 10 Iridium |

---

## 5.9 Upgrade Purchase Flow

```
Player presses upgrade button in UI
    └──> upgrade_panel._on_buy_pressed(system, name)
              ├──> Check credits >= cost
              ├──> GameState.add_credits(-cost)
              └──> if weapon and locked:
              │         GameState.unlock_weapon(name)
              │    elif weapon:
              │         GameState.upgrade_weapon(name)
              │    else:
              │         GameState.upgrade_system(system, name)
              │              └──> _sync_legacy_variables()
              └──> GameState emits upgrades_changed
                        ├──> WeaponManager.sync_upgrades()
                        ├──> ShieldComponent.sync_with_game_state()
                        ├──> RadarComponent.sync_with_game_state()
                        ├──> AsteroidSpawner.sync_with_game_state()
                        └──> upgrade_panel._refresh_upgrade_list()
```

---

## 5.10 The Upgrade Panel UI (`Scripts/upgrade_panel.gd`)

The upgrade panel is a `PanelContainer` that slides in from the left when TAB is pressed. It occupies the left 27.78% of the screen width, from top to the graphs panel boundary.

**Layout (top to bottom):**

1. **Scrollable upgrade list** — WEAPONS section (with sub-rows for rocket/mine upgrades), SHIELDS section, RADAR section, CARGO section, TRACTOR BEAM section
2. **Fixed inventory display** (pinned at bottom) — Mineral counts with live prices, cargo capacity indicator, credits display, SELL ALL button, exotic minerals display

All buttons use the standard black-and-white styling: black background, gray 1px border, 0 corner radius, white text.

---

# 6. Entities & World Systems

## 6.1 Player Ship

**Scene**: `Scenes/player.tscn` — **Script**: `Scripts/player.gd`

The player ship is a Node2D with procedurally drawn triangle visuals. It uses smooth cursor-following movement.

**Movement:** Input via WASD or left gamepad stick. Aim via mouse position or right gamepad stick. Follow strength is `GameState.move_follow_strength` (default 12.0) — higher = snappier. Speed is affected by `GameState.get_speed_multiplier()` when over-encumbered (min 25% speed).

**Components Attached to Player:**

| Component | Purpose |
|-----------|---------|
| `WeaponManager` | Manages all weapon instances |
| `ShieldComponent` | Handles damage, regen, game over |
| `RadarComponent` | Manages camera zoom (currently disabled) |
| Shield bar (`shield_bar.gd`) | Visual HP bar that follows the ship |

**Key Functions:**

| Function | Purpose |
|----------|---------|
| `take_damage(amount)` | Routes to ShieldComponent |
| `popup_mineral(name)` | Spawns floating "+1 Iron" text |
| `popup_cargo_full()` | Spawns "CARGO FULL" warning text |

**Mineral Collection:** The player has an `Area2D` pickup zone. When minerals enter this zone: mineral's `kind` is read, `GameState.add_mineral(kind)` is called, `GameState.add_mat(kind)` sets the current mineral type, floating text spawns showing the mineral name, `collect` sound plays via AudioManager, mineral node is freed.

---

## 6.2 Asteroids

**Scene**: `Scenes/asteroid.tscn` — **Script**: `Scripts/asteroid.gd` — **Class name**: `Asteroid` — **Extends**: `RigidBody2D`

**Properties:**

| Property | Default | Description |
|----------|---------|-------------|
| `radius` | 28.0 | Visual and collision size |
| `hit_points` | 2 | Hits to destroy |
| `split_radius_factor` | 0.5 | Child radius = parent × this |
| `min_split_radius` | 14.0 | Don't split below this |
| `mineral_drop_count` | 1 | Minerals dropped on break |

**Physics:** `gravity_scale = 0` (space), `linear_damp = 0` / `angular_damp = 0` (no friction), random angular velocity on spawn (-1.2 to 1.2 rad/s) for visual rotation, linear velocity is forced every physics tick to prevent physics engine from zeroing it.

**Splitting Behavior** (when hit_points reaches 0): Sound plays (`explode_big` if splitting, `explode_small` if not). Break particles spawn. Minerals drop (1–3, random type). **If `child_radius >= min_split_radius`**: splits into 2 smaller asteroids — children have `hit_points = 1`, `radius = parent.radius * 0.5`, and inherit parent's direction and speed. Parent is freed.

**Collision with Player:** Base damage: 20 points, scaled by `radius / 28.0` (bigger asteroids = more damage). Knockback applied to both. Asteroid self-destructs after collision.

---

## 6.3 Asteroid Spawner

**Script**: `Scripts/components/asteroid_spawner.gd` — **Class name**: `AsteroidSpawner` — **Extends**: `Node`

A component attached to the main scene that manages asteroid spawning. A Timer fires at `spawn_interval` (varies by difficulty). Each tick spawns `spawn_count` asteroids at a random screen edge, 100px beyond camera view.

**Trajectory Modes:**

| Mode | Behavior |
|------|----------|
| `RANDOM_ACROSS` | Aims at a random point on the opposite screen edge |
| `TOWARD_PLAYER` | Aims directly at the player's position |
| `TOWARD_CENTER` | Aims at the camera center |
| `MIXED` | 60% random across, 20% toward player, 20% toward center |

The game defaults to `RANDOM_ACROSS`.

The spawner reads the camera's zoom and position to calculate the visible area. Asteroids spawn just outside this area — when the camera zooms out (menu open), asteroids spawn further away. Asteroids always enter from off-screen, never pop in.

**Key Functions:**

| Function | Purpose |
|----------|---------|
| `sync_with_game_state()` | Read difficulty from GameState, apply settings |
| `_apply_difficulty_level(level)` | Set interval, count, health, speed for a difficulty |
| `set_difficulty(level)` | Manual difficulty override (testing) |
| `set_spawning_enabled(enabled)` | Pause/resume spawning |
| `spawn_now(count)` | Force spawn (testing) |

---

## 6.4 Shield Component

**Script**: `Scripts/components/shield_component.gd` — **Class name**: `ShieldComponent` — **Extends**: `Node`

Shield starts at max capacity. Damage reduces shield. After taking damage, regen pauses for `shield_regen_delay` seconds. After the delay, shield regenerates at `shield_regen_rate` per second. When shield reaches 0: **Game Over** (scene changes to `GameOver.tscn`).

**Visual Feedback:** On damage, player ship flashes red `(1.5, 0.5, 0.5)` for 0.1 seconds. Shield bar (drawn by `shield_bar.gd`) shows current/max as a white bar above the player.

**Upgrade Sync:** When upgrades change, old max shield is stored, new values are read from `GameState.upgrades.shield`, and if max increased, current shield is healed proportionally: `current = new_max * (old_current / old_max)`.

---

## 6.5 Shield Bar (`Scripts/shield_bar.gd`)

A `Node2D` attached as a child of the player ship. Draws the shield bar using `_draw()`: white rectangle showing current health, positioned above the player, updates every frame based on `GameState.shield_changed` signal.

---

## 6.6 Minerals

**Scene**: `Scenes/mineral.tscn` — **Script**: `Scripts/mineral.gd`

Dropped when asteroids break. Small collectible items that drift in space. `kind` property is `MineralType` enum — randomly assigned on drop. Spawns at asteroid's death position with small random offset. Drifts slowly or stays stationary. Collected when entering player's pickup area — triggers floating text and `collect` sound.

**Tractor Beam Interaction:** When the tractor beam is upgraded, minerals within range are pulled toward the player at the beam's strength. Range and strength scale with `GameState.get_tractor_beam_range()` and `get_tractor_beam_strength()`.

---

## 6.7 Floating Text

**Scene**: `Scenes/floating_text_2d.tscn` — **Script**: `Scripts/floating_text_2d.gd`

Small text labels that appear at the player's position and float upward before fading. Used for "+1 Iron", "+1 Nickel", etc. on mineral pickup, and "CARGO FULL" when capacity is reached.

---

## 6.8 Drones (Visual Only)

Drones are drawn procedurally in `base.gd` using inner classes:

**Voyage Drones (`_DroneDrawer`):** Small white triangle polyline, scale 0.4x, bob up and down with sine wave animation, positioned in left side of drone area.

**Expedition Drones (`_ExpeditionDroneDrawer`):** Small blue `(0.4, 0.7, 1.0)` triangle polyline, same scale and animation, positioned in right side of drone area.

Drones are purely visual at the base — they disappear when sent on voyages/expeditions and reappear when the mission completes (minus any lost drones).

---

## 6.9 Base Scene

**Scene**: `Scenes/base.tscn` — **Script**: `Scripts/base.gd`

The space station / home base where the player manages passive systems.

**Visual Elements:** Docked ship flies in from the left with a tween, then bobs gently. Drone formation is a grid of small triangles showing owned drones. Planet sprites are background planet images (bitmap — the only non-procedural visuals).

**UI Layout** (right-side menu with stacked panels):

1. **DRONE BAY** panel (white border) — Buy Voyage Drone button (75 cr), SEND ON VOYAGE section with 3 tier buttons, progress bar (visible during active voyage)
2. **EXPEDITIONS** panel (blue border) — Buy Expedition Drone button (75 cr), 3 expedition tier buttons, progress bar (visible during active expedition)
3. **DRONE UPGRADES** panel (purple border) — Exotic mineral inventory display, 4 upgrade rows (Drone Armor, Mineral Scanners, Warp Drive, Deep Probes)

**Navigation:** Back button returns to `main.tscn`. Credits and vault balance displayed at top-left.

---

## 6.10 Voyage & Expedition Flow

### Starting a Voyage

```
Player presses voyage tier button at base
    └──> VoyageManager.start_voyage(tier)
              ├──> All voyage drones are committed
              ├──> Duration = tier_duration × warp_drive_multiplier
              └──> GameState.voyage_started emits
```

### During a Voyage

```
VoyageManager._process(delta) each frame:
    └──> voyage_elapsed += delta
    └──> Emit voyage_progress_updated(progress)
              ├──> base.gd updates progress bar
              └──> main.gd updates voyage bar (if in main scene)
```

### Completing a Voyage

```
voyage_elapsed >= voyage_duration:
    └──> _complete_voyage()
              ├──> For each drone:
              │         Roll break_chance × (1 - armor_reduction)
              │         If survived: collect randi_range(min, max) + scanner_bonus minerals
              │         If broken: drone is lost
              ├──> Remove lost drones from GameState
              ├──> Add collected minerals to GameState
              └──> Emit voyage_completed(results)
                        ├──> base.gd shows results text
                        └──> main.gd shows results banner (6 seconds)
```

### Mineral Drop Rates (Voyages)

| Mineral | Weight | Chance |
|---------|--------|--------|
| Iron | 0.40 | 40% |
| Nickel | 0.30 | 30% |
| Silica | 0.20 | 20% |
| Platinum | 0.10 | 10% |

### Exotic Mineral Drop Rates (Expeditions)

| Mineral | Weight | Chance |
|---------|--------|--------|
| Cobalt | 0.40 | 40% |
| Titanium | 0.30 | 30% |
| Xenocryst | 0.20 | 20% |
| Iridium | 0.10 | 10% |

---

## 6.11 Menu Toggle System

Pressing **TAB** triggers `_toggle_menus()` in `main.gd`.

**Opening Menus (TAB):** Graphs panel slides in from left (bottom 27.78% of screen). Upgrade panel slides in from left (left 27.78%, top to graphs boundary). Voyage progress bar slides in (above graphs panel). Expedition progress bar slides in (above voyage bar). "Go to Base" button slides down from above screen. Camera zooms out to 0.75x. Camera limits expand.

**Closing Menus (TAB again):** Everything reverses — panels slide out, camera zooms back to 1.0x, limits restore.

All animations use `Tween` with `EASE_OUT` / `EASE_IN` and `TRANS_CUBIC` for smooth motion. Duration: 0.5 seconds.

---

## 6.12 Particle Effects

| Scene | Used By | Description |
|-------|---------|-------------|
| `break_particles.tscn` | Asteroid destruction | Debris effect on asteroid break |
| `rocket_particles.tscn` | Rocket trail | Exhaust trail behind rockets |
| `rocket_explode_particle.tscn` | Rocket/Mine explosion | Blast effect |

All particles use `GPUParticles2D` with `one_shot = true` and self-free on `finished`.

---

# 7. Script-by-Script Reference

Every script's purpose and major functions.

---

## 7.1 Root-Level Scripts

### `Scripts/game_state.gd`
**Extends:** Node (Autoload singleton)
**Purpose:** Central state manager — holds all persistent game data and emits signals on changes.

| Function | Purpose |
|----------|---------|
| `add_credits(amount)` | Add/subtract credits, emit `credits_changed` |
| `add_mineral(kind, amount)` | Add minerals, check cargo, emit signals |
| `sell_all()` | Sell all minerals at market prices |
| `get_total_minerals()` | Sum of all mineral counts |
| `is_over_encumbered()` | True if minerals exceed cargo capacity |
| `get_speed_multiplier()` | 1.0 normal, scales down to 0.25 when over capacity |
| `unlock_weapon(name)` | Unlock a weapon in the registry |
| `upgrade_weapon(name)` | Increment weapon level |
| `upgrade_system(system, upgrade)` | Upgrade non-weapon system |
| `get_upgrade_value(system, upgrade)` | Read current value from registry |
| `is_weapon_unlocked(name)` | Check weapon lock state |
| `set_spawner_difficulty(level)` | Set asteroid difficulty 0–4 |
| `get_rocket_damage/speed/cooldown()` | Formula-based rocket stats |
| `get_mine_cooldown/blast_radius()` | Formula-based mine stats |
| `get_tractor_beam_range/strength()` | Formula-based tractor stats |
| `buy_voyage_drone()` | Purchase a voyage drone for 75cr |
| `buy_expedition_drone()` | Purchase an expedition drone for 75cr |
| `add_exotic_mineral(kind, amount)` | Add exotic minerals |
| `buy_drone_upgrade(name)` | Purchase drone upgrade with exotics |
| `bank_deposit/withdraw(amount)` | Move credits to/from vault |
| `buy_bond(tier)` | Purchase a bond |
| `buy_fuel_future(tier, is_long)` | Purchase a futures contract |
| `_bank_tick(delta)` | Process compound interest each frame |
| `_bond_tick(delta)` | Mature bonds when duration expires |
| `_fuel_futures_tick(delta)` | Settle futures when expired |

---

### `Scripts/main.gd`
**Extends:** Node2D
**Purpose:** Main gameplay scene — player, menus, difficulty, UI overlays.

| Function | Purpose |
|----------|---------|
| `_ready()` | Spawn player, setup spawner, create UI, connect signals |
| `_process(delta)` | Run timer, auto-difficulty, base countdown |
| `_toggle_menus()` | Toggle panels, camera zoom, progress bars |
| `_zoom_camera_out/in()` | Tween camera to 0.75x / back to 1.0x |
| `_on_go_to_base_pressed()` | Start 5-second countdown to base |
| `_on_voyage_completed(results)` | Show results banner for 6 seconds |

---

### `Scripts/Market.gd`
**Extends:** Node (Autoload singleton)
**Purpose:** Dynamic market pricing with 4 mineral models + fuel.

| Function | Purpose |
|----------|---------|
| `_update_iron_price()` | Random walk: -1, 0, or +1 |
| `_update_nickel_price()` | Supply/demand with appreciation |
| `_update_silica_price()` | Sine wave pattern |
| `_update_platinum_price()` | Boom-and-bust with random crash |
| `_update_fuel_price()` | Mean-reverting with volatility spikes |
| `get_price(mineral)` | Current price |
| `get_price_history(mineral)` | Last 10 prices |
| `record_nickel_sale(amount)` | Record sale for supply/demand |

---

### `Scripts/player.gd`
**Extends:** CharacterBody2D
**Purpose:** Player ship — movement, aiming, weapon input, component setup.

| Function | Purpose |
|----------|---------|
| `_handle_move(delta)` | WASD with acceleration/friction, encumbrance |
| `_handle_aim()` | Rotate ship toward mouse when mouse moves |
| `_handle_weapon_input()` | Laser (RMB), Railgun (R key edge detection) |
| `_setup_weapon_system()` | Create WeaponManager, add 5 weapons, bind inputs |
| `_setup_shield_system()` | Create ShieldComponent |
| `take_damage(amount)` | Forward to ShieldComponent |
| `popup_mineral(name)` | Spawn floating mineral text |
| `_clamp_to_camera_bounds()` | Keep player inside camera limits |
| `_draw()` | Draw white triangle polyline |

---

### `Scripts/asteroid.gd`
**Extends:** RigidBody2D
**Purpose:** Asteroid entity — physics, damage, splitting, mineral drops.

| Function | Purpose |
|----------|---------|
| `setup_motion(from, target, speed)` | Set position and velocity |
| `hit_by_projectile(shooter)` | Decrement HP, break if 0 |
| `_break_safe()` | Sound, particles, minerals, split, free |
| `_on_body_entered(body)` | Damage player on collision |

---

### `Scripts/asteroid_visuals.gd`
**Extends:** Node2D
**Purpose:** Procedural irregular white polygon asteroid shape.

| Function | Purpose |
|----------|---------|
| `set_radius(r)` | Update size and regenerate shape |
| `_generate_shape()` | Create polygon with random vertex offsets |
| `_draw()` | Draw white polyline outline |

---

### `Scripts/audio_manager.gd`
**Extends:** Node (Autoload singleton)
**Purpose:** Centralized audio with pooled SFX and sequential queue.

| Function | Purpose |
|----------|---------|
| `play_sfx(key, volume, pitch)` | Play sound (overlapping, round-robin pool of 8) |
| `play_sfx_queued(key, volume, pitch)` | Play sequentially (no overlap) |
| `play_music(key, volume)` | Play music track |
| `stop_music()` | Stop current music |

---

### `Scripts/screen_utils.gd`
**Extends:** Node (Autoload singleton)
**Purpose:** Viewport utilities and camera boundary management.

| Function | Purpose |
|----------|---------|
| `is_position_on_screen(node, pos)` | Static. Check if world pos is visible |
| `is_node_on_screen(node)` | Static. Check if Node2D is on screen |
| `set_main_camera(camera)` | Store camera and save original limits |
| `adjust_boundaries(...)` | Tween camera limits for UI panels |
| `restore_boundaries(duration)` | Tween limits back to originals |

---

### `Scripts/upgrade_panel.gd`
**Extends:** PanelContainer
**Purpose:** Left-side upgrade shop + inventory display.

| Function | Purpose |
|----------|---------|
| `slide_in/out()` | Tween panel on/off screen |
| `_build_upgrade_list()` | Generate all upgrade rows from GameState |
| `_build_inventory_section()` | Mineral counts, prices, sell button, exotics |
| `_on_buy_pressed(system, name)` | Purchase level-capped upgrades |
| `_on_rocket_sub_buy(type)` | Purchase rocket sub-upgrades |
| `_on_mine_sub_buy(type)` | Purchase mine sub-upgrades |
| `_on_tractor_beam_buy()` | Purchase tractor beam upgrade |
| `_on_sell_all()` | Call `GameState.sell_all()` |

---

### `Scripts/voyage_manager.gd`
**Extends:** Node (Autoload singleton)
**Purpose:** Automated drone voyages for standard minerals.

| Function | Purpose |
|----------|---------|
| `start_voyage(tier)` | Begin voyage with all voyage drones |
| `get_progress()` | Current progress 0.0–1.0 |
| `_complete_voyage()` | Roll for each drone, distribute minerals |

---

### `Scripts/expedition_manager.gd`
**Extends:** Node (Autoload singleton)
**Purpose:** Automated drone expeditions for exotic minerals.

| Function | Purpose |
|----------|---------|
| `start_expedition(tier)` | Begin with all expedition drones |
| `get_progress()` | Current progress 0.0–1.0 |
| `_complete_expedition()` | Roll for each drone, distribute exotics |

---

### `Scripts/base.gd`
**Extends:** Node2D
**Purpose:** Base/station — drone management, voyages, expeditions, upgrades.

| Function | Purpose |
|----------|---------|
| `_spawn_docked_ship()` | Ship fly-in tween + bobbing |
| `_refresh_drone_visuals()` | Redraw drone grid |
| `_build_voyage_ui()` | Drone Bay panel |
| `_build_expedition_ui()` | Expeditions panel |
| `_build_drone_upgrades_ui()` | Upgrades panel with exotic inventory |
| `_on_back_button_pressed()` | Return to main.tscn |

**Inner classes:** `_ShipDrawer`, `_DroneDrawer`, `_ExpeditionDroneDrawer`, `_VoyageProgressBar`

---

## 7.2 Components (`Scripts/components/`)

### `asteroid_spawner.gd` — `AsteroidSpawner`
Spawns asteroids at screen edges with difficulty scaling.

| Function | Purpose |
|----------|---------|
| `_spawn_single_asteroid()` | Create one asteroid with position/direction/speed |
| `sync_with_game_state()` | Read difficulty, apply settings |
| `_apply_difficulty_level(level)` | Set interval/count/health/speed |
| `set_spawning_enabled(enabled)` | Start/stop spawn timer |

### `shield_component.gd` — `ShieldComponent`
Shield HP, regeneration, damage flash, game over.

| Function | Purpose |
|----------|---------|
| `take_damage(amount)` | Reduce shield, reset regen timer, flash |
| `_handle_shield_regeneration(delta)` | Regenerate after delay |
| `sync_with_game_state()` | Read shield values from upgrades |

### `radar_component.gd` — `RadarComponent`
Camera zoom control (currently disabled).

| Function | Purpose |
|----------|---------|
| `sync_with_game_state()` | Read radar level |

---

## 7.3 Weapons (`Scripts/weapons/`)

### `weapon_base.gd` — `WeaponBase`
Abstract base class. See [Section 3.1](#31-weaponbase-scriptsweaponsweapon_basegd).

### `weapon_manager.gd` — `WeaponManager`
Orchestrates all weapons. See [Section 3.2](#32-weaponmanager-scriptsweaponsweapon_managergd).

### `primary_cannon.gd` — `PrimaryCannon`
Dual hitscan auto-fire.

| Function | Purpose |
|----------|---------|
| `_execute_fire()` | Two parallel raycasts + sound |
| `_hitscan_shot(pos, dir)` | Single raycast + visual + damage |

### `laser_beam.gd` — `LaserBeam`
Continuous beam with ramping damage.

| Function | Purpose |
|----------|---------|
| `_apply_damage(target)` | Ramped damage as integer hits |
| `get_ramp_percentage()` | Current damage ramp 0.0–1.0 |

### `railgun.gd` — `Railgun`
Piercing shot with cooldown and charge visual.

| Function | Purpose |
|----------|---------|
| `_fire_piercing_shot(pos, dir)` | Iterative raycast with falloff |
| `_show_beam_effect(start, end, hits)` | Line2D flash-to-fade |
| `get_cooldown_progress()` | Charge progress 0.0–1.0 |

### `rocket_launcher.gd` — `RocketLauncher`
Auto-fire homing rocket spawner.

### `mine_layer.gd` — `MineLayer`
Auto-deploy stationary mines.

---

## 7.4 Entity Scripts

### `rocket.gd` — Homing rocket projectile

| Function | Purpose |
|----------|---------|
| `_find_nearest_asteroid()` | Physics query for closest on-screen target |
| `_explode(direct_hit)` | Splash damage in radius |

### `mine.gd` — Timed mine

| Function | Purpose |
|----------|---------|
| `_explode()` | Particle + area damage + free |

### `mineral.gd` — Collectible mineral drop

### `floating_text_2d.gd` — Rising/fading feedback text

---

## 7.5 UI Scripts

| Script | Purpose |
|--------|---------|
| `graphs_panel.gd` | Price graph container (slides in/out) |
| `MineralPriceGraph.gd` | Line graph of last 10 prices |
| `shield_bar.gd` | Shield HP bar above player |
| `InventoryMenu.gd` | Standalone inventory display |
| `game_over.gd` | Game over screen |
| `start_menu.gd` | Start menu |

---

### `Scripts/bank.gd`
**Extends:** Node2D
**Purpose:** Bank/vault scene — manages the banking UI and financial instruments (vault deposits, bonds, fuel futures). This is an actively expanding feature.

---

## 7.6 Legacy / Utility

| Script | Purpose |
|--------|---------|
| `laser.gd` | Legacy laser (replaced by `weapons/laser_beam.gd`) |
| `radar.gd` | Legacy radar (replaced by `components/radar_component.gd`) |
| `Projectile.gd` / `Projectile_visual.gd` | Visual-only bullet effects |
| `test_upgrades.gd` (root) | Upgrade testing utility |
| `player_old_backup.gd` (root) | Pre-refactor player backup |

---

# Design Rules (Quick Reference)

1. **Black and white** — Color is used sparingly and only to communicate state
2. **Straight lines, sharp edges** — All corner radii are 0, no rounded elements
3. **Procedural drawing** — Gameplay visuals use `_draw()`, not sprites
4. **DM Mono font** — Monospace everywhere
5. **Signals over polling** — GameState emits, everything else listens
