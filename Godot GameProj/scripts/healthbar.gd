extends ProgressBar

# ── Node references ──────────────────────────────────────────────────────────
@onready var damage_bar = $Damage_bar  # ghost bar showing upcoming pressure increase

# ══════════════════════════════════════════════════════ SETUP ════
# Initialises both bars to zero at the start of combat.
func init_pressure():
	max_value           = 100.0
	value               = 0.0
	damage_bar.max_value = 100.0
	damage_bar.value    = 0.0

# ══════════════════════════════════════════════════════ PREVIEW ════
# Sets the ghost bar to show what the pressure will be after the next End Turn.
func set_preview(preview_val: float):
	damage_bar.value = min(preview_val, max_value)
