# prototype_flags.gd
# ─────────────────────────────────────────────────────────────────────────────
# Single switchboard for all in-development Asteroid Farmer prototypes.
# Register as an autoload named "PrototypeFlags" in project.godot.
#
# Lifecycle:
#   1. Flip a flag below (or override via the PrototypeFlagsOverrides node in
#      main.tscn) to enable/disable a prototype globally.
#   2. From main.gd's _ready(), call:   PrototypeFlags.mount_all(self)
#   3. mount_all() instantiates every enabled prototype and parents it under
#      the main scene. Disabled prototypes never load.
#
# To add a new prototype:
#   - Add a flag var here.
#   - Mirror it as an @export bool in prototype_flag_overrides.gd so it's
#     toggleable from the inspector.
#   - Add a matching entry in mount_all() below pointing at its script.
#   - Drop the prototype's folder under Scripts/prototypes/.
# ─────────────────────────────────────────────────────────────────────────────

extends Node


# ─── Tier 1 — pure additions, no GameState changes ──────────────────────────
var NEWS_TICKER          := true
var SHIP_DAMAGE_STATES   := true
var PARALLAX_STARFIELD   := false
var MINERAL_GLYPHS       := false
var MARKET_PULSE         := false

# ─── Tier 2 — needs one new public method on GameState/Market ───────────────
var SOLAR_FLARE          := false
var HEAT_OVERDRIVE       := false
var BOSS_TELEGRAPH       := false

# ─── Tier 3 — heavy state changes; leave off until tier 1/2 is shipping ─────
var PIRATE_CORSAIRS      := false
var MINERAL_FUTURES      := false
var REFINERY             := false


# ─── Mount API ──────────────────────────────────────────────────────────────
# Call once from main.gd's _ready():
#     PrototypeFlags.mount_all(self)

func mount_all(main_root: Node) -> void:
	if main_root == null:
		push_warning("[PrototypeFlags] mount_all called with null main_root")
		return

	if NEWS_TICKER:
		_try_mount(
			"res://Scripts/prototypes/news_ticker/news_ticker.gd",
			main_root, "NewsTicker")

	if SHIP_DAMAGE_STATES:
		_try_mount(
			"res://Scripts/prototypes/ship_damage_states/ship_damage_states.gd",
			main_root, "ShipDamageStates")

	# Add additional prototypes here as they come online.


# Quietly skip a prototype if its script file is missing — useful when
# pulling a partial branch or sharing a single prototype with someone else.
func _try_mount(script_path: String, parent: Node, label: String) -> void:
	if not ResourceLoader.exists(script_path):
		push_warning("[PrototypeFlags] %s flag is on but missing script: %s"
			% [label, script_path])
		return
	var script: GDScript = load(script_path)
	if script == null:
		push_warning("[PrototypeFlags] failed to load %s" % script_path)
		return
	var node: Node = script.new()
	if node == null:
		push_warning("[PrototypeFlags] failed to instance %s" % script_path)
		return
	node.name = label
	parent.add_child(node)
