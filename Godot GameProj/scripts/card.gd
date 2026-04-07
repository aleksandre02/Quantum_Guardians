extends Node2D

signal card_clicked

# ── Node references ──────────────────────────────────────────────────────────
@onready var _sprite = $Sprite2D
@onready var _area   = $Area2D

# ── Audio players (created at runtime in _ready) ─────────────────────────────
var _hover_sfx: AudioStreamPlayer
var _click_sfx: AudioStreamPlayer

# ── Hover animation ───────────────────────────────────────────────────────────
var _hover_tween: Tween
const BASE_SCALE  = Vector2(1.0, 1.0)
const HOVER_SCALE = Vector2(1.2, 1.2)
const TWEEN_TIME  = 0.2  # seconds for scale transition

# ═══════════════════════════════════════════════════════════════════ READY ════
func _ready():
	# Connect hover signals in code to guarantee they are always wired
	_area.mouse_entered.connect(_on_area_2d_mouse_entered)
	_area.mouse_exited.connect(_on_area_2d_mouse_exited)

	# Create audio players at runtime to keep the scene file clean
	var hover_player = AudioStreamPlayer.new()
	hover_player.name   = "HoverSFX"
	hover_player.stream = preload("res://assets/sfx/card_hover_effect.mp3")
	add_child(hover_player)

	var click_player = AudioStreamPlayer.new()
	click_player.name   = "ClickSFX"
	click_player.stream = preload("res://assets/sfx/card_click_effect.mp3")
	add_child(click_player)

	_hover_sfx = hover_player
	_click_sfx = click_player

# ══════════════════════════════════════════════════════════ HOVER ════
func _on_area_2d_mouse_entered():
	_scale_to(HOVER_SCALE)
	_hover_sfx.play()

func _on_area_2d_mouse_exited():
	_scale_to(BASE_SCALE)

# Tweens only the Sprite2D scale — leaving Area2D collision shape unchanged
# so the hover detection does not misfire when the visual grows larger.
func _scale_to(target: Vector2):
	if _hover_tween:
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.set_trans(Tween.TRANS_BACK)   # springy overshoot feel
	_hover_tween.set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(_sprite, "scale", target, TWEEN_TIME)

# ══════════════════════════════════════════════════════════ INPUT ════
func _on_area_2d_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed:
		_click_sfx.play()
		emit_signal("card_clicked")
