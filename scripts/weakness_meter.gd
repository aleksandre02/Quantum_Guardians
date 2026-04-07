extends Control

# ── Bar node references ───────────────────────────────────────────────────────
@onready var access_bar        = $AccessBar
@onready var quality_bar       = $QualityBar
@onready var equity_bar        = $EquityBar
@onready var access_range_bar  = $AccessRangeBar   # white upper-bound ghost bar
@onready var quality_range_bar = $QualityRangeBar
@onready var equity_range_bar  = $EquityRangeBar

# Lower-bound bars are created at runtime in _ready() so Godot's editor
# cannot overwrite them when the scene file is re-saved.
var access_lower_bar:  ProgressBar
var quality_lower_bar: ProgressBar
var equity_lower_bar:  ProgressBar

# ── Constants ────────────────────────────────────────────────────────────────
const MAX_VALUE   = 100.0  # value at which a stat is considered maxed (win condition)
const DISPLAY_MAX = 100.0  # bars use this as max_value so the scale is 0–100

# ── Superposition ranges ──────────────────────────────────────────────────────
# Each stat tracks a min/max range (the superposition) and the value at the
# start of the turn (used to restore state on decoherence).
var ranges = {
	"access":  {"min": 0.0, "max": 0.0, "turn_start": 0.0},
	"quality": {"min": 0.0, "max": 0.0, "turn_start": 0.0},
	"equity":  {"min": 0.0, "max": 0.0, "turn_start": 0.0}
}

# ═══════════════════════════════════════════════════════════════════ READY ════
func _ready():
	# Set display maximums on all existing bars
	access_bar.max_value        = DISPLAY_MAX
	quality_bar.max_value       = DISPLAY_MAX
	equity_bar.max_value        = DISPLAY_MAX
	access_range_bar.max_value  = DISPLAY_MAX
	quality_range_bar.max_value = DISPLAY_MAX
	equity_range_bar.max_value  = DISPLAY_MAX

	# Shared dark fill style for the lower-bound bars
	var dark_fill = StyleBoxFlat.new()
	dark_fill.bg_color = Color(0.12, 0.12, 0.12, 0.88)
	dark_fill.corner_radius_top_left     = 5
	dark_fill.corner_radius_top_right    = 5
	dark_fill.corner_radius_bottom_right = 5
	dark_fill.corner_radius_bottom_left  = 5

	# Create lower-bound bars and insert them behind the main bars
	# Z-order (back → front): dark lower bar → white upper bar → coloured main bar
	access_lower_bar  = _make_lower_bar(access_bar,  dark_fill)
	quality_lower_bar = _make_lower_bar(quality_bar, dark_fill)
	equity_lower_bar  = _make_lower_bar(equity_bar,  dark_fill)

	# Push the main bars to the front after the lower bars have been added
	move_child(access_bar,  get_child_count() - 1)
	move_child(quality_bar, get_child_count() - 1)
	move_child(equity_bar,  get_child_count() - 1)

# Creates a dark lower-bound bar at the same position as ref_bar.
func _make_lower_bar(ref_bar: ProgressBar, fill_style: StyleBoxFlat) -> ProgressBar:
	var bar = ProgressBar.new()
	bar.layout_mode   = ref_bar.layout_mode
	bar.offset_left   = ref_bar.offset_left
	bar.offset_top    = ref_bar.offset_top
	bar.offset_right  = ref_bar.offset_right
	bar.offset_bottom = ref_bar.offset_bottom
	bar.max_value     = DISPLAY_MAX
	bar.value         = 0.0
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	bar.add_theme_stylebox_override("fill", fill_style)
	add_child(bar)
	return bar

# ── Bar lookup helpers ────────────────────────────────────────────────────────
func _get_bar(type: String) -> ProgressBar:
	match type:
		"access":  return access_bar
		"quality": return quality_bar
		"equity":  return equity_bar
	return null

func _get_range_bar(type: String) -> ProgressBar:
	match type:
		"access":  return access_range_bar
		"quality": return quality_range_bar
		"equity":  return equity_range_bar
	return null

func _get_lower_bar(type: String) -> ProgressBar:
	match type:
		"access":  return access_lower_bar
		"quality": return quality_lower_bar
		"equity":  return equity_lower_bar
	return null

# ══════════════════════════════════════════════════════════ SETUP ════
# Initialises all bars and ranges with the enemy's starting weakness values.
func setup(access_val: float, quality_val: float, equity_val: float):
	access_bar.value  = access_val
	quality_bar.value = quality_val
	equity_bar.value  = equity_val
	access_range_bar.value  = access_val
	quality_range_bar.value = quality_val
	equity_range_bar.value  = equity_val
	access_lower_bar.value  = access_val
	quality_lower_bar.value = quality_val
	equity_lower_bar.value  = equity_val
	ranges["access"]  = {"min": access_val,  "max": access_val,  "turn_start": access_val}
	ranges["quality"] = {"min": quality_val, "max": quality_val, "turn_start": quality_val}
	ranges["equity"]  = {"min": equity_val,  "max": equity_val,  "turn_start": equity_val}

# ══════════════════════════════════════════════════════ ADD RANGE ════
# Called when a card is played. Widens the superposition range for the stat.
# Only the ghost bars move — the main bar does not change until End Turn.
# The split is asymmetric: low end gains 60%, high end gains 140% of the amount.
func add_range(type: String, amount: float):
	if not type in ranges:
		return
	var r = ranges[type]
	r["min"] = min(r["min"] + amount * 0.6, MAX_VALUE)
	r["max"] = min(r["max"] + amount * 1.4, MAX_VALUE)

	# Animate the upper ghost bar up to the new max
	var range_bar = _get_range_bar(type)
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(range_bar, "value", r["max"], 0.3)

	# Animate the lower ghost bar up to the new min
	var lower_bar = _get_lower_bar(type)
	var tween2 = create_tween()
	tween2.set_ease(Tween.EASE_OUT)
	tween2.set_trans(Tween.TRANS_CUBIC)
	tween2.tween_property(lower_bar, "value", r["min"], 0.3)

# ══════════════════════════════════════════════════ RESOLVE TURN ════
# Called on End Turn. Collapses each stat's superposition range to a
# single random value (wave function collapse). All three bars update.
func resolve_turn() -> Dictionary:
	var results = {}
	for type in ranges:
		var r      = ranges[type]
		var actual = randf_range(r["min"], r["max"])
		actual     = min(actual, MAX_VALUE)
		results[type] = actual

		# Collapse the range to the resolved value
		r["min"]        = actual
		r["max"]        = actual
		r["turn_start"] = actual

		# Animate main bar to the resolved value
		var bar = _get_bar(type)
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(bar, "value", actual, 0.5)

		# Collapse ghost bars to the same resolved value
		var range_bar = _get_range_bar(type)
		var tween2 = create_tween()
		tween2.set_ease(Tween.EASE_IN)
		tween2.set_trans(Tween.TRANS_CUBIC)
		tween2.tween_property(range_bar, "value", actual, 0.5)

		var lower_bar = _get_lower_bar(type)
		var tween3 = create_tween()
		tween3.set_ease(Tween.EASE_IN)
		tween3.set_trans(Tween.TRANS_CUBIC)
		tween3.tween_property(lower_bar, "value", actual, 0.5)
	return results

# ══════════════════════════════════════════════════ DECOHERE ════
# Called when decoherence triggers on a stat.
# Collapses the ghost bars back to the current confirmed value,
# leaving the main bar untouched. Flashes the ghost bars red.
func decohere(type: String):
	var r      = ranges[type]
	var actual = _get_bar(type).value
	r["min"] = actual
	r["max"] = actual

	var range_bar = _get_range_bar(type)
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(range_bar, "value", actual, 0.4)

	var lower_bar = _get_lower_bar(type)
	var tween2 = create_tween()
	tween2.set_ease(Tween.EASE_IN)
	tween2.set_trans(Tween.TRANS_CUBIC)
	tween2.tween_property(lower_bar, "value", actual, 0.4)

	# Flash both ghost bars red to signal the collapse
	_flash_bar(range_bar)
	_flash_bar(lower_bar)

# Briefly tints a bar red then fades it back to white.
func _flash_bar(bar: ProgressBar):
	var tween = create_tween()
	tween.tween_property(bar, "modulate", Color(1.0, 0.2, 0.2, 1.0), 0.08)
	tween.tween_property(bar, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.35)

# ══════════════════════════════════════════════════ WIN CHECK ════
# Returns true when all three stats have a confirmed minimum of MAX_VALUE.
# Checks the range dict (updates instantly) rather than bar.value (lags behind tweens).
func all_maxed() -> bool:
	return (
		ranges["access"]["min"]  >= MAX_VALUE and
		ranges["quality"]["min"] >= MAX_VALUE and
		ranges["equity"]["min"]  >= MAX_VALUE
	)
