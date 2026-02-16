# Asteroid Farmer - Part 7: Script-by-Script Reference

> Part 7 of 7. See the [Table of Contents](./README.md) for all parts.

---

## How to Read This Reference

Each script entry includes:
- **File path** and what it extends
- **Purpose** — one-line summary
- **Major functions** — name and what they do

Scripts are grouped by directory.

---

## Root-Level Scripts

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
| `set_spawner_difficulty(level)` | Set asteroid difficulty 0-4 |
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
| `get_progress()` | Current progress 0.0-1.0 |
| `_complete_voyage()` | Roll for each drone, distribute minerals |

---

### `Scripts/expedition_manager.gd`
**Extends:** Node (Autoload singleton)
**Purpose:** Automated drone expeditions for exotic minerals.

| Function | Purpose |
|----------|---------|
| `start_expedition(tier)` | Begin with all expedition drones |
| `get_progress()` | Current progress 0.0-1.0 |
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

## Components (`Scripts/components/`)

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

## Weapons (`Scripts/weapons/`)

### `weapon_base.gd` — `WeaponBase`
Abstract base class. See [Part 3](./PART3_WEAPONS.md).

### `weapon_manager.gd` — `WeaponManager`
Orchestrates all weapons. See [Part 3](./PART3_WEAPONS.md).

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
| `get_ramp_percentage()` | Current damage ramp 0.0-1.0 |

### `railgun.gd` — `Railgun`
Piercing shot with cooldown and charge visual.

| Function | Purpose |
|----------|---------|
| `_fire_piercing_shot(pos, dir)` | Iterative raycast with falloff |
| `_show_beam_effect(start, end, hits)` | Line2D flash-to-fade |
| `get_cooldown_progress()` | Charge progress 0.0-1.0 |

### `rocket_launcher.gd` — `RocketLauncher`
Auto-fire homing rocket spawner.

### `mine_layer.gd` — `MineLayer`
Auto-deploy stationary mines.

---

## Entity Scripts

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

## UI Scripts

### `graphs_panel.gd` — Price graph container (slides in/out)
### `MineralPriceGraph.gd` — Line graph of last 10 prices
### `shield_bar.gd` — Shield HP bar above player
### `InventoryMenu.gd` — Standalone inventory display
### `game_over.gd` — Game over screen
### `start_menu.gd` — Start menu

---

## Legacy / Utility

| Script | Purpose |
|--------|---------|
| `laser.gd` | Legacy laser (replaced by `weapons/laser_beam.gd`) |
| `radar.gd` | Legacy radar (replaced by `components/radar_component.gd`) |
| `Projectile.gd` / `Projectile_visual.gd` | Visual-only bullet effects |
| `bank.gd` (root) | Bank/vault scene script |
| `test_upgrades.gd` (root) | Upgrade testing utility |
| `player_old_backup.gd` (root) | Pre-refactor player backup |

---

*Previous: [Part 6 - Entities & World](./PART6_ENTITIES.md)*
*Back to: [Table of Contents](./README.md)*
