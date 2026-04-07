extends Node2D

# ── Scene node references ────────────────────────────────────────────────────
@onready var player_marker_node    = $player_marker
@onready var enemy_marker_node     = $enemy_marker
@onready var player_node           = $player
@onready var enemy_node            = $Enemy
@onready var card_manager          = $card_manager
@onready var weakness_meter        = $weakness_meter

# Stat labels (A = Access, Q = Quality, E = Equity)
@onready var pressure_bar_label    = $Labels/Pressure_bar_label
@onready var decoherence_bar_label = $Labels/Decoherence_bar_label
@onready var game_win_label        = $Labels/Game_win_label
@onready var E_label               = $Labels/E_label
@onready var Q_label               = $Labels/Q_label
@onready var A_label               = $Labels/A_label

# UI nodes (live inside the "ui" CanvasLayer)
@onready var pressure_bar:      ProgressBar = $player/Healthbar
@onready var decoherence_bar:   ProgressBar = $ui/decoherence_bar
@onready var deco_ghost_bar:    ProgressBar = $ui/decoherence_bar/deco_ghost_bar
@onready var decoherence_label: Label       = $ui/decoherence_label
@onready var game_over_label:   Label       = $ui/game_over_label
@onready var end_turn_button:   Button      = $ui/end_turn_button

# ── Animation state flags ────────────────────────────────────────────────────
# These prevent _process() from snapping characters back to idle mid-animation.
var card_added         = true   # false once the initial hand has been dealt
var enemy_hit_flag     = false  # enemy is playing its hit animation
var enemy_die_flag     = false  # enemy has died — stop all enemy logic
var enemy_attack_flag  = false  # enemy is playing its attack animation
var player_attack_flag = false  # player is playing its attack animation
var player_hit_flag    = false  # player is playing its hit animation
var player_die_flag    = false  # player has died — stop all player logic
var player_win_flag    = false  # player has won — stop all player logic

# Nodes to hide when combat ends (populated in _ready)
var node_array_make_invisible = []

# ── Enemy weakness starting values ──────────────────────────────────────────
const ENEMY_ACCESS_START  = 20.0
const ENEMY_QUALITY_START = 40.0
const ENEMY_EQUITY_START  = 20.0
const WEAKNESS_PER_CARD   = 8.0  # base range expansion per card played

# ── Combat state ─────────────────────────────────────────────────────────────
var in_combat = false

# ── Superposition / diminishing returns ──────────────────────────────────────
# Tracks how many times each card type has been used this turn.
# Each repeat gives less range expansion: 100% → 80% → 60% → 20% floor.
var cards_used_this_turn = {"access": 0, "quality": 0, "equity": 0}

# ── Decoherence system ────────────────────────────────────────────────────────
# Chance of decoherence = numerator / 526. Doubles with each safe card played.
# Resets to 1 after a trigger. Five triggers = game over.
var decoherence_numerator = 1
var decoherence_count     = 0
const DECOHERENCE_MAX     = 5

# ── Pressure system ───────────────────────────────────────────────────────────
# Pressure rises each End Turn by an escalating amount. Reaching 100 = game over.
var pressure        = 0.0
const PRESSURE_MAX  = 100.0
var pressure_gains  = [5, 8, 12, 17, 23, 30, 38, 47]  # gain per turn (capped at last index)
var turn_end_count  = 0

# ── Tween references (kept to allow killing mid-animation) ───────────────────
var deco_tween:  Tween
var shake_tween: Tween

# ── Audio players (created at runtime in _ready) ─────────────────────────────
var _attack_sfx:   AudioStreamPlayer
var _hit_sfx:      AudioStreamPlayer
var _deco_sfx:     AudioStreamPlayer
var _gameover_sfx: AudioStreamPlayer
var _victory_sfx:  AudioStreamPlayer
var _bg_music:     AudioStreamPlayer

# ═══════════════════════════════════════════════════════════════════ READY ════
func _ready():
	# Build the list of nodes to hide before combat starts (and after it ends)
	node_array_make_invisible = [
		pressure_bar_label, decoherence_bar_label,
		weakness_meter, card_manager,
		E_label, Q_label, A_label,
		pressure_bar, decoherence_bar, decoherence_label, end_turn_button
	]
	for x in node_array_make_invisible:
		x.visible = false

	# Create all audio players at runtime to keep scene files clean
	_attack_sfx = AudioStreamPlayer.new()
	_attack_sfx.stream = preload("res://assets/sfx/attack_sound.mp3")
	add_child(_attack_sfx)

	_hit_sfx = AudioStreamPlayer.new()
	_hit_sfx.stream = preload("res://assets/sfx/hit_sound.mp3")
	add_child(_hit_sfx)

	_deco_sfx = AudioStreamPlayer.new()
	_deco_sfx.stream = preload("res://assets/sfx/decoherence_sound_effect.mp3")
	add_child(_deco_sfx)

	_gameover_sfx = AudioStreamPlayer.new()
	_gameover_sfx.stream = preload("res://assets/sfx/game_over_sound.mp3")
	add_child(_gameover_sfx)

	_victory_sfx = AudioStreamPlayer.new()
	_victory_sfx.stream = preload("res://assets/sfx/victory_sound.mp3")
	add_child(_victory_sfx)

	# Background music loops continuously at reduced volume
	_bg_music = AudioStreamPlayer.new()
	var bg_stream = preload("res://assets/sfx/bg_music.mp3")
	bg_stream.loop = true
	_bg_music.stream = bg_stream
	_bg_music.volume_db = -12.0
	add_child(_bg_music)
	_bg_music.play()

# ══════════════════════════════════════════════════════════════ MAIN LOOP ════
func _process(_delta):
	player_battle_ready()
	enemy_battle_ready()

	# Once the player reaches the marker position, trigger combat
	if player_node.global_position.x >= player_marker_node.global_position.x and card_added:
		card_added = false
		card_manager.add_cards_from_deck()
		for x in node_array_make_invisible:
			x.visible = true
		weakness_meter.setup(ENEMY_ACCESS_START, ENEMY_QUALITY_START, ENEMY_EQUITY_START)
		in_combat = true
		pressure_bar.init_pressure()
		_refresh_pressure_preview()
		_refresh_deco_preview()

# Moves the enemy toward its marker and plays the correct animation each frame.
func enemy_battle_ready():
	if enemy_die_flag:
		return
	if enemy_node.global_position.x > enemy_marker_node.global_position.x:
		enemy_node.move(-50)
		enemy_node.update_animation(0)  # walk
	elif not enemy_hit_flag and not enemy_attack_flag:
		enemy_node.move(0)
		enemy_node.update_animation(5)  # idle

# Moves the player toward its marker and plays the correct animation each frame.
func player_battle_ready():
	if player_die_flag:
		return
	if player_win_flag:
		return
	if player_node.global_position.x < player_marker_node.global_position.x:
		player_node.move(100)
		player_node.update_animation(0)  # walk
	elif not player_attack_flag and not player_hit_flag:
		player_node.move(0)
		player_node.update_animation(5)  # idle

# ══════════════════════════════════════════════════════════ CARD PLAYED ════
func _on_card_manager_card_clicked_with_type(card_type: String):
	if not in_combat:
		return
	card_manager.cards_enabled = false

	# Apply diminishing returns: same card type played repeatedly this turn
	# gives less range expansion — 100%, 80%, 60%, floor at 20%.
	var use_count  = cards_used_this_turn[card_type]
	var multiplier = max(0.2, 1.0 - use_count * 0.2)
	var amount     = WEAKNESS_PER_CARD * multiplier
	cards_used_this_turn[card_type] += 1

	# Widen the superposition range for this stat
	weakness_meter.add_range(card_type, amount)

	# Roll for decoherence — bar reset and shake fire on the same frame
	var chance       = float(decoherence_numerator) / 526.0
	var deco_triggered = randf() < chance
	var deco_chosen    = ""

	if deco_triggered:
		# Decoherence: reset bar, play sound, shake screen simultaneously
		deco_chosen = _trigger_decoherence()
		_deco_sfx.play()
		_screen_shake()
	else:
		# Safe card: double the decoherence numerator for next time
		decoherence_numerator *= 2
		decoherence_bar.value  = decoherence_numerator
		_refresh_deco_preview()

	if deco_triggered:
		# Wait for the screen shake to finish before playing retaliation
		await get_tree().create_timer(0.45).timeout

		# Enemy attacks and player gets hit simultaneously
		enemy_attack_flag = true
		enemy_node.update_animation(1)   # enemy attack
		_hit_sfx.play()
		player_hit_flag = true
		player_node.update_animation(2)  # player hit
		await get_tree().create_timer(0.5).timeout
		enemy_attack_flag = false
		player_hit_flag   = false

		# Show which stat was collapsed (only if game is still running)
		if in_combat and deco_chosen != "":
			decoherence_label.text     = "DECOHERENCE! %d/%d  %s collapsed!" % [decoherence_count, DECOHERENCE_MAX, deco_chosen.to_upper()]
			decoherence_label.modulate = Color(1, 1, 1, 1)
			if deco_tween:
				deco_tween.kill()
			deco_tween = create_tween()
			deco_tween.tween_interval(2.0)
			deco_tween.tween_property(decoherence_label, "modulate", Color(1, 1, 1, 0), 0.5)
	else:
		# Normal card play: player attacks then enemy reacts
		_attack_sfx.play()
		player_node.update_animation(1)  # player attack
		player_attack_flag = true
		await get_tree().create_timer(0.6).timeout
		player_attack_flag = false

		# Guard: abort if End Turn was pressed while the animation was playing
		if not in_combat:
			return

		_hit_sfx.play()
		enemy_node.update_animation(2)  # enemy hit
		enemy_hit_flag = true
		await get_tree().create_timer(0.2).timeout
		enemy_hit_flag = false

	card_manager.cards_enabled = true

# ══════════════════════════════════════════════════════════ DECOHERENCE ════
# Resets the decoherence bar, collapses a random stat's range,
# increments the decoherence counter, and returns the affected stat name.
func _trigger_decoherence() -> String:
	decoherence_numerator = 1
	decoherence_bar.value = 0
	_refresh_deco_preview()
	decoherence_count += 1

	# Pick a random stat to collapse
	var types  = ["access", "quality", "equity"]
	var chosen = types[randi() % 3]
	weakness_meter.decohere(chosen)

	# Five decoherence events = system fully destabilised, game over
	if decoherence_count >= DECOHERENCE_MAX:
		_game_over("DECOHERENCE LIMIT — SYSTEM COLLAPSED")
		return ""

	return chosen

# ═══════════════════════════════════════════════════════════ END TURN ════
func _on_end_turn_pressed():
	if not in_combat:
		return

	# Collapse all superposition ranges to their resolved values
	weakness_meter.resolve_turn()
	_refresh_stat_labels()

	# Check win condition immediately after collapse
	if weakness_meter.all_maxed():
		_win()
		return

	# Apply this turn's pressure increase
	var gain = pressure_gains[min(turn_end_count, pressure_gains.size() - 1)]
	pressure       += gain
	turn_end_count += 1

	# Animate the pressure bar to its new value
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(pressure_bar, "value", pressure, 0.5)

	# Check lose condition after pressure is applied
	if pressure >= PRESSURE_MAX:
		_game_over("PRESSURE MAXED — GAME OVER")
		return

	_refresh_pressure_preview()

	# Reset per-turn tracking so next turn starts fresh
	cards_used_this_turn  = {"access": 0, "quality": 0, "equity": 0}
	decoherence_numerator = 1
	decoherence_bar.value = 0
	_refresh_deco_preview()

	card_manager.reshuffle_all()

# ══════════════════════════════════════════════════════════ WIN / LOSE ════
func _win():
	_victory_sfx.play()
	in_combat               = false
	end_turn_button.visible = false

	# Clear all animation flags so nothing overrides the win/die animations
	enemy_hit_flag     = false
	enemy_attack_flag  = false
	player_hit_flag    = false
	player_attack_flag = false

	player_node.update_animation(4)  # player win
	player_win_flag = true
	enemy_node.update_animation(3)   # enemy die
	enemy_die_flag  = true

	card_manager.collect_to_deck()
	await get_tree().create_timer(1).timeout
	player_node.health_bar_node.visible = false
	for x in node_array_make_invisible:
		x.visible = false
	game_win_label.visible = true

func _game_over(msg: String):
	_gameover_sfx.play()
	in_combat                 = false
	end_turn_button.visible   = false
	game_over_label.text      = msg
	game_over_label.visible   = true
	enemy_attack_flag         = true
	enemy_node.update_animation(1)   # enemy attack (retaliates on game over)
	player_node.update_animation(3)  # player die
	player_die_flag = true
	card_manager.collect_to_deck()
	await get_tree().create_timer(1).timeout
	for x in node_array_make_invisible:
		x.visible = false

# ══════════════════════════════════════════════════════ SCREEN SHAKE ════
# Shakes the camera by tweening its offset through random small offsets,
# then snaps it back to centre. Kills any previous shake first to prevent drift.
func _screen_shake(strength: float = 3.0, duration: float = 0.45):
	var camera      = player_node.get_node("Camera2D")
	var base_offset = Vector2.ZERO
	if shake_tween:
		shake_tween.kill()
		camera.offset = base_offset
	shake_tween = create_tween()
	var steps = int(duration / 0.05)
	for i in range(steps):
		var rand_offset = base_offset + Vector2(randf_range(-strength, strength), randf_range(-strength, strength))
		shake_tween.tween_property(camera, "offset", rand_offset, 0.05)
	shake_tween.tween_property(camera, "offset", base_offset, 0.08)

# ══════════════════════════════════════════════════════ UI HELPERS ════
# Updates A/Q/E label colours — yellow when that stat is fully maxed, else original colour.
# Only called after End Turn so the result is hidden during card play.
func _refresh_stat_labels():
	var yellow = Color(1, 1, 0, 1)
	A_label.add_theme_color_override("font_color", yellow if weakness_meter.ranges["access"]["min"]  >= weakness_meter.MAX_VALUE else Color(0, 0, 1, 1))
	Q_label.add_theme_color_override("font_color", yellow if weakness_meter.ranges["quality"]["min"] >= weakness_meter.MAX_VALUE else Color(0, 1, 0, 1))
	E_label.add_theme_color_override("font_color", yellow if weakness_meter.ranges["equity"]["min"]  >= weakness_meter.MAX_VALUE else Color(1, 0, 0, 1))

# Updates the ghost bar on the decoherence bar to show what the next doubling will be.
func _refresh_deco_preview():
	deco_ghost_bar.value = min(decoherence_numerator * 2, 526.0)

# Updates the ghost bar on the pressure bar to show next turn's pressure cost.
func _refresh_pressure_preview():
	var next_gain = pressure_gains[min(turn_end_count, pressure_gains.size() - 1)]
	pressure_bar.set_preview(pressure + next_gain)
