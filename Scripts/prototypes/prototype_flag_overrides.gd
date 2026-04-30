# prototype_flag_overrides.gd
# ─────────────────────────────────────────────────────────────────────────────
# Inspector-editable mirror of the PrototypeFlags autoload. Drop this script
# on a node inside main.tscn so the toggles show up in the editor inspector.
# At runtime, _ready() pushes each value onto the PrototypeFlags singleton
# before main.gd's _ready() calls PrototypeFlags.mount_all(self) — Godot runs
# children's _ready() before the parent's, so the override always wins.
# ─────────────────────────────────────────────────────────────────────────────

extends Node


# ─── Tier 1 — pure additions, no GameState changes ──────────────────────────
@export var NEWS_TICKER          := true
@export var SHIP_DAMAGE_STATES   := true
@export var PARALLAX_STARFIELD   := false
@export var MINERAL_GLYPHS       := false
@export var MARKET_PULSE         := false

# ─── Tier 2 — needs one new public method on GameState/Market ───────────────
@export var SOLAR_FLARE          := false
@export var HEAT_OVERDRIVE       := false
@export var BOSS_TELEGRAPH       := false

# ─── Tier 3 — heavy state changes; leave off until tier 1/2 is shipping ─────
@export var PIRATE_CORSAIRS      := false
@export var MINERAL_FUTURES      := false
@export var REFINERY             := false


const _FLAG_NAMES := [
	"NEWS_TICKER", "SHIP_DAMAGE_STATES", "PARALLAX_STARFIELD",
	"MINERAL_GLYPHS", "MARKET_PULSE",
	"SOLAR_FLARE", "HEAT_OVERDRIVE", "BOSS_TELEGRAPH",
	"PIRATE_CORSAIRS", "MINERAL_FUTURES", "REFINERY",
]


func _ready() -> void:
	var flags := get_node_or_null("/root/PrototypeFlags")
	if flags == null:
		push_warning("[PrototypeFlagOverrides] PrototypeFlags autoload not registered")
		return
	for flag_name: String in _FLAG_NAMES:
		flags.set(flag_name, get(flag_name))
