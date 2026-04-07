extends Node
# card_data.gd
class_name SimpleCards

# 1) Card IDs (just names)
enum CardId {
	ACCESS_HIT,
	QUALITY_HIT,
	EQUITY_HIT,
	BIG_HIT,
	QUICK_HEAL,
	BIG_HEAL,
	RISKY_STRIKE,
	RISKY_HEAL,
	FREE_HIT,
	EMERGENCY_HEAL
}

# 2) What a card does (very simple)
# Returns a Dictionary like { "dmg": 0, "heal": 0, "pressure": 0, "name": "", "desc": "" }
static func get_card(card: CardId) -> Dictionary:
	match card:
		CardId.ACCESS_HIT:
			return {"name":"Access Hit", "desc":"Deal 2 damage.", "dmg":2, "heal":0, "pressure":0}
		CardId.QUALITY_HIT:
			return {"name":"Quality Hit", "desc":"Deal 2 damage.", "dmg":2, "heal":0, "pressure":0}
		CardId.EQUITY_HIT:
			return {"name":"Equity Hit", "desc":"Deal 2 damage.", "dmg":2, "heal":0, "pressure":0}

		CardId.BIG_HIT:
			return {"name":"Big Hit", "desc":"Deal 5 damage.", "dmg":5, "heal":0, "pressure":1}

		CardId.QUICK_HEAL:
			return {"name":"Quick Heal", "desc":"Heal 3 HP.", "dmg":0, "heal":3, "pressure":0}
		CardId.BIG_HEAL:
			return {"name":"Big Heal", "desc":"Heal 6 HP.", "dmg":0, "heal":6, "pressure":1}

		CardId.RISKY_STRIKE:
			return {"name":"Risky Strike", "desc":"Deal 7 damage but gain 2 pressure.", "dmg":7, "heal":0, "pressure":2}
		CardId.RISKY_HEAL:
			return {"name":"Risky Heal", "desc":"Heal 8 HP but gain 2 pressure.", "dmg":0, "heal":8, "pressure":2}

		CardId.FREE_HIT:
			return {"name":"Free Hit", "desc":"Deal 1 damage (no cost).", "dmg":1, "heal":0, "pressure":0}
		CardId.EMERGENCY_HEAL:
			return {"name":"Emergency Heal", "desc":"Heal 4 HP but gain 1 pressure.", "dmg":0, "heal":4, "pressure":1}

	return {"name":"Unknown", "desc":"", "dmg":0, "heal":0, "pressure":0}
