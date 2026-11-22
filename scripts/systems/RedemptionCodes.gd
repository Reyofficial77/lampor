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
	"BOOL5": {"type": "coins", "quantity": 5555, "description": "BOOL5!"},
	"LORDREYID": {"type": "coins", "quantity": 6767676767, "description": "Hadiah dari owner!"},
	"FOKUSCRYPTO": {"type": "coins", "quantity": 99999, "description": "BITCOIN LU ADA BERAPA BOS!?"},
	"LAMPORGIFT": {"type": "coins", "quantity": 2500, "description": "hadiah untuk kalian!"},
	"FOREVERYONE": {"type": "coins", "quantity": 5000, "description": "Hadiah untuk semua pemain!", "description_en": "A gift for everyone!"},
	"LAMPORLOVER": {"type": "coins", "quantity": 10000, "description": "Hadiah spesial pecinta Lampor!", "description_en": "Special gift for Lampor fans!"}
}

static func normalize_code(raw_code: String) -> String:
	var upper: String = raw_code.strip_edges().to_upper()
	var result: String = ""
	for i: int in range(upper.length()):
		var ch_code: int = upper.unicode_at(i)
		if (ch_code >= 65 and ch_code <= 90) or (ch_code >= 48 and ch_code <= 57):
			result += upper[i]
	return result

static func get_reward(raw_code: String) -> Dictionary:
	var normalized: String = normalize_code(raw_code)
	if not CODES.has(normalized):
		return {}
	var reward: Dictionary = CODES[normalized]
	return reward.duplicate(true)
