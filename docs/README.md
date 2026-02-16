# Asteroid Farmer - Complete Reference Guide

> The definitive reference for the Asteroid Farmer project.
> Everything about the game's premise, design, systems, and code — in one place.

---

## Table of Contents

| Part | Title | What It Covers |
|------|-------|---------------|
| [1](./PART1_GAME_OVERVIEW.md) | **Game Overview & Design Philosophy** | Premise, black-and-white aesthetic, sharp-edge design rules, procedural drawing, input controls, physics layers, project structure |
| [2](./PART2_ARCHITECTURE.md) | **Architecture & Autoloads** | Singleton pattern, all 6 autoloads (GameState, Market, ScreenUtils, VoyageManager, ExpeditionManager, AudioManager), signal flow, scene flow |
| [3](./PART3_WEAPONS.md) | **Weapons System** | WeaponBase class hierarchy, WeaponManager, all 5 weapons (Primary Cannon, Laser Beam, Railgun, Rocket Launcher, Mine Layer), damage pipeline |
| [4](./PART4_ECONOMY.md) | **Economy & Market** | 4 pricing models (random walk, supply/demand, sine wave, boom-bust), fuel pricing, banking, bonds, fuel futures, cargo/encumbrance |
| [5](./PART5_UPGRADES.md) | **Upgrade System** | Full upgrade registry, all level tables, infinite upgrade formulas, costs, drone upgrades, spawner difficulty |
| [6](./PART6_ENTITIES.md) | **Entities & World Systems** | Player ship, asteroids, minerals, shield, drones, base scene, voyage/expedition flow, menu toggle, particles |
| [7](./PART7_SCRIPT_REFERENCE.md) | **Script-by-Script Reference** | Every script's purpose and major functions listed |

---

## Quick Facts

| Property | Value |
|----------|-------|
| Engine | Godot 4.5 (GL Compatibility) |
| Language | GDScript |
| Resolution | 1920 x 1080 |
| Scripts | ~45 files, ~6,400 lines |
| Scenes | 26 .tscn files |
| Autoloads | 6 singletons |
| Weapons | 5 |
| Mineral Types | 4 standard + 4 exotic |
| Difficulty Levels | 5 (Easy through Extreme) |

---

## Design Rules (Quick Reference)

1. **Black and white** — Color is used sparingly and only to communicate state
2. **Straight lines, sharp edges** — All corner radii are 0, no rounded elements
3. **Procedural drawing** — Gameplay visuals use `_draw()`, not sprites
4. **DM Mono font** — Monospace everywhere
5. **Signals over polling** — GameState emits, everything else listens
