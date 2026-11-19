extends RefCounted
class_name RedemptionCodes

# Tambahkan atau ubah kode redeem di sini.
# Kode dinormalisasi menjadi huruf kapital dan hanya dapat diklaim sekali per save lokal.
const CODES: Dictionary = {
	"LAMPORWELCOME": {"type": "item", "item_id": "jamu", "quantity": 1, "description": "Jamu Tolak Bala x1"},
	"NDASMU": {"type": "item", "item_id": "jamu", "quantity": 2, "description": "Jamu Tolak Bala x2"},
	"NYAWANGDEEKAROWONGLIYA": {"type": "lives", "quantity": 1, "description": "Nyawa tambahan x1"},
	"LLBOLO": {"type": "lives", "quantity": 2, "description": "Nyawa tambahan x2"},
	"JIWARAGA": {"type": "lives", "quantity": 3, "description": "Nyawa tambahan x3"},
	"ASTRADEVID": {"type": "coins", "quantity": 50000, "description": "Jackpot! kode dari AstraDev"},
	"AMBATUKAM69": {"type": "coins", "quantity": 69, "description": "BASSS!!"},
	"AMSSRBLHGSHARK": {"type": "coins", "quantity": 5000, "description": "Secret kode JMK48 by Reza Auditore"},
	"NIGGA": {"type": "coins", "quantity": 999, "description": "WONG IRENG!!"},
	"REZA": {"type": "coins", "quantity": 6969, "description": "Sttt!!"},
	"BOOL5": {"type": "coins", "quantity": 5555, "description": "BOOL5!"}
}

static func get_reward(raw_code: String) -> Dictionary:
	var normalized: String = raw_code.strip_edges().to_upper()
	if not CODES.has(normalized):
		return {}
	var reward: Dictionary = CODES[normalized]
	return reward.duplicate(true)
