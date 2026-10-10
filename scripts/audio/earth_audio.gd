class_name EarthAudio
extends Node
## Original ambient bed and a bounded one-shot pool. Audio never drives simulation.

const AMBIENCE: AudioStreamWAV = preload("res://assets/audio/earth.wav")
const COLLECT: AudioStream = preload("res://assets/audio/collect.wav")
const PULSE: AudioStream = preload("res://assets/audio/pulse.wav")
const EVOLVE: AudioStream = preload("res://assets/audio/evolve.wav")
const RETURN: AudioStream = preload("res://assets/audio/return.wav")
const DIG: AudioStream = preload("res://assets/audio/dig.wav")

@export var playback_enabled: bool = true

var enabled: bool = true
var _ambience: AudioStreamPlayer
var _players: Array[AudioStreamPlayer] = []
var _cursor: int = 0
var _dig_count: int = 0
var _audible: bool = false


func _ready() -> void:
	_audible = playback_enabled and DisplayServer.get_name() != "headless"
	_ambience = AudioStreamPlayer.new()
	var loop: AudioStreamWAV = AMBIENCE.duplicate() as AudioStreamWAV
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_begin = 0
	loop.loop_end = loop.data.size() / 2
	_ambience.stream = loop
	_ambience.volume_db = -14.0
	add_child(_ambience)
	for index: int in range(6):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.volume_db = -12.0
		add_child(player)
		_players.append(player)
	if _audible: _ambience.play()


func bind(session: GameSession) -> void:
	session.pickup_collected.connect(func(_item: SoilCell.Item, _position: Vector2i) -> void: play(COLLECT))
	session.upgrades.purchased.connect(func(_skill: SkillDefinition) -> void: play(EVOLVE))
	session.returned_home.connect(func() -> void: play(RETURN))
	session.worm.stepped.connect(func(_position: Vector2i, _cell: SoilCell, _sprint: bool) -> void:
		_dig_count += 1
		if _dig_count % 2 == 0: play(DIG, -12.0)
	)


func _exit_tree() -> void:
	# Release looping playback before the audio server and scene tree shut down.
	if _ambience != null:
		_ambience.stop()
		_ambience.stream = null
	for player: AudioStreamPlayer in _players:
		player.stop()
		player.stream = null


func set_enabled(value: bool) -> void:
	enabled = value
	if _ambience != null: _ambience.volume_db = -14.0 if value else -80.0
	if not value:
		for player: AudioStreamPlayer in _players: player.stop()


func play(stream: AudioStream, offset_db: float = 0.0) -> void:
	if not enabled or not _audible or _players.is_empty(): return
	var player: AudioStreamPlayer = _players[_cursor]
	_cursor = (_cursor + 1) % _players.size()
	player.stop()
	player.stream = stream
	player.volume_db = -12.0 + offset_db
	player.play()
