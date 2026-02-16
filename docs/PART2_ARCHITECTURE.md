# Asteroid Farmer - Part 2: Architecture & Autoloads

> Part 2 of 7. See the [Table of Contents](./README.md) for all parts.

---

## Architectural Pattern

Asteroid Farmer uses a **singleton + component** architecture:

- **Singletons (Autoloads)** hold global state and provide services accessible from any script.
- **Components** are modular nodes attached to entities (e.g., `ShieldComponent` on the player, `AsteroidSpawner` on the main scene).
- **Weapons** follow a class hierarchy: `WeaponBase` (abstract) -> specific weapons, managed by `WeaponManager`.

Communication between systems is primarily through **signals**. GameState is the central signal hub — most UI and gameplay systems connect to its signals rather than polling.

---

## Autoload Singletons

These are loaded automatically before any scene and are accessible globally by name.

### 1. GameState (`Scripts/game_state.gd`)

**The central state manager.** Every piece of persistent game data lives here.

**Responsibilities:**
- Stores player credits, minerals, exotic minerals
- Holds the entire upgrade registry (weapons, shield, radar, cargo, tractor beam, spawner)
- Manages bank balance, bonds, fuel futures
- Tracks drone counts (voyage + expedition)
- Manages cargo capacity and encumbrance
- Emits signals when any state changes

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
| `voyage_progress_updated` | `progress: float` | Voyage progress tick (0.0-1.0) |
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
| `set_spawner_difficulty(level)` | Set asteroid difficulty (0-4) |
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

**The `_process(delta)` Loop:**

Every frame, GameState ticks three financial systems:
1. `_bank_tick(delta)` — Accumulates interest on vault balance
2. `_bond_tick(delta)` — Matures bonds when their duration expires
3. `_fuel_futures_tick(delta)` — Settles fuel futures when expired

---

### 2. Market (`Scripts/Market.gd`)

**The economy engine.** Manages dynamic pricing for all minerals and fuel.

**Responsibilities:**
- Updates prices every 3 seconds via internal Timer
- Tracks price history (last 10 data points per mineral)
- Each mineral uses a different pricing model
- Emits `prices_changed` signal on each update

**Key Functions:**

| Function | Purpose |
|----------|---------|
| `get_price(mineral)` | Current price for a mineral type |
| `get_price_history(mineral)` | Array of last 10 prices |
| `get_fuel_price()` | Current fuel price |
| `get_fuel_price_history()` | Array of last 10 fuel prices |
| `record_nickel_sale(amount)` | Record bulk sale for supply/demand model |
| `reset_market()` | Reset all prices to defaults |

Pricing models are detailed in [Part 4](./PART4_ECONOMY.md).

---

### 3. ScreenUtils (`Scripts/screen_utils.gd`)

**Viewport and boundary utilities.** Used by weapons to avoid damaging off-screen targets and by the menu system to manage camera limits.

**Key Functions:**

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

### 4. VoyageManager (`Scripts/voyage_manager.gd`)

**Manages automated drone voyages** that gather standard minerals.

**Key Functions:**

| Function | Purpose |
|----------|---------|
| `start_voyage(tier)` | Begin a voyage with all available voyage drones |
| `get_progress()` | Current progress (0.0 to 1.0) |
| `get_tier_data(tier)` | Get duration, risk, and reward for a tier |

Voyage tiers:

| Tier | Duration | Break Chance | Minerals/Drone |
|------|----------|-------------|----------------|
| SHORT | 30s | 5% | 1-2 |
| MEDIUM | 45s | 20% | 2-4 |
| LONG | 60s | 35% | 4-8 |

---

### 5. ExpeditionManager (`Scripts/expedition_manager.gd`)

**Manages automated drone expeditions** that gather exotic minerals.

**Key Functions:**

| Function | Purpose |
|----------|---------|
| `start_expedition(tier)` | Begin expedition with all expedition drones |
| `get_progress()` | Current progress (0.0 to 1.0) |
| `get_tier_data(tier)` | Get duration, risk, and reward for a tier |

Expedition tiers:

| Tier | Duration | Break Chance | Exotic Minerals/Drone |
|------|----------|-------------|----------------------|
| NEAR_ORBIT | 60s | 10% | 1-2 |
| DEEP_SPACE | 120s | 25% | 2-4 |
| UNCHARTED | 180s | 40% | 4-8 |

---

### 6. AudioManager (`Scripts/audio_manager.gd`)

**Centralized audio playback.** Pools SFX players and provides a registry-based API.

**Key Functions:**

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

## Scene Flow

```
start_menu.tscn  -->  main.tscn  <-->  base.tscn
                          |                |
                          v                v
                     GameOver.tscn    bank.tscn
```

- **start_menu.tscn**: Entry point. Simple start button.
- **main.tscn**: Core gameplay. Player, asteroids, UI panels. This is where mining happens.
- **base.tscn**: Space station. Drone management, voyages, expeditions, drone upgrades.
- **bank.tscn**: Banking interface. Vault deposits, bonds, fuel futures.
- **GameOver.tscn**: Shown when shields reach 0.

Transition between main and base uses a 5-second countdown ("Traveling to base...").

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

*Previous: [Part 1 - Game Overview](./PART1_GAME_OVERVIEW.md)*
*Next: [Part 3 - Weapons System](./PART3_WEAPONS.md)*
