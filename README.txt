Asteroid Farmer
--------------

Asteroid Farmer is a minimalist 2D black and white space action game inspired by the classic arcade game Asteroids. The player controls a small white spaceship in an empty black void, shooting and destroying asteroids to collect valuable minerals. These minerals can be sold for credits that can be used to buy upgrades, improving the ship’s performance and weapons over time.

The game focuses on smooth controls, clear visuals, and a satisfying gameplay loop built around mining, upgrading, and surviving in an endless asteroid field.

Core Gameplay

1. The player controls a small ship using the keyboard and mouse or a controller.
   - WASD or the left analog stick moves the ship in any direction.
   - The ship always rotates to face the cursor (or the right stick on a controller).
   - This setup allows twin-stick-style movement and aiming.
2. The ship automatically fires two projectiles in a straight line from its nose at a steady rate.
3. Asteroids drift across space. The player shoots them to break them apart.
4. Destroyed asteroids can drop mineral items (iron, nickel, silica).
5. The player collects minerals by flying into them.
6. Minerals are stored in an inventory and can be sold for credits.
7. Credits are used to purchase ship upgrades, such as faster firing, higher projectile speed, improved movement, or increased cargo capacity.

Asteroid Behavior

Asteroids spawn in a ring around the player at random angles and distances. Each asteroid moves along a straight path that passes roughly through a central region of the game space, but not always through the exact center. This makes movement patterns appear natural and varied.

Large asteroids split into two smaller ones when destroyed. Smaller asteroids are faster and can still drop minerals. All asteroids move with no gravity or drag, coasting endlessly through space after receiving their initial impulse.

Player Movement

The player moves freely in two dimensions. There is no gravity or friction. Movement is based on direct velocity control. The ship accelerates smoothly in the direction of input and can move independently of its facing direction. The ship always points toward the cursor, allowing precise aiming and shooting while drifting in any direction.

Projectiles

The player ship fires two projectiles simultaneously from its nose. Projectiles travel in straight lines and damage asteroids on contact. They are destroyed after impact or after leaving the visible area. The firing rate and projectile speed can be upgraded through the progression system.

Minerals and Inventory

Each destroyed asteroid has a chance to drop one or more minerals. These include iron, nickel, and silica. When collected, the minerals are added to the player’s inventory. The inventory is displayed in a simple menu showing the quantity of each mineral, for example:

Iron: 5
Nickel: 2
Silica: 0

The inventory updates automatically whenever the player collects or sells minerals. The GameState singleton tracks all mineral counts, credits, and upgrade information. It emits a signal whenever mineral quantities change, allowing the UI to update in real time.

Economy and Upgrades

Minerals can be sold from the inventory menu for credits. Credits are used to buy upgrades that enhance the ship. Planned upgrades include:

- Faster firing rate
- Higher projectile speed
- Improved movement speed and handling
- Increased cargo capacity
- Stronger armor or shields

Upgrades create a sense of progression as the player becomes more efficient at mining and combat.

Visual Style

The entire game is rendered in black and white.
- Background: solid black
- Ships, asteroids, and projectiles: white outlines or filled polygons drawn using the _draw() function
- Minerals: small white shapes or dots
The visual style is inspired by vector-display arcade games. It is clean, simple, and high contrast.

User Interface

The Inventory Menu contains text labels showing mineral counts and player credits. It updates automatically through signals. The interface is minimal and designed for clarity.

Future UI plans include buttons for selling minerals, purchasing upgrades, and possibly displaying ship stats.

Technical Overview

- Engine: Godot 4.x
- Core scripts:
  - Main.gd: handles player and asteroid spawning
  - Player.gd: ship movement and shooting logic
  - Projectile.gd: projectile behavior and collisions
  - Asteroid.gd and AsteroidVisuals.gd: asteroid physics and drawing
  - GameState.gd: global data for minerals, credits, and upgrades (autoload singleton)
  - InventoryMenu.gd: updates the mineral labels and UI

All motion uses RigidBody2D nodes with gravity and damping disabled to simulate zero-gravity space physics.

Design Goals

- Keep the gameplay simple and satisfying while allowing depth through upgrades.
- Maintain a clean, minimalist aesthetic with sharp contrast.
- Ensure the code is modular and easy to expand with new mineral types, upgrades, or weapons.
- Capture the mechanical precision and rhythm of classic Asteroids, but with a modern progression loop.

Example Gameplay Summary

The player’s ship glides through space, two bright white lasers firing rhythmically into a cluster of tumbling asteroids. The rocks split apart, spinning slowly as fragments drift away. Small mineral shards appear and are collected automatically. The player opens the inventory to see “Iron: 23” and “Nickel: 8,” sells them for credits, and buys a faster cannon before returning to space for the next run.
