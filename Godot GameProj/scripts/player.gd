extends CharacterBody2D

# ── Constants ────────────────────────────────────────────────────────────────
const GRAVITY     = 300
const MAX_FALL    = 500  # terminal velocity to prevent infinite acceleration

# ── Node references ──────────────────────────────────────────────────────────
@onready var animated_sprite_node = $AnimatedSprite2D
@onready var health_bar_node      = $Healthbar

# ═══════════════════════════════════════════════════════════════════ READY ════
func _ready():
	pass

# ══════════════════════════════════════════════════════════ PHYSICS LOOP ════
func _physics_process(delta):
	move_and_slide()
	# Apply gravity when airborne, capped at terminal velocity
	if not is_on_floor():
		velocity.y += GRAVITY * delta
		if velocity.y > MAX_FALL:
			velocity.y = MAX_FALL

# ══════════════════════════════════════════════════════════ PUBLIC API ════
# Sets the player's horizontal velocity (called by game.gd each frame).
func move(speed):
	velocity.x = speed

# Plays the animation matching the given flag:
#   0 = walk  |  1 = attack  |  2 = hit  |  3 = die  |  4 = win  |  else = idle
func update_animation(flag):
	if flag == 0:
		animated_sprite_node.play("walk")
	elif flag == 1:
		animated_sprite_node.play("attack")
	elif flag == 2:
		animated_sprite_node.play("hit")
	elif flag == 3:
		animated_sprite_node.play("die")
	elif flag == 4:
		animated_sprite_node.play("win_anim")
	else:
		animated_sprite_node.play("idle")
