# prototype_base.gd
# ─────────────────────────────────────────────────────────────────────────────
# Abstract base class for all Asteroid Farmer prototypes.
#
# What it gives subclasses:
#   • A flag-driven kill switch. If the matching PrototypeFlags constant is
#     false, the node frees itself in _ready() and its setup never runs.
#   • Signal-connection bookkeeping. Use _connect_signal() instead of
#     source.connect() and they auto-disconnect in _exit_tree().
#
# Subclass contract:
#   • Override _flag_name() to return the matching PrototypeFlags constant.
#   • Override _setup_prototype() instead of _ready().
# ─────────────────────────────────────────────────────────────────────────────

class_name PrototypeBase
extends Node

# Each entry: [source: Object, signal_name: String, callable: Callable]
var _registered_connections: Array = []


func _ready() -> void:
	if not _is_enabled():
		queue_free()
		return
	_setup_prototype()


# Override to point at your prototype's flag.
# e.g. return "NEWS_TICKER" -> reads PrototypeFlags.NEWS_TICKER.
# Returning "" (default) means "always on", which you should only do for
# helper subclasses that aren't gated themselves.
func _flag_name() -> String:
	return ""


func _is_enabled() -> bool:
	var flag := _flag_name()
	if flag.is_empty():
		return true
	var flags := get_node_or_null("/root/PrototypeFlags")
	if flags == null:
		push_warning("[%s] PrototypeFlags autoload not registered" % name)
		return false
	# .get() on a Node returns null if the property doesn't exist; treat
	# missing flags as "off" rather than crashing.
	var value: Variant = flags.get(flag)
	return value == true


# Override with your prototype's setup logic.
# Runs only after the flag check passes.
func _setup_prototype() -> void:
	pass


# Connect a signal and auto-disconnect on teardown.
# Returns true on success, false if the source/signal couldn't be found.
func _connect_signal(source: Object, signal_name: String, callable: Callable) -> bool:
	if source == null:
		push_warning("[%s] _connect_signal got null source for '%s'" % [name, signal_name])
		return false
	if not source.has_signal(signal_name):
		push_warning("[%s] source has no signal '%s'" % [name, signal_name])
		return false
	var err := source.connect(signal_name, callable)
	if err != OK:
		push_warning("[%s] connect '%s' failed (err=%d)" % [name, signal_name, err])
		return false
	_registered_connections.append([source, signal_name, callable])
	return true


func _exit_tree() -> void:
	for entry in _registered_connections:
		var source: Object = entry[0]
		var signal_name: String = entry[1]
		var callable: Callable = entry[2]
		if is_instance_valid(source) and source.is_connected(signal_name, callable):
			source.disconnect(signal_name, callable)
	_registered_connections.clear()
