extends Node2D

# ── Card texture preloads ─────────────────────────────────────────────────────
@onready var card_quality_3_res = preload("res://assets/cards/quality_3.png")
@onready var card_equity_3_res  = preload("res://assets/cards/equity_3.png")
@onready var card_access_3_res  = preload("res://assets/cards/access_3.png")

# ── Card and marker node references ──────────────────────────────────────────
@onready var card_node   = $Card
@onready var card_node_2 = $Card2
@onready var card_node_3 = $Card3
@onready var card_node_4 = $Card4

@onready var card_marker_1 = $card_marker_1
@onready var card_marker_2 = $card_marker_2
@onready var card_marker_3 = $card_marker_3
@onready var card_marker_4 = $card_marker_4
@onready var deck_marker   = $Deck_marker

# Convenience arrays for iterating over all cards / markers together
@onready var cards        = [card_node, card_node_2, card_node_3, card_node_4]
@onready var card_markers = [card_marker_1, card_marker_2, card_marker_3, card_marker_4]

# ── Signals ───────────────────────────────────────────────────────────────────
signal card_clicked_with_type(card_type: String)

# ── State ─────────────────────────────────────────────────────────────────────
var card_types    = ["", "", "", ""]  # current type of each slot: "access" / "quality" / "equity"
var textures      = {}                # maps type string → Texture2D
var cards_enabled = true              # false while a card play animation is in flight

# ── Animation timing constants ────────────────────────────────────────────────
const FLY_TO_DECK  = 0.45   # single card flying to the deck
const FLY_TO_HAND  = 0.55   # single card being dealt back to hand
const SHUFFLE_OUT  = 0.40   # full reshuffle: cards collecting into deck
const SHUFFLE_IN   = 0.50   # full reshuffle: cards being dealt from deck
const STAGGER_STEP = 0.10   # delay between each card during a reshuffle

# ── Audio ─────────────────────────────────────────────────────────────────────
var _shuffle_sfx: AudioStreamPlayer

# ═══════════════════════════════════════════════════════════════════ READY ════
func _ready():
	# Populate the texture lookup table
	textures["access"]  = card_access_3_res
	textures["quality"] = card_quality_3_res
	textures["equity"]  = card_equity_3_res

	# Cards 2–4 connect via lambdas; Card 1 connects via the scene signal (_on_card_card_clicked)
	card_node_2.connect("card_clicked", func(): _handle_card_clicked(1))
	card_node_3.connect("card_clicked", func(): _handle_card_clicked(2))
	card_node_4.connect("card_clicked", func(): _handle_card_clicked(3))

	# Shuffle sound player created at runtime to keep the scene file clean
	_shuffle_sfx = AudioStreamPlayer.new()
	_shuffle_sfx.stream = preload("res://assets/sfx/card_shuffle.mp3")
	add_child(_shuffle_sfx)

# ══════════════════════════════════════════════════════ INITIAL DEAL ════
# Called once when the player reaches the combat marker.
# Assigns random types and flies all four cards out from the deck.
func add_cards_from_deck():
	_shuffle_sfx.play()
	var type_pool = ["access", "quality", "equity"]
	for i in range(cards.size()):
		var t = type_pool[randi() % type_pool.size()]
		card_types[i] = t
		cards[i].get_node("Sprite2D").texture = textures[t]
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_QUINT)
		tween.set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(cards[i], "global_position", card_markers[i].global_position, FLY_TO_HAND)

# ══════════════════════════════════════════════════════ CARD CLICKED ════
# Handles a card being played: fly it to the deck, swap its type, fly a new card back.
func _handle_card_clicked(index: int):
	if not cards_enabled:
		return
	emit_signal("card_clicked_with_type", card_types[index])

	var card   = cards[index]
	var marker = card_markers[index]

	# Fly the played card to the deck
	var to_deck := create_tween()
	to_deck.set_trans(Tween.TRANS_QUINT)
	to_deck.set_ease(Tween.EASE_IN)
	to_deck.tween_property(card, "global_position", deck_marker.global_position, FLY_TO_DECK)
	await to_deck.finished

	# Assign a new random type and update its texture
	var type_pool = ["access", "quality", "equity"]
	var new_type  = type_pool[randi() % type_pool.size()]
	card_types[index] = new_type
	card.get_node("Sprite2D").texture = textures[new_type]

	# Fly the refreshed card back to its hand position
	var to_hand := create_tween()
	to_hand.set_trans(Tween.TRANS_QUINT)
	to_hand.set_ease(Tween.EASE_OUT)
	to_hand.tween_property(card, "global_position", marker.global_position, FLY_TO_HAND)

# ══════════════════════════════════════════════════════ END-TURN RESHUFFLE ════
# Collects all cards into the deck with a stagger, then deals a fresh hand.
func reshuffle_all():
	var type_pool = ["access", "quality", "equity"]

	# Stagger the collect animation so cards fly in one after another
	_shuffle_sfx.play()
	for i in range(cards.size()):
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_QUINT)
		tween.set_ease(Tween.EASE_IN)
		tween.tween_interval(i * STAGGER_STEP)
		tween.tween_property(cards[i], "global_position", deck_marker.global_position, SHUFFLE_OUT)

	# Wait until the last card has arrived before dealing the new hand
	var wait = (cards.size() - 1) * STAGGER_STEP + SHUFFLE_OUT + 0.05
	await get_tree().create_timer(wait).timeout

	# Assign new types and deal them out with a stagger
	for i in range(cards.size()):
		var t = type_pool[randi() % type_pool.size()]
		card_types[i] = t
		cards[i].get_node("Sprite2D").texture = textures[t]
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_QUINT)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_interval(i * STAGGER_STEP)
		tween.tween_property(cards[i], "global_position", card_markers[i].global_position, SHUFFLE_IN)

# ══════════════════════════════════════════════════════ GAME END ════
# Collects all cards back to the deck without re-dealing (used on win/game over).
func collect_to_deck():
	_shuffle_sfx.play()
	for i in range(cards.size()):
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_QUINT)
		tween.set_ease(Tween.EASE_IN)
		tween.tween_interval(i * STAGGER_STEP)
		tween.tween_property(cards[i], "global_position", deck_marker.global_position, SHUFFLE_OUT)

# ── Signal receiver for Card 1 (connected via scene editor) ──────────────────
func _on_card_card_clicked():
	_handle_card_clicked(0)
