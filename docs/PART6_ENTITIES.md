# Asteroid Farmer - Part 6: Entities & World Systems

> Part 6 of 7. See the [Table of Contents](./README.md) for all parts.

---

## Player Ship

**Scene**: `Scenes/player.tscn`
**Script**: `Scripts/player.gd`

The player ship is a Node2D with procedurally drawn triangle visuals. It uses smooth cursor-following movement.

### Movement

- **Input**: WASD or left gamepad stick
- **Aim**: Mouse position or right gamepad stick
- **Follow strength**: `GameState.move_follow_strength` (default 12.0) — higher = snappier
- **Speed**: Affected by `GameState.get_speed_multiplier()` when over-encumbered (min 25% speed)

### Components Attached to Player

| Component | Purpose |
|-----------|---------|
| `WeaponManager` | Manages all weapon instances |
| `ShieldComponent` | Handles damage, regen, game over |
| `RadarComponent` | Manages camera zoom (currently disabled) |
| Shield bar (`shield_bar.gd`) | Visual HP bar that follows the ship |

### Key Functions

| Function | Purpose |
|----------|---------|
| `take_damage(amount)` | Routes to ShieldComponent |
| `popup_mineral(name)` | Spawns floating "+1 Iron" text |
| `popup_cargo_full()` | Spawns "CARGO FULL" warning text |

### Mineral Collection

The player has an `Area2D` pickup zone. When minerals enter this zone, they are collected:
1. Mineral's `kind` is read
2. `GameState.add_mineral(kind)` is called
3. `GameState.add_mat(kind)` sets the current mineral type
4. Floating text spawns showing the mineral name
5. `collect` sound plays via AudioManager
6. Mineral node is freed

---

## Asteroids

**Scene**: `Scenes/asteroid.tscn`
**Script**: `Scripts/asteroid.gd`
**Class name**: `Asteroid`
**Extends**: `RigidBody2D`

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| `radius` | 28.0 | Visual and collision size |
| `hit_points` | 2 | Hits to destroy |
| `split_radius_factor` | 0.5 | Child radius = parent * this |
| `min_split_radius` | 14.0 | Don't split below this |
| `mineral_drop_count` | 1 | Minerals dropped on break |

### Physics

- `gravity_scale = 0` (space)
- `linear_damp = 0` / `angular_damp = 0` (no friction)
- Random angular velocity on spawn (-1.2 to 1.2 rad/s) for visual rotation
- Linear velocity is forced every physics tick to prevent physics engine from zeroing it

### Splitting Behavior

When destroyed (hit_points reaches 0):

1. Sound plays (`explode_big` if splitting, `explode_small` if not)
2. Break particles spawn
3. Minerals drop (1-3, random type)
4. **If `child_radius >= min_split_radius`**: Splits into 2 smaller asteroids
   - Children have `hit_points = 1`
   - Children have `radius = parent.radius * 0.5`
   - Children inherit parent's direction and speed
5. Parent is freed

### Collision with Player

When an asteroid's `body_entered` detects the player:
- Base damage: 20 points
- Scaled by `radius / 28.0` (bigger asteroids = more damage)
- Knockback applied to both asteroid and player
- Asteroid self-destructs after collision

---

## Asteroid Spawner

**Script**: `Scripts/components/asteroid_spawner.gd`
**Class name**: `AsteroidSpawner`
**Extends**: `Node`

A component attached to the main scene that manages asteroid spawning.

### Spawn Logic

1. A Timer fires at `spawn_interval` (varies by difficulty)
2. Each tick spawns `spawn_count` asteroids
3. Each asteroid spawns at a random screen edge, 100px beyond camera view
4. Direction is determined by `trajectory_mode`

### Trajectory Modes

| Mode | Behavior |
|------|----------|
| `RANDOM_ACROSS` | Aims at a random point on the opposite screen edge |
| `TOWARD_PLAYER` | Aims directly at the player's position |
| `TOWARD_CENTER` | Aims at the camera center |
| `MIXED` | 60% random across, 20% toward player, 20% toward center |

The game defaults to `RANDOM_ACROSS`.

### Camera-Aware Spawning

The spawner reads the camera's zoom and position to calculate the visible area. Asteroids spawn just outside this area, meaning:
- When the camera zooms out (menu open), asteroids spawn further away
- Asteroids always enter from off-screen, never pop in

### Key Functions

| Function | Purpose |
|----------|---------|
| `sync_with_game_state()` | Read difficulty from GameState, apply settings |
| `_apply_difficulty_level(level)` | Set interval, count, health, speed for a difficulty |
| `set_difficulty(level)` | Manual difficulty override (testing) |
| `set_spawning_enabled(enabled)` | Pause/resume spawning |
| `spawn_now(count)` | Force spawn (testing) |

---

## Shield Component

**Script**: `Scripts/components/shield_component.gd`
**Class name**: `ShieldComponent`
**Extends**: `Node`

### Shield Mechanics

- Shield starts at max capacity
- Damage reduces shield
- After taking damage, regen pauses for `shield_regen_delay` seconds
- After the delay, shield regenerates at `shield_regen_rate` per second
- When shield reaches 0: **Game Over** (scene changes to `GameOver.tscn`)

### Visual Feedback

- On damage: Player ship flashes red `(1.5, 0.5, 0.5)` for 0.1 seconds
- Shield bar (drawn by `shield_bar.gd`) shows current/max as a white bar above the player

### Upgrade Sync

When upgrades change:
1. Old max shield is stored
2. New values are read from `GameState.upgrades.shield`
3. If max increased, current shield is healed proportionally: `current = new_max * (old_current / old_max)`

---

## Shield Bar

**Script**: `Scripts/shield_bar.gd`

A `Node2D` attached as a child of the player ship. Draws the shield bar using `_draw()`:
- White rectangle showing current health
- Positioned above the player
- Updates every frame based on `GameState.shield_changed` signal

---

## Minerals

**Scene**: `Scenes/mineral.tscn`
**Script**: `Scripts/mineral.gd`

Dropped when asteroids break. Small collectible items that drift in space.

### Properties

| Property | Description |
|----------|-------------|
| `kind` | `MineralType` enum — randomly assigned on drop |

### Behavior

- Spawns at asteroid's death position with small random offset
- Drifts slowly or stays stationary
- Collected when entering player's pickup area
- Triggers floating text and `collect` sound

### Tractor Beam Interaction

When the tractor beam is upgraded, minerals within range are pulled toward the player at the beam's strength. Range and strength scale with `GameState.get_tractor_beam_range()` and `get_tractor_beam_strength()`.

---

## Floating Text

**Scene**: `Scenes/floating_text_2d.tscn`
**Script**: `Scripts/floating_text_2d.gd`

Small text labels that appear at the player's position and float upward before fading.

Used for:
- "+1 Iron", "+1 Nickel", etc. on mineral pickup
- "CARGO FULL" when capacity is reached

---

## Drones (Visual Only)

Drones are drawn procedurally in `base.gd` using inner classes:

### Voyage Drones (`_DroneDrawer`)
- Small white triangle polyline
- Scale: 0.4x
- Bob up and down with sine wave animation
- Positioned in left side of drone area

### Expedition Drones (`_ExpeditionDroneDrawer`)
- Small blue `(0.4, 0.7, 1.0)` triangle polyline
- Same scale and animation
- Positioned in right side of drone area

Drones are purely visual at the base — they disappear when sent on voyages/expeditions and reappear when the mission completes (minus any lost drones).

---

## Base Scene

**Scene**: `Scenes/base.tscn`
**Script**: `Scripts/base.gd`

The space station / home base where the player manages passive systems.

### Visual Elements

- **Docked ship**: Flies in from the left with a tween, then bobs gently
- **Drone formation**: Grid of small triangles showing owned drones
- **Planet sprites**: Background planet images (bitmap — the only non-procedural visuals)

### UI Layout

The base has a right-side menu with stacked panels:

1. **DRONE BAY** panel (white border)
   - Buy Voyage Drone button (75 cr)
   - SEND ON VOYAGE section with 3 tier buttons
   - Progress bar (visible during active voyage)

2. **EXPEDITIONS** panel (blue border)
   - Buy Expedition Drone button (75 cr)
   - 3 expedition tier buttons
   - Progress bar (visible during active expedition)

3. **DRONE UPGRADES** panel (purple border)
   - Exotic mineral inventory display
   - 4 upgrade rows (Drone Armor, Mineral Scanners, Warp Drive, Deep Probes)

### Navigation

- **Back button**: Returns to `main.tscn`
- Credits and vault balance displayed at top-left

---

## Voyage & Expedition Flow

### Starting a Voyage

```
Player presses voyage tier button at base
    └──> VoyageManager.start_voyage(tier)
              ├──> All voyage drones are committed
              ├──> Duration = tier_duration * warp_drive_multiplier
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
              │         Roll break_chance * (1 - armor_reduction)
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

## Menu Toggle System

Pressing **TAB** triggers `_toggle_menus()` in `main.gd`:

### Opening Menus (TAB)

1. Graphs panel slides in from left (bottom 27.78% of screen)
2. Upgrade panel slides in from left (left 27.78%, top to graphs boundary)
3. Voyage progress bar slides in (above graphs panel)
4. Expedition progress bar slides in (above voyage bar)
5. "Go to Base" button slides down from above screen
6. Camera zooms out to 0.75x to show more playing field
7. Camera limits expand to accommodate the wider view

### Closing Menus (TAB again)

Everything reverses — panels slide out, camera zooms back to 1.0x, limits restore.

All animations use `Tween` with `EASE_OUT` / `EASE_IN` and `TRANS_CUBIC` for smooth motion. Duration: 0.5 seconds.

---

## Particle Effects

| Scene | Used By | Description |
|-------|---------|-------------|
| `break_particles.tscn` | Asteroid destruction | Debris effect on asteroid break |
| `rocket_particles.tscn` | Rocket trail | Exhaust trail behind rockets |
| `rocket_explode_particle.tscn` | Rocket/Mine explosion | Blast effect |

All particles use `GPUParticles2D` with `one_shot = true` and self-free on `finished`.

---

*Previous: [Part 5 - Upgrades](./PART5_UPGRADES.md)*
*Next: [Part 7 - Script Reference](./PART7_SCRIPT_REFERENCE.md)*
