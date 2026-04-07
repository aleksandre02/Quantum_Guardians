extends CharacterBody2D

# ── Constants ────────────────────────────────────────────────────────────────
const GRAVITY  = 200
const MAX_FALL = 500  # terminal velocity

# ── Node references ──────────────────────────────────────────────────────────
@onready var animated_sprite_node = $AnimatedSprite2D

# ═══════════════════════════════════════════════════════════════════ READY ════
func _ready():
	# Flip the sprite so the enemy faces left (toward the player)
	animated_sprite_node.flip_h = true

# ══════════════════════════════════════════════════════════ PHYSICS LOOP ════
func _physics_process(delta):
	move_and_slide()
	# Apply gravity when airborne, capped at terminal velocity
	if not is_on_floor():
		velocity.y += GRAVITY * delta
		if velocity.y > MAX_FALL:
			velocity.y = MAX_FALL

# ══════════════════════════════════════════════════════════ PUBLIC API ════
# Sets the enemy's horizontal velocity (called by game.gd each frame).
func move(speed):
	velocity.x = speed

# Plays the animation matching the given flag:
#   0 = walk  |  1 = attack  |  2 = hit  |  3 = die  |  else = idle
func update_animation(flag):
	if flag == 0:
		animated_sprite_node.play("enemy_1_walk")
	elif flag == 1:
		animated_sprite_node.play("enemy_1_attack")
	elif flag == 2:
		animated_sprite_node.play("enemy_1_hit")
	elif flag == 3:
		animated_sprite_node.play("enemy_1_die")
	else:
		animated_sprite_node.play("enemy_1_idle")
