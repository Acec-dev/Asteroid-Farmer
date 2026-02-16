# Asteroid Farmer - Part 3: Weapons System Reference

> Part 3 of 7. See the [Table of Contents](./README.md) for all parts.

---

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

## WeaponBase (`Scripts/weapons/weapon_base.gd`)

**Class name:** `WeaponBase`
**Extends:** `Node2D`

The abstract base class every weapon inherits from. Provides the shared interface.

### Properties

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

### Lifecycle

1. `initialize(owner)` — Called by WeaponManager when weapon is added. Sets owner reference, calls `_ready_weapon()`.
2. `update_weapon(delta)` — Called every frame by WeaponManager. Ticks cooldown, fires if active and ready.
3. `activate()` / `deactivate()` — Called on input press/release.
4. `apply_upgrade(level, stats)` — Called when GameState upgrades change.

### Virtual Methods (Override in Subclasses)

| Method | Purpose |
|--------|---------|
| `_ready_weapon()` | Weapon-specific initialization |
| `_execute_fire()` | **Core firing logic** — must be implemented |
| `_can_fire_custom()` | Additional firing conditions (default: true) |
| `_on_activated()` | Custom activation behavior |
| `_on_deactivated()` | Custom deactivation behavior |
| `_apply_custom_upgrade(stats)` | Handle weapon-specific upgrade data |

### Signals

| Signal | When |
|--------|------|
| `weapon_fired` | After `_execute_fire()` completes |
| `stats_updated` | After `apply_upgrade()` is called |

---

## WeaponManager (`Scripts/weapons/weapon_manager.gd`)

**Class name:** `WeaponManager`
**Extends:** `Node`

Orchestrates all weapons attached to the player.

### Key Functions

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

### How Upgrades Flow

```
GameState.upgrades_changed signal
    └──> WeaponManager._on_upgrades_changed()
              └──> sync_upgrades()
                        └──> For each weapon in GameState.upgrades.weapons:
                                  └──> weapon.apply_upgrade(level, stats)
```

The `_get_weapon_stats()` function is the translator between GameState's data format and each weapon's stats Dictionary. It handles:
- Generic `*_values` arrays (extracts stat name from key, looks up by level)
- Rocket Launcher formula-based stats (calls `GameState.get_rocket_*()`)
- Mine Layer formula-based stats (calls `GameState.get_mine_*()`)

---

## Primary Cannon (`Scripts/weapons/primary_cannon.gd`)

**Class name:** `PrimaryCannon`
**Extends:** `WeaponBase`
**Always unlocked** — the player's default weapon.

### How It Works

The Primary Cannon uses **dual hitscan raycasts**. On each fire:

1. Two parallel rays are cast from the player's position in the aim direction
2. Each ray extends 2000 units
3. If a ray hits an asteroid on screen, `hit_by_projectile()` is called on it
4. A visual-only projectile scene is spawned for feedback (white line that travels and fades)
5. The `gun_1` sound effect plays

### Stats by Level

| Level | Damage | Cooldown | Shots/Second |
|-------|--------|----------|-------------|
| 1 | 1.0 | 0.50s | 2.0 |
| 2 | 1.0 | 0.35s | 2.86 |
| 3 | 2.0 | 0.35s | 2.86 |
| 4 | 2.0 | 0.20s | 5.0 |

### Key Detail

The cannon fires **continuously while the fire button is held**. It auto-fires at the cooldown rate — the player does not need to click repeatedly.

---

## Laser Beam (`Scripts/weapons/laser_beam.gd`)

**Class name:** `LaserBeam`
**Extends:** `WeaponBase`
**Requires unlock** — bound to right mouse button.

### How It Works

The Laser Beam is a **continuous damage weapon with ramping damage**:

1. While held, a raycast fires forward from the player every frame
2. If the ray hits an asteroid, a damage timer ticks at 0.1s intervals
3. Damage starts at `base_beam_damage` (2.0) and ramps up to `max_beam_damage` (50.0) over `ramp_time` (3.0 seconds)
4. Switching targets resets the ramp
5. The beam is drawn every frame using `_draw()` with glow layers

### Visual Details

- Main beam: Red `(1.0, 0.3, 0.3)` with increasing alpha and width as damage ramps
- Outer glow: Same color at 30% alpha, 4px wider
- Impact circle: Drawn at hit point, grows with ramp progress

### Stats by Level

| Level | Max Damage/Tick |
|-------|----------------|
| 1 | 50.0 |
| 2 | 75.0 |
| 3 | 100.0 |
| 4 | 150.0 |

### Key Functions

| Function | Purpose |
|----------|---------|
| `get_ramp_percentage()` | Returns 0.0-1.0, how far into the damage ramp |
| `_apply_damage(target)` | Calculates ramped damage, applies as integer hits |
| `_reset_target()` | Clears target tracking, resets ramp timer |

### Override Behavior

The Laser overrides `update_weapon()` to skip standard cooldown-based firing. It has no cooldown — it fires continuously while active. The `_process()` function handles all beam logic independently.

---

## Railgun (`Scripts/weapons/railgun.gd`)

**Class name:** `Railgun`
**Extends:** `WeaponBase`
**Requires unlock** — bound to R key.

### How It Works

The Railgun fires a **single high-damage piercing shot**:

1. On fire, a ray is cast forward from the player
2. The ray hits the first asteroid, records the hit, then **excludes it and recasts**
3. This repeats until: no more targets, damage falls below minimum, or max pierce count reached
4. All hit asteroids take damage simultaneously
5. A `Line2D` beam visual appears (white flash -> cyan fade)

### Piercing Mechanics

Each pierce reduces damage by a falloff percentage:

```
Hit 1: full damage
Hit 2: damage * (1 - falloff)
Hit 3: damage * (1 - falloff)^2
...continues until damage < 0.5 or max_pierce_count (20) reached
```

### Stats by Level

| Level | Damage | Cooldown | Pierce Falloff |
|-------|--------|----------|---------------|
| 1 | 3.0 | 5.0s | 20% per pierce |
| 2 | 4.0 | 4.5s | 15% per pierce |
| 3 | 5.0 | 4.0s | 10% per pierce |
| 4 | 7.0 | 3.5s | 5% per pierce |

### Charge Visual

While on cooldown, a charge buildup line appears at the ship's barrel:
- Grows in length and brightness as cooldown progresses
- Pulses when fully charged (sine wave alpha)
- Disappears on fire

### Key Functions

| Function | Purpose |
|----------|---------|
| `_fire_piercing_shot(pos, dir)` | Core piercing raycast loop |
| `_apply_railgun_damage(obj, dmg)` | Tries `hit_by_railgun()` then `hit_by_projectile()` |
| `_show_beam_effect(start, end, hits)` | Draws the Line2D beam visual |
| `_update_charge_visual(progress)` | Updates charge buildup Line2D |
| `get_cooldown_progress()` | Returns 0.0-1.0 for UI/visuals |
| `get_status_text()` | "RAILGUN: READY" or "RAILGUN: 67%" |

---

## Rocket Launcher (`Scripts/weapons/rocket_launcher.gd`)

**Class name:** `RocketLauncher`
**Extends:** `WeaponBase`
**Requires unlock** — fires automatically.

### How It Works

The Rocket Launcher **auto-fires** at its cooldown rate. On each fire:

1. Instantiates the `rocket.tscn` scene at the player's position
2. Sets the rocket's damage and speed from current upgrade values
3. Adds the rocket to the scene tree

The rocket itself (`Scripts/rocket.gd`) handles all flight and targeting logic.

### Rocket Behavior (`Scripts/rocket.gd`)

- **Homing**: Queries a 500-unit radius for the nearest on-screen asteroid
- **Turning**: Rotates toward target at 3 radians/second
- **Speed**: 400 units/second (base), upgradeable
- **Lifetime**: 3 seconds, then self-destructs
- **On hit**: Deals direct damage, then splash damage in an 80-unit explosion radius
- **Visual**: White polygon triangle with tail fins, drawn via `_draw()`

### Upgrade System (Infinite, Escalating)

Rocket upgrades use formulas, not lookup tables. Each stat has its own level:

| Stat | Formula | Base | Per Level |
|------|---------|------|-----------|
| Damage | `1.0 + level` | 1.0 | +1.0 |
| Speed | `400 * (1 + 0.2 * level)` | 400 | +20% |
| Cooldown | `2.0 / (1 + 0.25 * level)` | 2.0s | Decreasing |

**Cost formula:** `ceil(100 * 1.5^level)` — starts at 100, grows 50% each level.

---

## Mine Layer (`Scripts/weapons/mine_layer.gd`)

**Class name:** `MineLayer`
**Extends:** `WeaponBase`
**Requires unlock** — deploys automatically.

### How It Works

The Mine Layer **auto-deploys mines** at the player's position at its cooldown rate. On each fire:

1. Instantiates the `mine.tscn` scene at the player's position
2. Sets the mine's explosion radius from current upgrade values
3. Adds the mine to the scene tree

### Mine Behavior (`Scripts/mine.gd`)

- **Timer**: Explodes after 3 seconds (fixed)
- **Blink**: In the last 1 second, blinks white-to-red with increasing frequency
- **Explosion**: Queries a 350-unit radius (base, upgradeable) for all bodies with `hit_by_projectile()`
- **Visual**: White circle with 8 spike lines, drawn via `_draw()`
- **Particle effect**: Spawns `rocket_explode_particle.tscn` on detonation

### Upgrade System (Infinite, Escalating)

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
                              ├──> Drop minerals (1-3 per asteroid)
                              ├──> If big enough: split into 2 smaller asteroids
                              └──> queue_free()
```

The Railgun has a special path that tries `hit_by_railgun()` first, falling back to `hit_by_projectile()`. The Laser converts float damage to integer hits.

---

*Previous: [Part 2 - Architecture](./PART2_ARCHITECTURE.md)*
*Next: [Part 4 - Economy & Market](./PART4_ECONOMY.md)*
