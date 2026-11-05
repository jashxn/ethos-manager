# Executor WebSocket, crypto, autoexec, and Lune 0.10 harness

All sources read 2026-11-05.

## 1. Executor WebSocket API

**Question:** What is the WebSocket API in executors, and which executors support it?

**Answer:** UNC defines `WebSocket.connect(url) -> ws`. The returned object has `ws:Send(msg)`, `ws:Close()`, `ws.OnMessage:Connect(fn(msg: string))` and `ws.OnClose:Connect(fn())`. Messages are strings only.

**Details**
- Spec text (UNC `api/WebSocket.md`): `function WebSocket.connect(url: string): WebSocket`. Its example connects to `ws://localhost:8080`, so plain ws:// to localhost is the documented case.
- The spec says nothing on binary frames, size limits, connect errors, or reconnect. Treat payloads as UTF-8 text strings, and send JSON (or base64 for binary).
- **Not verified:** support in each executor (Potassium, Wave, Solara, Xeno, Volcano, Swift, AWP), per-executor message size caps, and whether `127.0.0.1` behaves differently from `localhost`. Probe at runtime with `type(WebSocket) == "table" and type(WebSocket.connect) == "function"` and wrap the connect call in `pcall`. Some older executors use `syn.websocket.connect`.
- Existing library code: grepping `Ethos-Suite-Library-em/src` found no `WebSocket.connect` and no `crypt.` uses. The only executor-global pattern is the feature probe in `src/app/relaunch.luau:38-42` (`queue_on_teleport`, falling back to `syn.queue_on_teleport`). A WebSocket probe should copy that style.

## 2. Crypto for HMAC-SHA256

**Question:** Can UNC crypt functions compute an HMAC-SHA256?

**Answer:** UNC has no `crypt.hmac`. It has `crypt.hash(data, algorithm)` (algorithms include 'sha256'), `crypt.generatebytes(size)`, `crypt.generatekey()` and `crypt.base64encode/base64decode`. You can build HMAC from `crypt.hash`, but the spec does not say whether the output is hex or raw bytes. The spec page notes its behaviour is "based on Script-Ware" and marks encrypt/decrypt as having too few supporting executors. Do not rely on crypt matching across executors.

**Details**
- HMAC = H((K xor opad) .. H((K xor ipad) .. m)). The inner hash must come back as raw bytes. If an executor returns hex, decode it before the outer hash.
- Recommendation: ship a pure-Luau SHA-256/HMAC (about 150 lines, using `bit32` or `buffer`). It is deterministic everywhere and can be tested against Lune's `serde.hmac`. Cost is **not measured**. Expect roughly tens of microseconds per 64-byte block in native Luau, which is negligible for small control messages. Benchmark before signing large payloads.
- `crypt.generatebytes` gives random bytes for nonces where present. Fall back to `Random.new()` if it is missing (weaker, so flag it).

## 3. autoexec and queue_on_teleport

**Answer:** UNC `misc.md` defines `queue_on_teleport(code: string): ()`, which "Queues the specified script to be executed after the player teleports to a different place." UNC does not document autoexec folders.
**Not verified:** autoexec is an executor convention, usually an `autoexec/` folder next to the executor's `workspace/`, whose scripts run on each game join. Each executor names and times it differently. The library already uses `queue_on_teleport` (see `src/app/relaunch.luau`). Project memory says to use it only when `LPH_OBFUSCATED`.

## 4. Lune 0.10 net and serde

**Answer:** Latest 0.10 is v0.10.5 (2026-07-02). Newer releases exist: v0.11.0 (2026-10-11) and v0.11.1 (2026-10-21). Recheck these APIs if you pin 0.11.
- `net.socket(url: string): WebSocket`
- `WebSocket = { closeCode: number?, close(self, code?), send(self, message: (string|buffer)?, asBinaryMessage: boolean?), next(self) -> string? }`. `next` yields until the next message arrives and returns nil once the socket is closed. `send` throws on a closed socket.
- `net.serve(port, { handleRequest, handleWebSocket = function(socket) end })` lets a Lune harness play the server side too.
- `serde.encode("json", value, pretty?)` and `serde.decode("json", str|buffer)`. Formats: json, jsonc, yaml, toml.
- `serde.hash(alg, msg) -> hex string` and `serde.hmac(alg, msg, secret) -> base64 string`. Algorithms include md5, sha1, sha224, sha256, sha384, sha512 and sha3-*. Note the encodings differ: hash returns hex, hmac returns base64.

A fake Roblox client in Lune can call `net.socket("ws://127.0.0.1:PORT")`, loop on `sock:next()`, and `sock:send(serde.encode("json", msg))`. Map the executor's `OnMessage`/`Send`/`Close` onto `next`/`send`/`close` with a small adapter.

## Sources (read 2026-11-05)
- https://github.com/unified-naming-convention/NamingStandard/blob/main/api/WebSocket.md
- https://github.com/unified-naming-convention/NamingStandard/blob/main/api/crypt.md
- https://github.com/unified-naming-convention/NamingStandard/blob/main/api/misc.md
- https://github.com/lune-org/lune/releases (gh api)
- https://github.com/lune-org/lune/blob/v0.10.5/crates/lune-std-net/types.d.luau (lines 155-180, 378, 393)
- https://github.com/lune-org/lune/blob/v0.10.5/crates/lune-std-serde/types.d.luau (lines 16, 58-65, 111, 127, 181, 196-202)
- https://github.com/lune-org/lune/blob/v0.10.5/crates/lune-std-serde/src/hash.rs
- Local: C:/Users/famet/OneDrive/Desktop/Ethos-Suite-Library-em/src/app/relaunch.luau
