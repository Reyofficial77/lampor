extends RefCounted
class_name RedemptionCodes

# Tambahkan atau ubah kode redeem di sini.
# Kode dinormalisasi menjadi huruf kapital dan hanya dapat diklaim sekali per save lokal.
const CODES: Dictionary = {
	"LAMPORWELCOME": {"type": "item", "item_id": "jamu", "quantity": 1, "description": "Jamu Tolak Bala x1"},
	"TOLAKBALA": {"type": "item", "item_id": "jamu", "quantity": 2, "description": "Jamu Tolak Bala x2"},
	"NYAWA1": {"type": "lives", "quantity": 1, "description": "Nyawa tambahan x1"},
	"NYAWA2": {"type": "lives", "quantity": 2, "description": "Nyawa tambahan x2"},
	"NYAWA3": {"type": "lives", "quantity": 3, "description": "Nyawa tambahan x3"},
	"KOIN50": {"type": "coins", "quantity": 50, "description": "50 Koin Emas"},
	"KOIN100": {"type": "coins", "quantity": 100, "description": "100 Koin Emas"}
}

static func get_reward(raw_code: String) -> Dictionary:
	var normalized: String = raw_code.strip_edges().to_upper()
	if not CODES.has(normalized):
		return {}
	var reward: Dictionary = CODES[normalized]
	return reward.duplicate(true)
