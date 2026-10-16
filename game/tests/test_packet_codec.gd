extends SceneTree
## 验证小包兼容、大快照压缩与解压大小边界。

const Codec = preload("res://network/packet_codec.gd")
var failures := 0

func _initialize() -> void:
	var small := {"type": "pong"}
	_check(Codec.decode(Codec.encode(small)) == small, "小包应保持 JSON 往返兼容")
	var big := {"type": "snapshot", "units": []}
	for index in range(100): big.units.append({"id": "unit_%d" % index, "hp": 600, "position": [32, 30]})
	var packet := Codec.encode(big)
	_check(packet.size() < JSON.stringify(big).to_utf8_buffer().size() / 2, "典型快照应显著减少分片载荷")
	_check(Codec.decode(packet) == Codec.decode(JSON.stringify(big).to_utf8_buffer()), "压缩与普通 JSON 解码后的快照内容必须一致")
	var oversized := {"text": "a".repeat(Codec.MAX_BYTES)}
	_check(Codec.encode(oversized).is_empty(), "超限快照必须拒绝编码")
	var forged := packet.duplicate()
	forged.encode_u32(4, Codec.MAX_BYTES + 1)
	_check(Codec.decode(forged).is_empty(), "解压前必须拒绝超限声明，防止无界分配")
	forged.encode_u32(4, 0)
	_check(Codec.decode(forged).is_empty(), "零长度声明必须拒绝")
	_check(Codec.decode(packet.slice(0, 8)).is_empty(), "截断头不能进入解压")
	_check(Codec.decode("[]".to_utf8_buffer()).is_empty(), "非字典载荷不能进入协议")
	if failures == 0: print("网络载荷编码测试通过。")
	quit(1 if failures else 0)

func _check(value: bool, reason: String) -> void:
	if not value:
		failures += 1
		push_error(reason)
