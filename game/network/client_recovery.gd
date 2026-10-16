extends RefCounted
## 有时限的传输重试；不决定英雄状态，也不重放未确认命令。

const Protocol = preload("res://network/dev_protocol.gd")
const WINDOW_MS := 25000
const ATTEMPT_MS := 3000
var token := ""
var deadline := 0
var next_attempt := 0
var sent := false
var port := 0

func begin(client: RefCounted, destination: int, now: int) -> void:
	port = destination
	deadline = now + WINDOW_MS
	next_attempt = now
	sent = false
	client.close()

func step(client: RefCounted, now: int) -> bool:
	if now >= deadline: return false
	if now >= next_attempt:
		client.close()
		client.start(port)
		next_attempt = now + ATTEMPT_MS
		sent = false
	if not sent and client.peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		var request: Dictionary = Protocol.identity()
		request.merge({"type": "resume", "match": Protocol.MATCH_ID, "token": token})
		if client.send(request) == OK: sent = true
	return true
