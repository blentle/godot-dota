extends RefCounted
## 有界 JSON 载荷编码；大快照先压缩再交给 ENet 分片，禁止反序列化对象。

const MAX_BYTES := 262144
const MAGIC := [68, 90, 48, 49]

static func encode(message: Dictionary) -> PackedByteArray:
	var raw := JSON.stringify(message).to_utf8_buffer()
	if raw.size() > MAX_BYTES: return PackedByteArray()
	if raw.size() < 1024: return raw
	var compressed := raw.compress(FileAccess.COMPRESSION_ZSTD)
	if compressed.size() + 8 >= raw.size(): return raw
	var packet := PackedByteArray(MAGIC)
	packet.resize(8)
	packet.encode_u32(4, raw.size())
	packet.append_array(compressed)
	return packet

static func decode(packet: PackedByteArray) -> Dictionary:
	if packet.is_empty() or packet.size() > MAX_BYTES: return {}
	var raw := packet
	if packet.size() >= 4 and packet.slice(0, 4) == PackedByteArray(MAGIC):
		if packet.size() <= 8: return {}
		var expected := packet.decode_u32(4)
		if expected < 1 or expected > MAX_BYTES: return {}
		raw = packet.slice(8).decompress(expected, FileAccess.COMPRESSION_ZSTD)
		if raw.size() != expected: return {}
	var parser := JSON.new()
	if parser.parse(raw.get_string_from_utf8()) != OK or not parser.data is Dictionary: return {}
	return parser.data
