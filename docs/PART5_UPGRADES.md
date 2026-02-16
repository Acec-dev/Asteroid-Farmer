# Asteroid Farmer - Part 5: Upgrade System Reference

> Part 5 of 7. See the [Table of Contents](./README.md) for all parts.

---

## Overview

The upgrade system is **data-driven**. All upgrade definitions, levels, and values live in `GameState.upgrades` — a nested Dictionary that acts as the single source of truth. UI, components, and weapons all read from this registry.

There are two categories of upgrades:
1. **Level-capped upgrades** — Have a fixed number of levels with lookup tables
2. **Infinite upgrades** — Use formulas that scale indefinitely with escalating costs

---

## The Upgrade Registry

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
    └── difficulty          (0-4, auto-managed by timer)
```

---

## Weapon Upgrades

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

Unlock cost: **100 cr**. After unlock, three independent upgrade tracks:

| Track | Formula | Base Value |
|-------|---------|-----------|
| Damage | `1.0 + level` | 1.0 |
| Speed | `400 * (1 + 0.2 * level)` | 400 |
| Fire Rate (cooldown) | `2.0 / (1 + 0.25 * level)` | 2.0s |

**Cost per level**: `ceil(100 * 1.5^level)`

| Level | Cost |
|-------|------|
| 0 -> 1 | 100 |
| 1 -> 2 | 150 |
| 2 -> 3 | 225 |
| 3 -> 4 | 338 |
| 4 -> 5 | 506 |
| ... | +50% each |

### Mine Layer (Infinite Sub-Upgrades)

Unlock cost: **100 cr**. After unlock, two independent upgrade tracks:

| Track | Formula | Base Value |
|-------|---------|-----------|
| Place Speed (cooldown) | `3.0 / (1 + 0.25 * level)` | 3.0s |
| Blast Radius | `350 * (1 + 0.15 * level)` | 350 |

**Cost per level**: `ceil(100 * 1.5^level)` (same formula as rockets)

---

## Shield Upgrades

| Upgrade | Lv0 | Lv1 | Lv2 | Lv3 | Lv4 |
|---------|-----|-----|-----|-----|-----|
| Max Capacity | 100 | 150 | 200 | 300 | 500 |
| Regen Rate (per sec) | 10 | 15 | 20 | 30 | 50 |
| Regen Delay (seconds) | 3.0 | 2.5 | 2.0 | 1.5 | 1.0 |

**Costs**:

| Upgrade | Lv1 | Lv2 | Lv3 | Lv4 | Lv5 |
|---------|-----|-----|-----|-----|-----|
| Max Capacity | 50 | 100 | 250 | 500 | 1000 |
| Regen Rate | 50 | 100 | 250 | 500 | 1000 |
| Regen Delay | 75 | 150 | 350 | 700 | 1400 |

When max shield capacity increases, the player's current shield is healed proportionally (same percentage of new max).

---

## Radar Upgrades

| Level | Zoom Value | Cost |
|-------|-----------|------|
| 0 | 1.0x | — |
| 1 | 1.2x | 50 |
| 2 | 1.5x | 100 |
| 3 | 2.0x | 200 |
| 4 | 2.5x | 400 |
| 5 | — | 800 |

**Note**: Radar zoom is currently **disabled** in code (conflicts with the graphs panel camera zoom). The values are calculated and stored but not applied to the camera. See `RadarComponent._apply_base_zoom()`.

---

## Cargo Upgrades

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

## Tractor Beam Upgrades (Infinite)

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

## Spawner Difficulty (Auto-Managed)

Difficulty is **not purchased** — it auto-escalates based on elapsed time.

```gdscript
# In main.gd _process():
var target_level := clampi(1 + int(_run_time / 60.0), 0, 4)
```

| Level | Name | Timer | Spawn Interval | Count | Health | Speed Range |
|-------|------|-------|----------------|-------|--------|-------------|
| 0 | Easy | — | 3.0s | 1 | 2 HP | 150-250 |
| 1 | Normal | 0:00 | 2.0s | 1 | 2 HP | 200-300 |
| 2 | Hard | 1:00 | 1.5s | 1 | 3 HP | 250-400 |
| 3 | Very Hard | 2:00 | 1.0s | 2 | 3 HP | 300-500 |
| 4 | Extreme | 3:00 | 0.8s | 2 | 4 HP | 350-600 |

The game starts at **Normal** (level 1) and increases by one level every 60 seconds.

---

## Drone Upgrades (Exotic Minerals)

These are purchased at the base using exotic minerals (not credits).

### Drone Armor

Reduces drone break chance during voyages/expeditions.

| Level | Break Reduction | Cost |
|-------|----------------|------|
| 0 | 0% | — |
| 1 | 25% | 5 Cobalt |
| 2 | 50% | 10 Cobalt |
| 3 | 75% | 20 Cobalt |

### Mineral Scanners

Bonus minerals per surviving drone on voyages.

| Level | Bonus Minerals | Cost |
|-------|---------------|------|
| 0 | +0 | — |
| 1 | +1 | 5 Titanium |
| 2 | +2 | 10 Titanium |
| 3 | +3 | 20 Titanium |

### Warp Drive

Reduces voyage/expedition duration.

| Level | Duration Multiplier | Cost |
|-------|-------------------|------|
| 0 | 1.00x (no reduction) | — |
| 1 | 0.85x (-15%) | 3 Xenocryst |
| 2 | 0.70x (-30%) | 8 Xenocryst |
| 3 | 0.55x (-45%) | 15 Xenocryst |

### Deep Probes

Better exotic mineral yields from expeditions.

| Level | Yield Multiplier | Cost |
|-------|-----------------|------|
| 0 | 1.0x | — |
| 1 | 1.5x | 2 Iridium |
| 2 | 2.0x | 5 Iridium |
| 3 | 2.5x | 10 Iridium |

---

## Upgrade Purchase Flow

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

## The Upgrade Panel UI (`Scripts/upgrade_panel.gd`)

The upgrade panel is a `PanelContainer` that slides in from the left when TAB is pressed. It occupies the left 27.78% of the screen width, from top to the graphs panel boundary.

**Layout (top to bottom)**:
1. Scrollable upgrade list
   - WEAPONS section (with sub-rows for rocket/mine upgrades)
   - SHIELDS section
   - RADAR section
   - CARGO section
   - TRACTOR BEAM section
2. Fixed inventory display (pinned at bottom)
   - Mineral counts with live prices
   - Cargo capacity indicator
   - Credits display
   - SELL ALL button
   - Exotic minerals display

All buttons use the standard black-and-white styling: black background, gray 1px border, 0 corner radius, white text.

---

*Previous: [Part 4 - Economy](./PART4_ECONOMY.md)*
*Next: [Part 6 - Entities & World](./PART6_ENTITIES.md)*
