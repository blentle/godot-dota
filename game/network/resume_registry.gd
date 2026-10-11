extends RefCounted
## 开发局内存凭据：随机能力令牌只绑定本局席位，不充当平台身份或长期登录凭据。

const GRACE_MS := 30000
var records: Dictionary = {}

func issue(slot: int) -> String:
	var token := Crypto.new().generate_random_bytes(32).hex_encode()
	records[slot] = {"token": token, "deadline": 0}
	return token

func detach(slot: int, now: int) -> void:
	if records.has(slot): records[slot].deadline = now + GRACE_MS

func resolve(token: Variant, now: int) -> int:
	if not token is String or token.length() != 64: return -1
	for slot in records:
		var record: Dictionary = records[slot]
		if record.token != token: continue
		if record.deadline != 0 and now >= record.deadline: return -1
		return slot
	return -1

func bind(slot: int) -> void:
	records[slot].deadline = 0

func token_for(slot: int) -> String:
	return records[slot].token
