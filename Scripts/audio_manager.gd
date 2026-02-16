## Autoloaded audio manager
## Handles SFX and music playback through pooled AudioStreamPlayer nodes.
##
## Usage:
##   AudioManager.play_sfx("gun_1")
##   AudioManager.play_sfx("gun_1", -12.0)          # custom volume (dB)
##   AudioManager.play_sfx("gun_1", -12.0, 0.95)    # custom pitch
##   AudioManager.play_music("theme")
##
## To add a new sound, put the file in Assets/Audio/SFX/ (or Music/)
## and register it in _SOUND_REGISTRY below.
extends Node

# ── Sound Registry ──────────────────────────────────────────────────────────
# Maps a short key to { path, default_volume_db, bus }.
# Add new entries here to expand; no other code changes needed.

const _SOUND_REGISTRY := {
	"gun_1": {
		"path": "res://Assets/gun-1.wav",
		"volume_db": -14.0,
		"bus": "Primary Cannon",
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

# Global volume offsets (dB) — persist these if you add a settings menu
var sfx_volume_offset: float = 0.0
var music_volume_offset: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep audio alive during pause
	_build_sfx_pool()
	_build_music_player()
	_preload_registered_sounds()

# ── Public API ──────────────────────────────────────────────────────────────

## Play a registered sound effect by key.
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
