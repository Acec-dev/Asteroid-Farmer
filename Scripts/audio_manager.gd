## Autoloaded audio manager
## Handles SFX and music playback through pooled AudioStreamPlayer nodes.
##
## Usage:
##   AudioManager.play_sfx("gun_1")
##   AudioManager.play_sfx("gun_1", -12.0)          # custom volume (dB)
##   AudioManager.play_sfx("gun_1", -12.0, 0.95)    # custom pitch
##   AudioManager.play_sfx_queued("collect")         # queues instead of overlapping
##   AudioManager.play_music("theme")
##
## To add a new sound, put the file in Assets/ and register it in
## _SOUND_REGISTRY below.
extends Node

# ── Sound Registry ──────────────────────────────────────────────────────────
# Maps a short key to { path, default_volume_db }.
# Add new entries here to expand; no other code changes needed.

const _SOUND_REGISTRY := {
	"gun_1": {
		"path": "res://Assets/gun-1.wav",
		"volume_db": -14.0,
		"bus": "Primary Cannon",
	},
	"explode_rocket": {
		"path": "res://Assets/explode-7.wav",
		"volume_db": -10.0,
	},
	"explode_big": {
		"path": "res://Assets/explode-5.wav",
		"volume_db": -10.0,
	},
	"explode_small": {
		"path": "res://Assets/explode-2.wav",
		"volume_db": -10.0,
	},
	"hit_asteroid": {
		"path": "res://Assets/hit-7.wav",
		"volume_db": -10.0,
	},
	"collect": {
		"path": "res://Assets/collect-5.wav",
		"volume_db": -12.0,
	},
	"mine_explode": {
		"path": "res://Assets/explode-5.wav",
		"volume_db": -18.0,
	},
}

# ── Configuration ───────────────────────────────────────────────────────────
const SFX_POOL_SIZE := 8       # simultaneous SFX voices
const MUSIC_CROSSFADE := 0.4   # seconds

# ── Internal state ──────────────────────────────────────────────────────────
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_index: int = 0
var _music_player: AudioStreamPlayer
var _cache: Dictionary = {}  # path -> AudioStream

# Sequential queue — one dedicated player, sounds wait their turn
var _seq_player: AudioStreamPlayer
var _seq_queue: Array[Dictionary] = []  # { stream, volume_db, pitch_scale }

# Global volume offsets (dB) — persist these if you add a settings menu
var sfx_volume_offset: float = 0.0
var music_volume_offset: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep audio alive during pause
	_build_sfx_pool()
	_build_music_player()
	_build_seq_player()
	_preload_registered_sounds()

# ── Public API ──────────────────────────────────────────────────────────────

## Play a registered sound effect by key (overlapping / polyphonic).
## volume_db and pitch_scale override the registry defaults when provided.
func play_sfx(key: String, volume_db: float = NAN, pitch_scale: float = 1.0) -> void:
	if not _SOUND_REGISTRY.has(key):
		push_warning("AudioManager: unknown sfx key '%s'" % key)
		return

	var entry: Dictionary = _SOUND_REGISTRY[key]
	var stream := _get_stream(entry.path)
	if stream == null:
		return

	var player := _next_sfx_player()
	player.stream = stream
	player.bus = entry.get("bus", "Master")
	player.volume_db = volume_db if not is_nan(volume_db) else entry.get("volume_db", 0.0)
	player.volume_db += sfx_volume_offset
	player.pitch_scale = pitch_scale
	player.play()

## Play a sound sequentially — if something is already playing on the
## sequential channel, this sound waits in line instead of overlapping.
## Great for rapid pickup sounds that should be heard one after another.
func play_sfx_queued(key: String, volume_db: float = NAN, pitch_scale: float = 1.0) -> void:
	if not _SOUND_REGISTRY.has(key):
		push_warning("AudioManager: unknown sfx key '%s'" % key)
		return

	var entry: Dictionary = _SOUND_REGISTRY[key]
	var stream := _get_stream(entry.path)
	if stream == null:
		return

	var vol: float = volume_db if not is_nan(volume_db) else entry.get("volume_db", 0.0)
	vol += sfx_volume_offset

	if not _seq_player.playing:
		_seq_player.stream = stream
		_seq_player.volume_db = vol
		_seq_player.pitch_scale = pitch_scale
		_seq_player.play()
	else:
		_seq_queue.append({ "stream": stream, "volume_db": vol, "pitch_scale": pitch_scale })

## Play a registered music track by key (loops automatically for .ogg).
func play_music(key: String, volume_db: float = NAN) -> void:
	if not _SOUND_REGISTRY.has(key):
		push_warning("AudioManager: unknown music key '%s'" % key)
		return

	var entry: Dictionary = _SOUND_REGISTRY[key]
	var stream := _get_stream(entry.path)
	if stream == null:
		return

	_music_player.stream = stream
	_music_player.volume_db = volume_db if not is_nan(volume_db) else entry.get("volume_db", 0.0)
	_music_player.volume_db += music_volume_offset
	_music_player.play()

## Stop whatever music is currently playing.
func stop_music() -> void:
	_music_player.stop()

# ── Internals ───────────────────────────────────────────────────────────────

func _build_sfx_pool() -> void:
	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_sfx_pool.append(p)

func _build_music_player() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Master"
	add_child(_music_player)

func _build_seq_player() -> void:
	_seq_player = AudioStreamPlayer.new()
	_seq_player.bus = "Master"
	_seq_player.finished.connect(_on_seq_finished)
	add_child(_seq_player)

func _on_seq_finished() -> void:
	if _seq_queue.is_empty():
		return
	var next: Dictionary = _seq_queue.pop_front()
	_seq_player.stream = next.stream
	_seq_player.volume_db = next.volume_db
	_seq_player.pitch_scale = next.pitch_scale
	_seq_player.play()

func _next_sfx_player() -> AudioStreamPlayer:
	var player := _sfx_pool[_sfx_index]
	_sfx_index = (_sfx_index + 1) % _sfx_pool.size()
	return player

func _get_stream(path: String) -> AudioStream:
	if _cache.has(path):
		return _cache[path]

	if not ResourceLoader.exists(path):
		push_warning("AudioManager: file not found '%s'" % path)
		return null

	var stream = load(path) as AudioStream
	if stream:
		_cache[path] = stream
	return stream

func _preload_registered_sounds() -> void:
	for key in _SOUND_REGISTRY:
		var entry: Dictionary = _SOUND_REGISTRY[key]
		_get_stream(entry.path)
