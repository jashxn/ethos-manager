# Ethos Manager bridge protocol v1 (final)

Status: final spec for Phase 1 step 1 ("Bridge protocol") of
`docs/plans/ethos-manager.md`, under ADR 0006 and the new ADR 0008
(`adr-0008-bridge-protocol.md`). Written 2026-11-05 for an unattended build.
An implementer should be able to build the Rust server, the Lua stub, the full
Lua bridge and the library adapter from this file alone.

This is the reconciliation of the five panel designs. It starts from the two
protocol winners (`protocol-security`, `protocol-minimal`) and the two mirror
winners (`mirror-registry`, `mirror-snapshot`), grafts the ideas the judges
called for, and fixes every flaw they listed. Where a decision resolves a flaw
or applies a graft, the text says so inline as **[fix]** or **[graft]**.

The central reconciliation: the handshake and crypto come from
`protocol-security` (client-first, port-bound and source-bound proofs), but the
post-handshake wire is **connection-authenticated with no per-frame MAC**, as in
`protocol-minimal`. Section 1.4 proves that `SO_EXCLUSIVEADDRUSE` + port-bound +
source-bound proofs + loopback TCP integrity close the in-scope threat model
without per-frame MACs, which keeps the design the "smallest complete" one the
plan asks for. The mirror is `mirror-registry`'s one-row-per-registry-entry
model, carried inside the protocol's own `register`/`values`/`set` messages
rather than a separate `ui.*` family, so no mirror-specific message type exists.

---

## 0. Where the code lives

Repo `jashxn/ethos-manager` (the RoALT fork). The Ethos library
(`jashxn/Ethos-Suite-Library`) holds **no transport and no token**; it is a
client of the public Lua API (§8).

| Path | What |
| --- | --- |
| `bridge/stub.luau` | Stub template. Placeholders `__PORT__`, `__TOKEN__`, `--[[HMAC]]`. |
| `bridge/hmac.luau` | Pure-Luau `sha256(s) -> hex` and `hmac(keyText, msg) -> hex`, ~100 lines, `bit32` + `buffer` + `string.pack`. Returns `sha256, hmac`; inlined into the stub. |
| `bridge/bridge.luau` | The full bridge: framing, messages, the public API, the heartbeat. Bundled with `protocol.luau`, served by the app. |
| `bridge/protocol.luau` | The pure Lua validator (no HttpService, runs under Lune and in game). Takes a JSON codec parameter. |
| `bridge/fixtures/ws/<group>/<name>.json` | Shared handshake / crypto / message fixtures (§14). |
| `bridge/fixtures/mirror/<name>.json` | Shared mirror (schema / row / value) fixtures (§14). |
| `bridge/tests/*.luau` | Lune tests (§14, §15). |
| `src-tauri/src/ethos/bridge/{mod,server,protocol,crypto,dispatch}.rs` | The Rust server, validator and HMAC helpers. All new Rust goes under `src/ethos/` so merges with upstream RoALT stay clean (plan risk). |
| `Ethos-Suite-Library` `src/app/bridge.luau` | The library adapter: schema from the registry, value encoding, `onSet`, `onLoadout`, stats. App layer (ADR 0001 rank 5), kept in `PRIVATE_MODULES` of the runtime split because it is wired from `V2:CreateWindow`. Holds no socket and no secret. |

New Rust dependencies: `tokio-tungstenite` (no TLS features). **`sha2` 0.10 and
`subtle` 2.6 are already in the lockfile**; HMAC is ~10 lines on `sha2` and the
compare is `subtle`'s constant-time `ct_eq`, so **no `hmac` crate is added**
**[graft: implement HMAC on `sha2`, keep the RoALT fork's dependency diff
smaller]**. `getrandom`, `tokio`, `serde_json`, `windows` (0.62) are present.
`SO_EXCLUSIVEADDRUSE` needs the `Win32_Networking_WinSock` feature on the
existing `windows` dep; no new crate.

---

## 1. Trust model

### 1.1 Assets

- The ability to run code on the user's Roblox clients (the highest-value asset).
- The pairing token.
- Loadout startup scripts, which embed the user's `script_key`.
- Masked input values (Agent API keys, the Account Manager webserver password at
  `src/app/accountManager.luau:181`, webhook URLs). These never travel the bridge
  (§9.4) **[fix: masked leak in every mirror design]**.
- Values and schema, which are game state and are untrusted text to the agent.

### 1.2 Attackers and outcomes

| # | Attacker | Outcome |
| --- | --- | --- |
| A1 | Web page in any browser (always sends `Origin`) | Upgrade 403 (§2.1). |
| A2 | Fake app squatting the port (app closed, or a stale/hand-copied stub dialling an old port after a port change) | Gets one client nonce and one client proof bound to that attacker's nonce and port. Cannot produce a valid server proof (no token), so the stub never runs its code. Learns **no alt identity**: identity is sent only after the server proves itself (§3). |
| A3 | Local process without the token | Gets an `auth.challenge` nonce, then a close. Never gets `auth.ok`, the bridge source, a loadout, values or schema. |
| A4 | Relay / MITM (fake server on port Q forwarding to the real app on P) | Both proofs bind the dialled port, so a stub on Q and an app on P compute different transcripts; both reject. The server proof also binds `H(source)`, so a relay that swaps the served code is rejected (§3.2). |
| A5 | Same-user process that can bind but not read the stub (low-integrity / AppContainer) trying to hijack port P with `SO_REUSEADDR` | `SO_EXCLUSIVEADDRUSE` is set before `bind`, so no second socket can take the port while the app holds it (§2.1) **[fix: minimal cut this, same-port relay]**. |
| A6 | Replayer (loopback capture, e.g. Npcap without admin mode) | Fresh nonces each handshake defeat handshake replay. Post-auth: injecting into an established loopback TCP stream needs admin/kernel (§1.4), which is out of scope. |
| A7 | Other local Windows user reading files outside the profile | The stub file ACL is restricted to the owner, SYSTEM, Administrators (§2.4) **[fix: both mirror threat models assumed this but neither set the ACL]**. |
| A8 | Oversized / slow / flooding local client | Bounded memory and time (§5); availability against a local process is not a goal. |

### 1.3 Out of scope (stated so nothing relies on them)

- An administrator, the kernel, or the same user with malware. They read the
  stub file and app memory and own the alts anyway.
- Other scripts in the same executor. They are already trusted with the client.
  The bridge keeps the token and no secret in `getgenv` or the public API, so
  nothing leaks by accident.
- **Confidentiality against a loopback sniffer.** Frames are authenticated at the
  connection, not encrypted. A process that installs Npcap without its admin-only
  capture option could read a loadout `script_key`. Upgrade path (§1.4): encrypt-
  then-MAC inside the served bridge, no stub change.

### 1.4 Why connection authentication, not a per-frame MAC

`protocol-security` signed every frame; `protocol-minimal` signed only the
handshake. The judges rated security highest but called per-frame MACs "beyond
the fixed constraints" and "the heaviest build this week" (~33 ms per 512 KiB
`run` in pure Luau, unmeasured on executors). This spec signs only the handshake,
because the in-scope threat model closes without per-frame MACs **once three
things hold together**:

1. `SO_EXCLUSIVEADDRUSE` before `bind`, so no other socket can take the port
   while the app holds it.
2. Both proofs bind the **dialled port**, so a relay on a different port fails.
3. The server proof binds **`H(served source)`**, so a relay cannot substitute
   the code the stub runs.

The only remaining way to tamper with an authenticated connection is injecting
into an established loopback TCP stream, which needs admin/kernel — out of scope,
and a same-user process already has the token. This is exactly the hole in
`protocol-operability` (it had neither port nor source in its proofs **and** no
exclusive bind), which is why that design failed; binding both and setting the
exclusive flag fixes it without per-frame MACs. The decision and its upgrade path
are recorded in ADR 0008.

### 1.5 Assumptions

- Windows `CryptGenRandom` via `getrandom` is a CSPRNG.
- HMAC-SHA256 is a PRF.
- The stub file reaches the executor intact (the app writes it, or the user
  copies it).

---

## 2. Listener, port, token, stub file

### 2.1 Listener

- Bind **IPv4 `127.0.0.1` only**. Never `0.0.0.0`, never `::1`. The stub dials
  the literal `ws://127.0.0.1:<port>/`, never `localhost`, so it can never
  resolve to a `[::1]` listener someone else owns.
- Set **`SO_EXCLUSIVEADDRUSE`** before `bind`:
  `TcpSocket::new_v4()` → `as_raw_socket()` →
  `setsockopt(SOL_SOCKET, SO_EXCLUSIVEADDRUSE, 1)` → `bind` → `listen(64)`.
- WebSocket via `tokio-tungstenite` `accept_hdr_async_with_config` with
  `max_message_size = max_frame_size = 1 MiB`.
- Header callback:
  - Any `Origin` header, any value including `null`, gets **HTTP 403**; the value
    and User-Agent are logged (to tell a web page from an executor that
    unexpectedly sends `Origin`). No WebSocket is produced.
  - The request path is ignored. No CORS header is ever sent.
  - A plain HTTP request without an upgrade gets 400 from tungstenite.

### 2.2 Port

- First start: a random port in **20000–39999** from `getrandom` (below the
  Windows dynamic range 49152–65535), persisted in settings row `bridge_port`.
- Later starts: bind the saved port. On failure, pick again (up to 20 tries),
  persist, rewrite the stub at the saved autoexec folder, and show an
  `app://notice`: "Bridge port changed. Copies of the stub you placed yourself
  must be replaced." The board shows "port N is in use" with a "pick a new port"
  action.
- A squatter can force a port change but gains nothing; stale stubs hit A2.

### 2.3 Token and Reset pairing

- 32 bytes from `getrandom`, **64 lowercase hex characters** = `TOKEN`.
- Stored in settings row `bridge_token` via `set_setting_value` (SQLCipher, DPAPI
  key, readable while a Master vault is locked). **Never** in the `Settings` JSON
  blob that `settings_get` returns to the UI. Reuse `discord::hex`/`unhex`.
- The UI gets the token only inside the stub text, from `bridge_stub()` (copy) or
  `bridge_stub_write(folder)` (one click).
- **Reset pairing** (`bridge_reset_pairing`, ships in the MVP): generates a new
  token, rewrites the stub at the saved folder, and closes every bridge
  connection with close code 4401. It is the only remedy for a leaked stub
  **[fix: minimal had no rotation; operability's `kid` only labelled stale
  stubs]**. A stale running stub then fails its proof and is counted in
  `failed_auth`; the board lists "old stub: rejoin these alts".
- The app never logs the token, a proof, a loadout script, or run code — only
  frame `type`, byte length, connection id and close reason.

### 2.4 Stub file

- Written atomically as `ethos-bridge.lua` into the user-chosen autoexec folder
  (no auto-detection, per plan).
- Its ACL is then limited to the current user, SYSTEM and Administrators, with
  the same `icacls` call as `restrict_to_user` in `main.rs` (roalt-core
  L272), applied to the file **[graft + fix]**. Without this, executor folders
  outside the profile (e.g. `C:\SomeExecutor\autoexec`) inherit
  `Authenticated Users: Read` and any local user reads the token.
- A hand-made copy gets no ACL; the copy dialog says so in one line.

---

## 3. Handshake

### 3.1 Sequence (client-first, identity-free)

```
stub (executor)                                      app (127.0.0.1:P)
   |  TCP + WS upgrade (no Origin)                         |  403 if Origin; <= 8 unauth
   |  auth.begin   {v:1, nonce:Nc}                         |  (no identity)
   |------------------------------------------------------>|  Ns = 32 bytes getrandom
   |  auth.challenge {v:1, nonce:Ns}                       |
   |<------------------------------------------------------|
   |  auth.proof   {v:1, proof:Pc}                         |
   |------------------------------------------------------>|  verify Pc (constant time) else 4401
   |  auth.ok      {v:1, proof:Ps, source:<bridge chunk>}  |
   |<------------------------------------------------------|
   |  verify Ps over H(source), then loadstring(source)    |
   |  hello {identity, loadout:bool}  ... framed msgs ...   |
   |<=====================================================>|
```

**Why the client speaks first.** An executor's `OnMessage` can drop a frame that
arrives before the handler is connected (reproduced in both prototypes). The stub
connects its handlers, then sends `auth.begin`, so the app never sends into that
race **[fix: operability's server-first handshake lost the challenge]**.

**Why the client proves first, and sends no identity first.** An unauthenticated
peer gets only a random nonce — no server proof to study, no bridge source, no
state, and **no alt identity** (user id, place, job). A squatter learns nothing
**[fix: minimal and operability sent `hello` identity before the server proved
itself]**.

### 3.2 Exact transcript (byte level)

All values are ASCII. `\n` is byte `0x0A`. `HMAC` is HMAC-SHA256 (RFC 2104); `H`
is SHA-256. Both are written as **64 lowercase hex characters**. The HMAC key is
the 64-byte ASCII text of the token hex string itself — exactly one SHA-256
block, so it is used as-is, with no hashing down and no hex-decoding on either
side.

```
TOKEN = 64 lowercase hex (the pairing token)
PORT  = decimal port, no sign, no leading zeros
        stub: the PORT constant it dialled;  app: its own listening port
Nc    = 64 lowercase hex, chosen by the stub
Ns    = 64 lowercase hex, chosen by the app (getrandom, 32 bytes)
T     = PORT .. "\n" .. Nc .. "\n" .. Ns

Pc = HMAC(TOKEN, "ethos-bridge/1 client\n" .. T)
Ps = HMAC(TOKEN, "ethos-bridge/1 server\n" .. T .. "\n" .. H(SOURCE))
```

- `SOURCE` is the `source` string of `auth.ok`: the decoded JSON string on the
  stub, the served bytes on the app. A Rust test asserts the bundled bridge
  source `is_ascii()`, so no JSON decoder can disagree about the bytes.
- There is **no per-frame key and no per-frame MAC** (§1.4). `Kc`/`Ka` from
  `protocol-security` are not derived.

| Part | Prevents |
| --- | --- |
| Labels `client` / `server` | Reflection: one role's proof replayed as the other's. |
| `ethos-bridge/1` in both labels | Cross-version reuse; a later handshake version cannot accept v1 proofs. |
| `PORT` in `T` | Relay (A4). A stub on Q and an app on P never agree. |
| `Nc` | Replay of a recorded `auth.ok` to the stub. |
| `Ns` (CSPRNG) | Replay of a recorded `auth.proof` to the app. |
| `H(SOURCE)` in `Ps` | Code substitution (A4). The proof that authenticates the server also pins the exact code the stub will run. |
| Fixed-length lowercase hex + decimal fields | Ambiguity. No field can contain `\n`, so the joined string has one parse. |

**Worked vector** (fixture `ws/crypto/handshake-valid`; computed in Node `crypto`
and cross-checked in Lune 0.10.5 `serde.hmac`):

```
TOKEN      7f3c9a1e5b2d4f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8
PORT       51734
Nc         61c3a46f9de2f8fe55aad88d2d21c243ccf7a99b8ced3c68b99de3b579a272c3
Ns         5b7687b0d4f2e27712388be3eb5cc1963b6700e57325a330f9f08905aa5e552a
SOURCE     return function(ctx) end
H(SOURCE)  cf2615b3b4daf7817cc83fde8196c45e9830a57a605306c7606463346b128650
Pc         cc4dffa7a19dc4e7297f0d41b0e9ba85d023a83a535adce0dc354d22a9328d0f
Ps         06a67108f4f44ed9cec176e52169b326713b58602ae0fdb34a83edeb50e31316
Ps @ PORT 51735 (must reject)  338282cd61be0f303eaf533b7a16e8fe7a00293f1e9098c051d2bb64f359adff
```

> **Encoding note for the fixture generator.** Lune 0.10.5 on this machine
> returned HMAC as **hex**, although its docs say base64. Do not assume either;
> compare against Node, or decode explicitly.

### 3.3 Client nonce

```lua
local function entropy()
	local ok, bytes = pcall(function() return crypt.generatebytes(32) end)
	return tostring(ok and bytes) .. Random.new():NextNumber() .. os.clock() .. game.JobId .. tostring({})
end
local Nc = sha256(entropy())
```

`crypt.generatebytes` is missing on some executors, so `Nc` can be weaker than
`Ns`. Acceptable: `Nc` only protects the stub from a replayed `auth.ok`, and
even a successful replay can only run an older bridge the app genuinely served —
without `TOKEN` the attacker can send no valid frame afterward.

### 3.4 What the stub verifies before running served code

In this order; any failure means `ws:Close()`, back off, retry (§7). The stub
never prints, warns or errors (quiet).

1. `WebSocket.connect` (or `syn.websocket.connect`) and `loadstring` exist; else
   return at once (the quiet exit).
2. Generation guard: `gen = (getgenv().__ethosBridgeGen or 0) + 1`;
   `getgenv().__ethosBridgeGen = gen`. The loop runs only while it still owns
   `gen`, so a rewritten stub (after Reset pairing or a port change) supersedes
   the old loop in the same VM, no rejoin needed **[graft: replace security's
   hard `__ETHOS_BRIDGE_STUB` guard with minimal's generation counter]**.
3. The connection is to `"ws://127.0.0.1:" .. PORT .. "/"`, fixed in the file.
4. The **first** frame within 10 s is text ≤ 1 MiB, JSON, `v == 1`,
   `type == "auth.challenge"`, `nonce` 64 chars `[0-9a-f]`. Anything else fails.
5. Send `auth.proof` with `Pc`.
6. The **next** frame within 10 s is text ≤ 1 MiB, JSON, `v == 1`,
   `type == "auth.ok"`, `proof` 64 hex, `source` a string.
7. `hmac(TOKEN, "ethos-bridge/1 server\n" .. T .. "\n" .. sha256(source)) == proof`
   (plain string equality; both sides lowercase hex).
8. `loadstring(source, "=EthosBridge")` returns a function.
9. Only now, `pcall(fn, ctx)`. The served chunk receives `ctx` as `...` (the
   bridge source starts `local ctx = ...`, not `return function(ctx)`). `ctx`
   holds the socket functions and the crypto, **never `TOKEN`**.

`ctx`:

```lua
{
	send = function(text: string) end,          -- raw text frame
	recv = function(timeout: number): string? end,  -- next frame; nil on close/timeout
	close = function() end,
	isClosed = function(): boolean end,
	sha256 = sha256, hmac = hmac,               -- so the bridge carries no crypto
}
```

### 3.5 What the app verifies

1. The upgrade completed within 5 s of accept, no `Origin`, and there are fewer
   than **8 unauthenticated** and **200 authenticated** connections. Otherwise
   close at accept. The unauth cap is 8 but accept uses **±20 % backoff jitter**
   on the app's own retry/accept pacing so 50 alts reconnecting after an app
   update are not all dropped in one wave **[graft: raise effective capacity with
   jitter]**.
2. First frame: text ≤ 512 B, JSON, validator `auth.begin`. The `type` is checked
   first: any type other than `auth.begin` (including `hello` or `register`) →
   **4400**; an `auth.begin` with `v ~= 1` → **4426**; any other failure →
   **4400**.
3. Send `auth.challenge` with a fresh `Ns`.
4. Next frame: text ≤ 512 B, validator `auth.proof`. Hex-decode `proof`, verify
   with `subtle::ct_eq` (constant time). Failure → **4401**, `failed_auth += 1`
   (shown on the board with the last-failure time).
5. Whole handshake within 5 s of accept, else **4408**.
6. Send `auth.ok`; wait for `hello`.

No lockout after failures (a lockout lets any local process lock out real stubs,
and a 256-bit token is not brute-forceable).

### 3.6 Stub source

Assembled by Rust and by the Lune tests with the same three literal (plain
string, not pattern) `replace` calls; `string.gsub` breaks because `hmac.luau`
contains `%`.

```lua
local PORT, TOKEN = __PORT__, "__TOKEN__"
local env = getgenv and getgenv() or _G
local gen = (env.__ethosBridgeGen or 0) + 1
env.__ethosBridgeGen = gen
local connect = (type(WebSocket) == "table" and WebSocket.connect)
	or (type(syn) == "table" and type(syn.websocket) == "table" and syn.websocket.connect)
if type(connect) ~= "function" or type(loadstring) ~= "function" then return end
local Http = game:GetService("HttpService")
local sha256, hmac = (function() --[[HMAC]] end)()
local MAX = 1048576

local function hex64(s) return type(s) == "string" and #s == 64 and not s:find("[^0-9a-f]") end
local function decode(s)
	if not s then return nil end
	local ok, v = pcall(Http.JSONDecode, Http, s)
	return ok and type(v) == "table" and v or nil
end
local function entropy()
	local ok, bytes = pcall(function() return crypt.generatebytes(32) end)
	return tostring(ok and bytes) .. Random.new():NextNumber() .. os.clock() .. game.JobId .. tostring({})
end

local function session()
	local ok, ws = pcall(connect, "ws://127.0.0.1:" .. PORT .. "/")
	if not ok or not ws then return end
	local inbox, closed = {}, false
	local function close() closed = true; pcall(ws.Close, ws) end
	ws.OnMessage:Connect(function(m)
		if closed then return end
		if type(m) ~= "string" or #m > MAX or #inbox >= 256 then return close() end
		table.insert(inbox, m)             -- queue only; never yields in OnMessage
	end)
	ws.OnClose:Connect(function() closed = true end)
	local function recv(timeout)
		local waited = 0
		while #inbox == 0 and not closed and waited < timeout do waited += task.wait(0.05) end
		return table.remove(inbox, 1)
	end
	local nc = sha256(entropy())
	ws:Send(Http:JSONEncode({ v = 1, type = "auth.begin", nonce = nc }))
	local c = decode(recv(10))
	if not (c and c.v == 1 and c.type == "auth.challenge" and hex64(c.nonce)) then return close() end
	local t = PORT .. "\n" .. nc .. "\n" .. c.nonce
	ws:Send(Http:JSONEncode({ v = 1, type = "auth.proof", proof = hmac(TOKEN, "ethos-bridge/1 client\n" .. t) }))
	local w = decode(recv(10))
	if not (w and w.v == 1 and w.type == "auth.ok" and hex64(w.proof) and type(w.source) == "string") then return close() end
	if hmac(TOKEN, "ethos-bridge/1 server\n" .. t .. "\n" .. sha256(w.source)) ~= w.proof then return close() end
	local run = loadstring(w.source, "=EthosBridge")
	if not run then return close() end
	pcall(run, {
		send = function(s) if not closed then ws:Send(s) end end,
		recv = recv, close = close, isClosed = function() return closed end,
		sha256 = sha256, hmac = hmac,
	})
	close()
end

task.spawn(function()                      -- wrapped so autoexec is never blocked
	if not game:IsLoaded() then game.Loaded:Wait() end
	while env.__ethosBridgeGen == gen do
		local started = time()
		pcall(session)
		if env.__ethosBridgeGen ~= gen then break end
		local delay = (time() - started > 60) and 2 or math.min((env.__eb_delay or 2) * 2, 60)
		env.__eb_delay = delay
		task.wait(delay * (0.8 + math.random() * 0.4))   -- +-20% jitter
	end
end)
```

`loadstring` runs exactly once, on a `source` whose `Ps` verified. The whole body
is `task.spawn`ed and waits for `game.Loaded`, so it never blocks other autoexec
scripts, and `OnMessage` only queues — it never yields **[fix: minimal ran
`game.Loaded:Wait()`, the reconnect loop and `loadstring` on the autoexec thread
inside `OnMessage`]**.

---

## 4. Framing and versioning after the handshake

- Every post-auth frame is one UTF-8 JSON object, one message, with a `type`
  field. There is **no `mac`, no `seq`, and no per-frame `v`**: the stream is
  authenticated once by the handshake (§1.4), TCP preserves order, and every
  post-auth frame comes from code the app served in the same build, so it cannot
  be out of version step.
- **Versioning rule.** `v:1` lives only on the four handshake frames. The stub
  carries it; the app accepts `v == 1` and rejects anything else (**4426**). To
  change the post-handshake wire, change `bridge/bridge.luau` — a stub loads the
  new bridge on its next handshake with no version negotiation. The handshake
  frames are the only thing that must stay backward-compatible; any change to
  them must be additive and bump the label to `ethos-bridge/2`.
- **Empty-map gotcha.** `HttpService:JSONEncode({})` emits `[]`. Both validators
  accept `[]` as an empty map wherever a map is expected (`values`, `input`).
  Fixtures cover it.
- **Strictness.** An unknown key in any fixed-key object (the frame, an action,
  an input, a declared value, an element, `executor`, `ethos`, `ethos.config`) or
  an unknown `type` makes a frame invalid. Maps keyed by ids or names (`values`,
  `input`, `addons`) are open. A schema element never carries a value. Both ends
  ship from one build, so strictness only catches bugs.
- Third-party data (action/value/schema definitions) is **sanitised by the
  bridge API layer before it is sent**: only known keys are copied, strings are
  clipped to their caps on UTF-8 boundaries, counts over a cap are dropped with
  one `warn`. Ids are never truncated; an over-long id raises an error in the
  calling script. So only valid frames reach the wire.

Field rules used throughout:
- **Id**: 1–200 bytes, no control chars (0–31, 127). Library ids may hold spaces,
  `@` and `/` (add-on ids are `@<Name>/<id>`). Unique within an owner across its
  actions, declared values and schema elements.
- **Owner**: 1–40 chars `[A-Za-z0-9 _.-]`.
- **Sizes**: every string cap counts UTF-8 bytes. A value's size is the byte
  length of its compact JSON encoding.

---

## 5. Message catalogue

Handshake frames carry `v:1` (§3). Post-auth frames omit `v`, `seq` and `mac`.

### 5.1 Pre-auth

| Type | Dir | Fields |
| --- | --- | --- |
| `auth.begin` | client → app | `nonce`: 64 hex (no identity) |
| `auth.challenge` | app → client | `nonce`: 64 hex |
| `auth.proof` | client → app | `proof`: 64 hex |
| `auth.ok` | app → client | `proof`: 64 hex; `source`: string, 1 byte to 1 MiB − 200 |

```json
{"v":1,"type":"auth.begin","nonce":"61c3a46f9de2f8fe55aad88d2d21c243ccf7a99b8ced3c68b99de3b579a272c3"}
{"v":1,"type":"auth.challenge","nonce":"5b7687b0d4f2e27712388be3eb5cc1963b6700e57325a330f9f08905aa5e552a"}
{"v":1,"type":"auth.proof","proof":"cc4dffa7a19dc4e7297f0d41b0e9ba85d023a83a535adce0dc354d22a9328d0f"}
{"v":1,"type":"auth.ok","proof":"06a67108f4f44ed9cec176e52169b326713b58602ae0fdb34a83edeb50e31316","source":"return function(ctx) end"}
```

### 5.2 Client → app

#### `hello` — the first post-auth frame, once per connection

```json
{"type":"hello","userId":123456789,"userName":"PetFarm01",
 "placeId":8737899170,"gameId":3317771874,"jobId":"8f2c41e0-77aa-4d1b-9c55-0a1b2c3d4e5f",
 "executor":{"name":"Potassium","version":"1.0.0"},"v":1,"loadout":false}
```

| Field | Rule |
| --- | --- |
| `userId` | Integer 1 to 2^53−1. |
| `userName` | 1–20 chars `[A-Za-z0-9_]`. |
| `placeId`, `gameId` | Integers 0 to 2^53−1. |
| `jobId` | 0–64 chars; `""` in Studio. |
| `executor` | `{name 1–40, version 0–40}` from `identifyexecutor()`. |
| `v` | The protocol version, as the plan requires on `hello`. |
| `loadout` | Boolean. **True once this Lua VM has actually received a `loadout` frame** (persisted in `getgenv().__ethosBridgeLoadout = jobId`). |

- The app must receive `hello` within 10 s of `auth.ok`, else **4408**. Any other
  first frame → **4400**.
- **`loadout` semantics [fix: loadout lost if the socket drops between hello and
  the loadout frame].** `loadout` is set true only when the bridge *receives* a
  `loadout` frame, not at bridge start. If the connection drops after `hello` but
  before the `loadout` frame arrives, the next reconnect's `hello` still reports
  `loadout:false`, so the app re-sends. The app sends the `loadout` frame only
  when `hello.loadout == false` **and** the account has a loadout.
- **Linking.** The app links the connection to the account whose Roblox user id
  is `userId`, cross-checking `jobId` against the tracker `Instance.job_id`. A
  connection that matches nothing shows as "not launched by Ethos Manager" but
  stays usable.
- **Duplicates — newest wins [graft + fix].** A second live connection for the
  same `userId` closes the **older** one (code 4409 to the old socket), replacing
  `protocol-security`'s keep-first rule, which locked a reconnecting VM out for up
  to 20 s after a blip. A stale socket from a teleport is cleaned up this way.

#### `status` — heartbeat and state

```json
{"type":"status","state":"playing","fps":59.8}
{"type":"status"}
{"type":"status","state":"teleporting"}
```

- `state` optional: `loading`, `playing`, `teleporting`. On
  `LocalPlayer.OnTeleport` (`Started`) the bridge sends `teleporting` at once, so
  the board distinguishes a teleport from a crash **[graft]**.
- `fps` optional, 0–1000. Sent every 5 s and on every change (the heartbeat).

#### `register` — replaces one owner's whole registration

Debounced to at most one `register` per owner per 250 ms.

```json
{"type":"register","owner":"Ethos","title":"Ethos",
 "actions":[
  {"id":"rejoin","label":"Rejoin server","description":"Teleports back into this server"},
  {"id":"hatch","label":"Hatch eggs","inputs":[
    {"key":"egg","type":"choice","label":"Egg","options":["Grass Egg","Mining Egg"],"default":"Grass Egg"},
    {"key":"amount","type":"number","min":1,"max":1000,"default":50}]}],
 "values":[
  {"id":"@stats.playtime","label":"Playtime","unit":"s"},
  {"id":"@stats.executions","label":"Executions"}],
 "schema":[
  {"id":"AutoFarm","type":"Toggle","title":"Auto farm","path":["Main","Farming"]},
  {"id":"WalkSpeed","type":"Slider","title":"Walk speed","path":["Main","Farming"],"min":16,"max":100,"step":1},
  {"id":"Keep","type":"Range","title":"Keep between","path":["Main","Farming"],"min":0,"max":5000,"step":50},
  {"id":"Mode","type":"Dropdown","title":"Mode","path":["Main","Eggs"],"options":["Nearest","Strongest"],"multi":false},
  {"id":"ApiKey","type":"Input","title":"Agent key","path":["Settings","Agent"],"secret":true},
  {"id":"Status","type":"Text","title":"Farming area 3","path":["Main"]}]}
```

An owner closing sends
`{"type":"register","owner":"Ethos","actions":[],"values":[],"schema":[]}`.

| Field | Rule |
| --- | --- |
| `owner` | Owner rule. ≤ 8 owners per connection. |
| `title` | Optional, ≤ 100 bytes. |
| `actions` | ≤ 100 items `{id, label ≤ 100, description? ≤ 300, inputs? ≤ 12}`. |
| Action input | `{key 1–40 [A-Za-z0-9_.-] unique in the action, type: toggle\|number\|text\|choice, label? ≤ 100, options? ≤ 500 strings ≤ 100 (choice), min?/max? finite (number), default? matching the type ≤ 1 KiB}`. Inputs take no `path`. |
| `values` | ≤ 100 items `{id, label ≤ 100, unit? ≤ 20}`. Read-only status-board declarations. |
| `schema` | A **flat array** of elements (≤ 2000). Each element carries a `path` **[graft: path-based schema from Registry.place, not a fixed tabs→sections tree, so categories and sub-tabs survive]**. |
| Element | `{type 1–40 ASCII, id?, title? ≤ 200, description? ≤ 2000, path: 1–4 strings ≤ 200, min?/max?/step? finite, options? ≤ 500 strings ≤ 200, multi? bool, locked? string reason, hidden? true, secret? true, max? (progress)}`. |
| `more` | Optional `true`: another part of this registration follows (§9.5). |

`actions`, `values` and `schema` are required; an empty list is `[]`.

- **`path`** is `[category?, tab, subtab?, section]`, 1–4 strings, from
  `Registry.place(entry, " › ")` split on ` › `, repeats collapsed. The app
  groups the left rail by `path[1]`/tab and draws sections by the rest.
- An **unknown element `type` is valid**; the mirror draws it read-only as
  "Open in game to use this control" **[fix: snapshot and minimal-ui rejected a
  whole snapshot on one unknown type; here each element is validated on its own]**.
- An element without `id` is display-only.
- `secret: true` marks a masked input; its value is **never** sent in `values`
  and the validator rejects an element that has both `secret` and a value
  **[fix: masked leak]**.
- **Per-element validation.** The app validates each element on its own and draws
  an invalid one as a placeholder, so one bad control never blanks the mirror
  **[graft from registry]**.

#### `values` — merges live values into one owner

```json
{"type":"values","owner":"Ethos","values":{"AutoFarm":true,"WalkSpeed":24,"Keep":{"Min":500,"Max":5000},"Mode":"Nearest","@stats.playtime":5400}}
{"type":"values","owner":"Ethos","values":[]}
```

- Keys are ids that owner registered (declared values or schema elements). Each
  value is non-null JSON ≤ 8 KiB. The app keeps ≤ 256 KiB per owner (the sum of
  the sizes of the owner's current values, §4; a single frame over it is invalid
  on its own), checked on
  the app side **and** against a shared `limits-valid.json` the bridge sanitiser
  also reads, so the two cannot drift **[graft: shared limits fixture, incl. the
  256 KiB per-owner aggregate the bridge did not check]**.
- Only **changed** keys are sent per flush (not the whole map), coalesced to ≤ 4
  flushes/s per owner **[graft from operability]**.
- The client is the source of truth; the mirror shows what `values` reports.
- After each `hello`, the bridge sends every owner's `register` then a full
  `values` snapshot.
- Value encoding per element type is §9.1.

#### `result` — the reply to one app→client request

```json
{"type":"result","re":"d17","ok":true,"value":["8737899170"]}
{"type":"result","re":"d18","ok":false,"error":"[string \"Agent\"]:1: attempt to index nil with 'Character'"}
```

| Field | Rule |
| --- | --- |
| `re` | The request id (`^[A-Za-z0-9_-]{1,32}$`). |
| `ok` | Boolean. |
| `value` | Only when `ok` true. JSON ≤ 64 KiB; the bridge truncates to fit. |
| `error` | Only when `ok` false. String ≤ 4096. |

`value`: for `run`, an array of `tostring` of each returned value; for `invoke`,
the handler's return; for `set` and `loadout`, a short status string (§11).

### 5.3 App → client

#### `ping` — every 10 s (the app-to-bridge liveness check)

```json
{"type":"ping"}
```

The bridge replies to nothing; a `ping` simply resets the bridge's app-silence
timer, so the bridge notices a hung app **[fix: minimal had no app→bridge ping]**.

#### `run` — raw code

```json
{"type":"run","id":"d17","name":"Agent","code":"return game.PlaceId"}
```

- `id` `^[A-Za-z0-9_-]{1,32}$`. `code` 1–524288 bytes. `name` optional, 1–40
  printable chars (the chunk name).
- The bridge `loadstring(code, "=" .. name)`; a compile error → `result ok=false`.
  Otherwise the chunk runs in a new thread under `pcall`; `result` on return.

#### `invoke` — press an action

```json
{"type":"invoke","id":"d19","owner":"Ethos","action":"hatch","input":{"egg":"Grass Egg","amount":50}}
```

- `input` an object (or `[]`) ≤ 64 KiB. The app checks `input` against the
  registered inputs before sending (no unknown keys, right type, `min ≤ v ≤ max`,
  `choice` from `options`). The bridge calls `handler(input)`; unknown owner or
  action → `result ok=false error="Not registered"`.

#### `set` — set a schema element (live mirror / MCP "set an option")

```json
{"type":"set","id":"d20","owner":"Ethos","key":"WalkSpeed","value":24}
```

- `value` non-null JSON ≤ 64 KiB. The app sends `set` only for ids in that
  owner's schema that are not `locked` and are settable (§9.1), and
  **only after validating the value against its stored copy of the element**
  (type, bounds, option membership) — the MCP/UI boundary is a trust boundary
  **[graft from minimal-ui]**.
- The bridge calls the owner's `onSet(key, value)` → `true` or `false, reason`,
  which becomes `result`. A button is pressed by `set` with no `value`
  (`value` absent is valid only for a button). The new value echoes back via
  `values`.

#### `loadout` — applies the alt's loadout

Sent once, right after a `hello` with `loadout:false`, only if the account has a
loadout.

```json
{"type":"loadout","id":"d21",
 "script":"script_key = \"KEY_FROM_VAULT\"\nloadstring(game:HttpGet(\"https://api.luarmor.net/files/v3/loaders/LOADER_ID.lua\"))()",
 "ethos":{"config":{"local":"Farm"},"addons":["Auto parry"],"hideWindow":true}}
{"type":"loadout","id":"d21","ethos":{"config":{"cloud":"cfg_8f2c41e0-77aa-4d1b-9c55-0a1b2c3d4e5f"}}}
{"type":"loadout","id":"d21","script":"print('hi')"}
```

| Field | Rule |
| --- | --- |
| `script` | Optional. 1–524288 bytes. An Ethos preset fills in the loader and `script_key`. |
| `ethos` | Optional object; the app includes it only for a signed-in Ethos account. |
| `ethos.config` | Optional. Exactly one of `{"local": name 1–100}` or `{"cloud": id matching `^cfg_[0-9a-f-]{36}$`}` **[graft: validate the cloud id and do the kind check, not a nil-from-Model.settings check]**. |
| `ethos.addons` | Optional, ≤ 50 strings 1–100 chars. Listed add-ons are enabled; others untouched. |
| `ethos.hideWindow` | Optional boolean. |
| (whole) | At least one of `script`, `ethos`. |

Bridge order of work and the library-side apply order are §10 and §11. The app
never logs `script`, never echoes it in an MCP response, and `result` never
carries it.

---

## 6. Errors and close codes

| Code | Meaning | Sent by |
| --- | --- | --- |
| 1003 | Binary frame | app |
| 1007 | Not UTF-8 / not JSON | app |
| 1009 | Frame over its cap | app |
| 1013 | Send backlog over 4 MiB | app |
| 4000 | Client-silence timeout (20 s) | app |
| 4400 | Pre-auth message wrong for the state | app |
| 4401 | Bad proof, or pairing reset | app |
| 4408 | Handshake or `hello` deadline missed | app |
| 4409 | Duplicate `userId` (the **older** socket is closed) | app |
| 4426 | Handshake `v` is not 1 | app |

**Rules [graft + fix: a post-auth validator failure must not close the
connection, which otherwise loops close → reconnect → replay register → close]:**

- **Pre-auth:** the app sends only the close code, never an explanation (a reason
  frame is a lever for a fake app).
- **Post-auth, bad frame from the client:** the connection **stays open**. A bad
  `register`/`values` is answered with
  `{"type":"error","code":"invalid_register","ref":"<owner>"}` (the owner stays
  unregistered) or the single bad field is dropped; a bad request is answered
  with a `result ok=false`. Only a malformed *handshake* uses a 44xx close. This
  stops one oversized or drifted registration from taking `run`/`invoke` offline
  for that alt in a reconnect loop.
- **Handler errors** (action, `onSet`, run code, loadout script) never close the
  connection; they become `result ok=false`.
- **No automatic resend** of `run`/`invoke`/`set`/`loadout` after a disconnect,
  so nothing runs twice. Each pending request fails with
  "Disconnected; the outcome is unknown".
- Executors give `OnClose` no code (UNC), so close codes exist for the app log
  and the Lune tests; the board's diagnostics come from the `failed_auth`
  counter and the tracker, not from a reason the stub can read.

`error` frame (app → client, post-auth, connection stays open):

```json
{"type":"error","code":"invalid_register","ref":"Ethos","message":"schema[4]: slider min is above max"}
```

---

## 7. Reconnect and state machines

### 7.1 Stub loop

```
LOAD ── WebSocket/loadstring missing ───────────► EXIT (quiet)
LOAD ── bump __ethosBridgeGen; wait game.Loaded ─► LOOP (while it owns gen)
LOOP ─► CONNECT  connect fails ─────────────────► BACKOFF
CONNECT ─► BEGIN: hook OnMessage/OnClose, send auth.begin(Nc)
BEGIN ── valid auth.challenge in 10 s ──► PROVE: send auth.proof(Pc)
BEGIN ── else ──────────────────────────────────► CLOSE ► BACKOFF
PROVE ── valid auth.ok and Ps verifies ─► LOAD_BRIDGE: loadstring(source)
PROVE ── else ──────────────────────────────────► CLOSE ► BACKOFF
LOAD_BRIDGE ─► RUN: pcall(bridge, ctx) until the channel closes ─► CLOSE ► BACKOFF
BACKOFF: 2 s if the last session lasted > 60 s, else min(2*delay, 60 s), +-20% jitter ► CONNECT
```

The stub never stops retrying (there is no authenticated "stop forever" signal a
squatter could abuse). A stale stub costs one failed connect per minute, shown in
`failed_auth`.

### 7.2 Bridge (one run per connection)

```
START ── adopt/create getgenv().EthosBridge; re-run every EthosBridgeAttach[owner]
      ── send hello(loadout = __ethosBridgeLoadout == game.JobId),
         then every owner's register, then every owner's values snapshot, then status
OPEN  ── frame:
          validator fails ─► error (connection stays open), warn; drop the frame
          ping ─────────── note the time
          run|invoke|set|loadout ─► task.spawn handler; send result when done
      ── API change ─ debounce 250 ms ─► register / values (changed keys only)
      ── every 5 s ─► status
      ── no frame (incl. ping) from the app for 30 s ─► close ► END
      ── ctx.isClosed() ─► END
END   ── the API keeps working offline and queues nothing; state is replayed on the next hello
```

Requests in flight when the connection drops keep running; their results are
dropped.

### 7.3 Reconnect scenarios

| Scenario | What happens |
| --- | --- |
| App restart, same build | Sockets close; stubs retry (2–60 s, jittered). New app accepts; `hello.loadout` is true (the VM already applied one), so no loadout re-push. Registrations + values are replayed in full. |
| App update | Same, but the served source differs; the stub loads the new bridge on the next handshake (the source always matches the app build). |
| Teleport | New Lua VM; the stub runs again; `hello.loadout` is false, so the app pushes the loadout on the new server. A stale old socket for the same `userId` is closed by the new `hello` (newest wins). |
| Client freeze > 20 s | The app closes (4000), the board shows "unresponsive"; the stub reconnects when Lua resumes. |
| Stub re-run in one VM | The generation bump makes the old loop exit; one loop survives. |
| Pairing reset | Every connection closes (4401); running stubs fail the new proof and show under "old stub: rejoin these alts"; the saved-folder stub is rewritten, so a rejoin recovers. |
| App not running on join | The stub retries every ≤ 60 s; it connects when the app starts, and the loadout is pushed then. |

---

## 8. Public Lua bridge API

`getgenv().EthosBridge` exists once a bridge has loaded in this Lua VM. The data
lives on a root table; each bridge load reinstalls the methods on the same table
and a shared owner metatable, so handles a script already holds keep working
across reconnects and app updates. The token and any secret are never stored
here.

```lua
Bridge.version                          -- 1
Bridge.connected() -> boolean

local api = Bridge.open(owner: string) -> Owner
-- One handle per owner; opening the same owner again replaces its registrations.
-- Multiple owners coexist: a second script does NOT evict Ethos's mirror.

api:action(id, def?, handler?)          -- def {label, description?, inputs?}; nil def removes it.
                                        -- handler(input) -> (ok?, value?|reason); nil/true = ok, false,msg = fail, error = fail.
api:value(id, def?)                     -- declare a status-board value {label, unit?}; nil removes it.
api:update(values: {[string]: any})     -- merge live values (board values and schema element values).
api:schema(elements: {Element}?)        -- replace the live-mirror schema (flat list with path); nil clears it.
api:onSet(fn: (key, value) -> (boolean, string?))   -- the app set a schema element (or pressed a button: value nil).
api:onLoadout(fn: (ethos) -> ())        -- a loadout's ethos part; runs synchronously here if one is already pending.
api:close()                             -- sends an empty register for this owner.
```

- Changes are coalesced: `update` in a tight loop sends ≤ 4 `values` frames/s per
  owner; `schema`/`action` changes debounce at 250 ms. Calls work while
  disconnected; state is replayed after the next `hello`.
- **A no-op guard [graft]:** `update` drops a value equal to the last one sent
  (Fusion `isSimilar` on the wire), and the library's `onSet` path must not call
  `SetValue` when the value already equals the handle's value, because the
  library's `SetValue` fires `Callback`/`OnChanged` on every call (base.luau).
  Without the guard an agent or loadout re-setting `AutoFarm=true` re-runs the
  game callback.

**Load order (before or after the bridge), surviving a bridge swap** — every
script, including the library, uses the attach-registry idiom
**[fix: minimal dropped the Ethos loadout when the library loaded before the
bridge]**:

```lua
local env = getgenv()
env.EthosBridgeAttach = env.EthosBridgeAttach or {}
env.EthosBridgeAttach.Ethos = function(Bridge)
	local api = Bridge.open("Ethos")
	api:onLoadout(applyLoadout)   -- a pending loadout is delivered synchronously inside this call
	-- ... register schema, values, onSet ...
end
if env.EthosBridge then env.EthosBridgeAttach.Ethos(env.EthosBridge) end
```

The bridge calls each `EthosBridgeAttach[owner]` on load **and on every reload**
(re-running attach replaces the owner's registration, so attach functions must
be idempotent). Keying by owner means a re-executed script overwrites its own entry.

---

## 9. Live-mirror schema and value encoding

The mirror **is** the `schema` of the Ethos owner's `register`, its live values
the `values` frames, and its edits the generic `set`/`invoke`. There is no
separate `ui.*` message family — this is the smallest reconciliation of the two
mirror designs on top of the protocol's own messages. The library adapter
(`src/app/bridge.luau`) builds the schema from `registry.entries()`, one element
per non-`Internal` entry, keyed by the entry's Options id verbatim (e.g.
`WalkSpeed`, `@Auto parry/Enabled`) or a session key `~<n>` for entries without
an id (most buttons and text) — `mirror-registry`'s model.

### 9.1 Encoding per element type

"Set" = the element accepts `set` from the app.

| Type | `value` | Extras in `schema` | Set | Library decode |
| --- | --- | --- | --- | --- |
| Toggle | `true`/`false` | — | yes | as is |
| Slider | number | `min`, `max`, `step` | yes | `SetValue` (clamped, rounded) |
| Number | number | — (bounds default to ±inf, left off) | yes | `SetValue` |
| Range | `{"Min":n,"Max":n}` | `min`, `max`, `step` | yes | `SetValue` |
| Dropdown | string, or `false` for none; with `multi`, array in option order | `options`, `multi` | yes | `SetValue` (`cleanSet` accepts a list) |
| Segmented | string | `options` | yes | `SetValue` |
| Checklist | array in option order | `options` | yes | `SetValue` |
| Input | string; **absent when `secret`** | `secret` | yes (secret is write-only) | `SetValue` |
| Colorpicker | `"rrggbb"` (6 hex, no `#`) | — | yes | `Color3.fromHex` in `pcall` |
| Keybind | `{"Key":"F","Mode":"Toggle"}` | — | no | — (configs/loadouts still round-trip it via `Config.apply`) |
| PlayerPicker | string/`false`; array when `multi` | `multi` | no | — |
| Button | none | — | press via `set` with no `value` | `state.Fire`/`handle:Press()` |
| Text | none (content is `title`+`description`) | — | no | — |
| Progress | number | `max` | no | — |
| Stats, Table, Log, Steps | none | — | no | — (placeholder; live numbers go via `values`/the board) |
| any other type | up to 8 KiB, or none | — | no | — (read-only "Open in game") |

- Value encoding reuses `Config.encode`/`CODECS` (`src/ui/config.luau`):
  Colorpicker→hex, Keybind→`{Key,Mode}`, `nil`→`false`. The mirror, configs,
  cloud configs and loadouts therefore share one value form.
- Range and Colorpicker are settable (unlike `mirror-minimal-ui`, which made them
  read-only — a flaw). Keybind/PlayerPicker stay read-only (rebinding from the
  desktop is rarely useful; the live player list is not on the wire).
- Sets are arrays on the wire, not `{[v]=true}` maps, so an empty set is `[]` not
  an ambiguous `{}`/`[]`.

### 9.2 Both-way value flow

- **Game → app.** Each tracked entry has one Fusion `Computed` + `Observer` over
  its Value, Lock, Title, Description, Visible, Mode and option list. On change
  the key is marked dirty and flushed (changed keys only) within 100 ms as a
  `values` frame, with the row rebuilt at flush time so the newest value wins. A
  value change is a cheap `values` merge; a structure/lock/title/options change
  resends that owner's `schema` (debounced). JSON dedupe drops a value equal to
  the last sent.
- **App → game.** `set` runs through the element's own `SetValue`, so app edits
  behave like clicks (callbacks fire, locks refuse, autosave records). The app
  keeps **one `set` in flight per element, latest value wins** (no timers): while
  one is in flight it holds only the newest wanted value and sends it when the
  reply arrives, so a slider drag runs at the alt's real round-trip rate (even at
  5 FPS) and always ends on the final value **[graft from minimal-ui]**. Before
  the bridge sends the reply to a `set`, it flushes every dirty value of that
owner (a button press changes other rows), so the
  control never flickers back **[graft]**.
- **Echo/conflict.** The game is authoritative (last write wins). While a control
  is dragged in the app, incoming values update the cache but not the held
  control. On `ok:false` the app toasts the reason; the library resends the row
  and the control snaps to the real value.

### 9.3 Structure, locks, visibility

- `registry.subscribe` fires on add/remove; the adapter coalesces with one
  `task.defer(sync)`. New entries become `schema` elements; removed ones drop
  from `schema`. The subscribe callback runs before `Section.Destroy` cleans the
  row scope, so each row's Computed/Observer lives in its own scope destroyed in
  that callback — nothing ever `use`s a destroyed state.
- `locked` carries the reason (e.g. from `BindAccess` "A paid key is required.").
  The app draws the control disabled with the reason; the library refuses writes
  anyway (`SetValue` checks the lock, a button checks `IsLocked`).
- `hidden: true` (`DependsOn`, `SetVisible(false)`, a hidden owner) is not drawn
  by the mirror but is still settable by the agent, matching the in-game agent.

### 9.4 Masked inputs (secret)

- `handle.Masked = config.Masked == true` is read in `input.luau`
  (`config.Masked` at `input.luau:66`; `RamPassword` is a real masked Option at
  `accountManager.luau:181`). A masked input's element carries `secret: true` and
  **no value**. The validator rejects an element with both `secret` and a value,
  on both sides. The app shows an empty password field with a Set button; `set`
  works and the row never echoes the value. This keeps keys and the Account
  Manager webserver password out of `values` and out of MCP `status` output
  **[fix: snapshot, minimal-ui and registry's base all leaked these]**.

### 9.5 Size

~156 bytes per element (measured: 98–235 B). The v2 example window (~40 elements)
is ~6 KB; a large script (~600) ~92 KB. A `register` with > 100 elements is split
into frames of ≤ 100 elements, and the app builds the new schema and swaps it in
atomically, so a reconnect never shows a half-filled mirror
**[graft: frame split + atomic swap; fix: snapshot's 34 KB single unsplit frame]**.
Every part but the last carries `"more": true`. The app concatenates the parts'
`actions`, `values` and `schema`, takes `title` from the first part, checks the
caps and id uniqueness on the whole registration, and swaps it in when the part
without `more` arrives. The 2000-element cap holds per frame and per
registration.

---

## 10. Window-level state (hidden, add-ons, configs)

These are **not** schema elements; they ride the owner's generic actions and
values **[graft from registry: reuse the generic action/value machinery, add no
new window-control concept]**.

- Action **`ethos.apply`** with input
  `{hidden?: bool, addons?: {[name]: bool}, config?: string, cloud?: string}`
  (at least one field; `config`/`cloud` mutually exclusive; `config` passes
  `Config.cleanName`; `cloud` matches `^cfg_[0-9a-f-]{36}$`; `addons` ≤ 50).
- Values **`ethos.hidden`** (bool), **`ethos.config`**
  (`{current, list}` from `configs.Current()`/`List()`, republished on
  `configs.OnChanged`), **`ethos.addons`**
  (`[{name, enabled, status}]` from `window.Addons.Items`).
- The mirror header draws a Hide switch, a Config select + Apply, a Cloud id
  field + Apply, and an Add-ons list of switches (each showing its status; "Needs
  review in game" for `review`). Each calls `ethos.apply` with one field. The app
  cannot approve add-on code — the review gate stays in game.

**Hide window.** `ethos.apply{hidden=true}` disables the root `EthosV2` ScreenGui
(`Enabled=false`, or `Visible=false` when the root is a Frame), so the window,
toasts, launcher and dock all hide ("built but invisible", plan). The window keeps
its open state. The adapter also edits `src/app/window/visibility.luau`
`minimize()` so the in-game toggle key **un-hides** a hidden root (sets hidden
false and opens), instead of flipping `open` under a disabled ScreenGui where
nothing visible happens **[graft + fix: a hidden root could not be recovered in
game in registry and minimal-ui]**.

---

## 11. Loadout application order

The task phrases the loadout as "startup script first, then config, add-ons,
hide". The **correct apply order** reorders the ethos part for correctness, which
this spec adopts and justifies (add-on options only exist after mount, and a hide
applied after `Init` flashes the window):

**Bridge, on a `loadout` frame:**
1. Set `getgenv().__ethosBridgeLoadout = game.JobId` immediately, so a reconnect
   mid-script never re-runs it (and `hello.loadout` reports true next time).
2. Store `ethos` as the pending loadout and hand it to owner `Ethos`'s
   `onLoadout` (synchronously inside `onLoadout` if the library registers after,
   or at once if it already registered).
3. Run `script` exactly as `run` would; send `result` when the chunk returns,
   with `value` = `{"script":"ran"}`.

**Library `onLoadout(ethos)`:**
1. **Startup script** has already run (step 3 loaded the library, which is why
   `onLoadout` is now registered).
2. **Hide before `Init`.** If `ethos.hideWindow`, disable the root now, inside
   `V2:CreateWindow` before `Window:Init` opens the card — the window never
   flashes.
3. **Add-ons after `Init`/`Mount`, before the config.** `Addons.Enable(name)` for
   each in `ethos.addons` (it yields until loaded; a review/error is reported as
   is). Add-ons first so their `@Name/` controls exist before a config sets them.
4. **Config after add-ons.** To avoid applying every autoload toggle and then the
   loadout toggle (which fires callbacks twice and can start-then-stop a farm),
   the adapter makes `Window:Init` load the loadout config **instead of** the
   autoload: it wraps `configs.LoadAutoload` so, when a loadout config is pending,
   `Init` loads that config, else the normal autoload
   **[graft + fix: registry/snapshot applied the loadout config after autoload,
   firing saved callbacks twice]**. `{local}` → `configs.Load(name)`; `{cloud}` →
   `profiles:getConfig(id)` kind check (`== "config"`), then
   `profiles:downloadConfig(id, cb)` → `Model.settings(json)` →
   `Installs.applySettings(V2.Options, snapshot, nil, LoadOrder)`, with no install
   record (a per-join re-apply would flood Library › Yours). The cloud call uses
   the library's own key (ADR 0006); the app never handles config JSON.
5. **Report the outcome** so a dropped result is never silent
   **[graft + fix: registry's `task.spawn(apply)` threw away the add-on review
   and missing-config errors]**: the `onLoadout` result flows as a one-line
   value `@loadout.status` (e.g. "Applied Farm, 1 add-on" or "Config Farm not
   found" or "Auto parry needs review"), and the `loadout` `result` summarises the
   first failure.

A re-executed window starts visible (a fresh VM, run on purpose); loadouts apply
on join.

---

## 12. Stats

Generic stats (`@stats.playtime`, unit `s`, and `@stats.executions`) are declared
in the Ethos owner's `register.values` and pushed as live values through
`values`. They also go to the backend directly with the license key (ADR 0006),
so lifetime totals accrue even for users who never run the app. The status board
reads the `values` copies; the backend holds the authoritative totals. No stat
travels through the app for the backend, and no raw code ever goes to the backend.

---

## 13. Desktop agent (MCP) boundary

| MCP tool | Bridge message | Source |
| --- | --- | --- |
| list alts | none | accounts + tracker + connection map |
| status | none | last `status`, `values`, schema, tracker; **secret values excluded** |
| run an action | `invoke` | |
| set an option | `set` (owner defaults to `Ethos`) | resolves id or `tab › section › title`; Rust validates the value against the stored element first |
| run code | `run` | |
| screenshot | none | the app's Windows.Graphics.Capture pipeline |

Two rules belong to the bridge's security:

1. **The MCP endpoint is a second way into `run`.** Prefer a **stdio** MCP server
   that the agent spawns as its own child; it opens no socket. If it must be HTTP
   on loopback, it gets the same `Origin` 403 and a **fresh random bearer token
   per agent session**, passed in ACP `session/new` `mcpServers[].headers`.
   Otherwise every A1/A3 defence is bypassed. (The stdio child still needs an
   authenticated channel back to the app core — it reaches the bridge only
   through the app's internal `bridge.dispatch`, never a socket of its own.)
2. **Values, labels and schema text come from game scripts, so they are untrusted
   data to the agent** (prompt injection). MCP results wrap them as data. `run`,
   `invoke` and `set` always go through the ACP permission request; the app never
   auto-approves them.

The app exposes one internal interface the board, the mirror and MCP all read
(never the wire): `bridge.alts()`, `bridge.dispatch(targets, request, source)`,
`bridge.wait(id, max)`, `bridge.dispatch_get(id)`. **Dispatch records** hold one
outcome per target (`ok|error|timeout|lost|skipped|busy`); `status({dispatch})`
reads late results, and `set` coalesces latest-value-wins per `(alt, owner, key)`
**[graft from operability]**.

---

## 14. Fixture catalogue

Shared files `bridge/fixtures/ws/<group>/<name>.json`,
`bridge/fixtures/mirror/<name>.json` and `bridge/fixtures/ws/limits-valid.json`,
each `{"id":"bridge.<group>.<name>","valid":bool,"value":...}` where `<group>` is
the file's folder (`crypto`, `auth`, `c2a`, `a2c`, `mirror`, `ws`) — the shape of
the existing `docs/fixtures/ws` files. The name ends in `-valid` exactly when `valid`
is true; both suites assert that and that `id` matches the path. **Rust**
(`src/ethos/bridge/protocol.rs` tests) reads them from
`CARGO_MANIFEST_DIR/../bridge/fixtures`; **Lune** (`bridge/tests/fixtures.luau`)
reads the same files with `@lune/fs`, its JSON shim encoding `{}` as `[]`. No sync
script and no manifest — both readers are in one repo. Megabyte size-limit cases
are generated in the tests, not stored. Both suites also assert their limit
constants equal `ws/limits-valid.json` **[graft: the sanitiser and the validator
cannot drift, incl. the 256 KiB per-owner aggregate]**.

**Who checks what:** the *receiver* of a direction judges every fixture (valid
accepted, invalid rejected); the *sender* (the real stub/bridge in Lune, the real
app-emit in Rust) proves it emits each valid fixture deep-equal (golden tests)
**[graft from minimal: sender-side golden tests]**.

**Value shapes.** Key order never matters.

- `ws/auth`, `ws/c2a`, `ws/a2c` and `mirror/values-*`: `value` is the decoded
  frame.
- `set-*` (in `ws/a2c` and `mirror`): `{"element": <stored element>, "frame":
  <set frame>}`, because whether a value is required, in range or an option
  depends on the stored element (§5.3).
- `mirror/row-*`: `{"element": <schema element>, "value": <its value>}`, with
  `value` left out when the element carries none (secret Input, Button, Text).
  `mirror/schema-all-types-valid` is a `register.schema` array; `mirror/apply-*`
  is the `ethos.apply` input (§10).
- `ws/crypto`: `sha256` is `{kind, messageHex, expected}` and `hmac` is
  `{kind, keyHex, messageHex, expected}`, bytes as lowercase hex. `handshake` is
  `{kind, token, port, nc, ns, source, sourceHash, clientProof, serverProof}`,
  valid exactly when `sourceHash` is `H(source)` and both presented proofs equal
  the §3.2 proofs for those inputs.
- `ws/limits-valid`: a flat map from a camelCase cap name to a positive integer
  (`…Bytes`, `…Seconds`, `…Ms`, or a count).
- An empty map is written `[]`, never `{}` (what `JSONEncode` emits, and Lune
  cannot tell them apart); golden deep-equal treats `{}` and `[]` as equal.
- Absent means the key is left out. `null` appears only in `values-null-invalid`
  and `set-null-value-invalid`. Lune decodes `null` as absent, so it sees the
  `set` case as a missing value (still invalid) and the `values` case as an empty
  map; Rust, its receiver, judges that one.
- JSON has no NaN: `row-slider-nan-invalid` carries the string `"NaN"`, and
  non-finite numbers are generated in tests.
- A verdict covers the whole value: a `register` with one bad element is
  `-invalid`, though the app still draws its good elements (§5.2).

### 14.1 `ws/crypto/`

| Name | Proves |
| --- | --- |
| `sha256-empty-valid`, `sha256-abc-valid`, `sha256-two-block-valid`, `sha256-1000a-valid` | SHA-256 padding at 0, 3, 56-ish and many blocks (FIPS 180-2). |
| `hmac-rfc4231-1..4-valid`, `-6-valid`, `-7-valid` | RFC 4231; cases 6/7 use a 131-byte key (key hashing). |
| `handshake-valid` | the §3.2 worked vector: `Pc`, `Ps`. |
| `handshake-wrong-port-invalid` | `Ps` with port 51735 → reject (relay). |
| `handshake-swapped-nonces-invalid` | `Pc` with `Nc`/`Ns` swapped. |
| `handshake-reflected-proof-invalid` | `Pc` offered as `Ps` (reflection). |
| `handshake-changed-source-invalid` | `Ps` for source + trailing space (code swap). |
| `handshake-uppercase-proof-invalid` | `Ps` uppercased. |
| `handshake-v2-label-invalid` | `Ps` with label `ethos-bridge/2 server`. |

### 14.2 `ws/auth/` — pre-auth messages

`begin-valid`; `begin-v2-invalid`; `begin-missing-v-invalid`;
`begin-short-nonce-invalid`; `begin-uppercase-nonce-invalid`;
`begin-identity-invalid` (extra `userId` — identity before auth refused);
`challenge-valid`; `challenge-newline-nonce-invalid` (nonce `32hex \n 31hex`,
transcript injection); `proof-valid`; `proof-non-hex-invalid`;
`proof-short-invalid`; `ok-valid`; `ok-missing-proof-invalid`;
`ok-source-not-string-invalid`; `ok-empty-source-invalid`; `not-object-invalid`;
`unknown-type-invalid`.

### 14.3 `ws/c2a/` — post-auth client→app

`hello-valid`; `hello-loadout-true-valid`; `hello-studio-valid` (`jobId:""`,
`placeId:0`); `hello-missing-user-id-invalid`; `hello-user-id-zero-invalid`;
`hello-user-id-fraction-invalid`; `hello-user-name-too-long-invalid`;
`hello-user-name-space-invalid`; `hello-unknown-field-invalid`;
`status-valid`; `status-teleporting-valid`; `status-heartbeat-valid`;
`status-bad-state-invalid`; `status-fps-negative-invalid`;
`register-valid` (the §5.2 example: every piece, path-based schema);
`register-unknown-element-type-valid`; `register-close-valid` (empty lists);
`register-more-valid` (a split part, §9.5);
`register-duplicate-id-invalid`; `register-owner-empty-invalid`;
`register-owner-41-invalid`; `register-owner-control-char-invalid`;
`register-id-control-char-invalid`; `register-101-actions-invalid`;
`register-input-bad-type-invalid`; `register-input-duplicate-key-invalid`;
`register-choice-without-options-valid`; `register-default-too-big-invalid`;
`register-path-depth-5-invalid`; `register-secret-with-value-invalid`;
`register-2001-elements-invalid`; `values-valid`; `values-empty-array-valid`;
`values-null-invalid`; `values-too-large-invalid`; `values-bad-owner-invalid`;
`values-owner-aggregate-over-256k-invalid`; `result-ok-valid`;
`result-error-valid`; `result-missing-re-invalid`; `result-ok-with-error-invalid`;
`result-error-too-long-invalid`; `run-from-client-invalid` (direction check);
`extra-mac-field-invalid` (a stray `mac` key — there is no per-frame MAC).

### 14.4 `ws/a2c/` — post-auth app→client

`ping-valid`; `run-valid`; `run-no-name-valid`; `run-empty-code-invalid`;
`run-name-too-long-invalid`; `invoke-valid`; `invoke-empty-input-array-valid`;
`invoke-missing-owner-invalid`; `invoke-input-string-invalid`; `set-valid`;
`set-button-no-value-valid`; `set-null-value-invalid`; `set-missing-value-invalid`;
`loadout-valid` (script + local config); `loadout-cloud-valid`;
`loadout-script-only-valid`; `loadout-hide-only-valid`;
`loadout-both-configs-invalid`; `loadout-empty-invalid`;
`loadout-cloud-id-bad-chars-invalid`; `loadout-addons-not-strings-invalid`;
`loadout-51-addons-invalid`; `error-valid` (invalid_register with `ref`);
`result-from-app-invalid` (direction check).

### 14.5 `mirror/` — schema rows, values, edits (library producer vs validator)

The library spec builds a window with every element type and its `register.schema`
output becomes `mirror/schema-all-types-valid`, synced into the shared tree like
`test/Support/fleetFixtures.luau`, so the **Lua producer**, not only the
validator, is held to the contract **[graft from snapshot]**.

Valid: `row-toggle-valid`, `row-slider-valid`, `row-number-valid`,
`row-range-valid`, `row-dropdown-valid`, `row-dropdown-none-valid` (`false`),
`row-dropdown-multi-valid`, `row-dropdown-multi-empty-valid` (`[]`),
`row-segmented-valid`, `row-checklist-valid`, `row-input-valid`,
`row-input-secret-valid` (no value), `row-colorpicker-valid`, `row-keybind-valid`,
`row-playerpicker-valid`, `row-button-session-key-valid` (`~3`), `row-text-valid`,
`row-progress-valid`, `row-addon-key-valid` (`@Auto parry/Enabled`),
`row-locked-hidden-valid`, `row-category-path-valid` (path of 2),
`row-subtab-path-valid` (path of 4), `row-unknown-type-valid`,
`schema-all-types-valid`, `values-mirror-valid`, `set-valid`,
`set-button-no-value-valid`, `apply-hidden-valid`, `apply-loadout-valid`
(addons+config+hidden), `apply-cloud-valid`.

Invalid: `row-toggle-string-invalid`, `row-slider-nan-invalid`,
`row-colorpicker-hash-invalid` (`#ff8800`), `row-keybind-mode-invalid`,
`row-input-secret-value-invalid`, `row-path-empty-invalid`,
`row-path-depth-5-invalid`, `row-options-501-invalid`, `row-key-empty-invalid`,
`row-title-long-invalid`, `row-value-9kb-invalid`, `set-missing-value-invalid`,
`set-value-out-of-range-invalid` (a trust-boundary case: a `set` value outside the
stored element's bounds), `apply-empty-invalid`, `apply-config-and-cloud-invalid`,
`apply-cloud-bad-id-invalid`, `apply-config-bad-name-invalid`,
`apply-addons-51-invalid`.

---

## 15. Security test plan (mapped to the done items)

Harnesses: **Rust integration tests** (`src/ethos/bridge/tests.rs`) start the
real server on a random port with a test token and a tiny test bridge source,
acting as stub/attacker with `tokio-tungstenite` and raw `TcpStream`;
**Lune stub tests** run the assembled stub in a sandbox (`WebSocket.connect` over
`net.socket`, `loadstring` recording every call, a `net.serve` fake app, an
Lune pinned at 0.10.4, where a `net.serve` handler's `socket:close()` works (it
throws in 0.10.5); `net.serve` upgrades without calling the request handler, so
the `Origin` cases run against the Rust server, with a Lune client sending the
header over `net.tcp`); a **Rust↔Lune cross test**
spawns `lune run bridge/tests/stub_e2e.luau -- <port> <token>` against the real
server and **fails, not skips, if Lune is missing**.

| Done item (plan checklist 2) | Tests |
| --- | --- |
| **Listener binds only 127.0.0.1** | S2: `local_addr().ip() == 127.0.0.1`; connecting via the LAN IPv4 and via `[::1]` is refused. |
| **Upgrade with Origin refused** | S1: `Origin: https://evil`, `Origin: null`, `Origin: http://127.0.0.1:<port>` each get HTTP 403, never 101; the value is logged. |
| **A client without the token gets nothing** | S4: wrong-token stub, and `hello`/`register` before auth, and `auth.proof` before `auth.begin` → at most one frame (`auth.challenge`), then 4401/4400; never `auth.ok`, never the source; `failed_auth += 1`. |
| **A fake app squatting the port cannot make a real bridge run code** | S7a no-token `auth.ok` with a random proof → `loadstring` recorder empty, nothing printed, stub backs off. S7b replay of a recorded challenge+ok → no `loadstring` (new `Nc` breaks `Ps`). S7c relay to the real server on another port → app 4401 (port check), no `loadstring`. S7d code swap (right proof, one source byte changed) → no `loadstring` (`H(source)` check). S7e protocol abuse (ok before proof, two challenges, `\n` nonce, 1 MiB+1, 300 frames) → no `loadstring`. S7f reflection (stub's `Pc` echoed as `Ps`) → no `loadstring`. S7g silence → gives up at 10 s. S7h identity: the frames the fake received have exactly `{v,type,nonce}` and `{v,type,proof}` — no alt identity. |
| **Fixtures pass on the Rust and Lua sides** | S15: every `ws/*` and `mirror/*` fixture; every `-valid` accepted and emitted deep-equal, every `-invalid` rejected, on both Rust and Lune; both suites assert their limits equal `limits-valid.json`; the cross test round-trips a real `run`. |

Additional hardening tests: S3 no port stealing (`SO_REUSEADDR` second bind and
`0.0.0.0` bind both fail; a client still reaches the app); S5 slowloris/idle caps
(5 s deadline; 9th unauth dropped; a real handshake succeeds after idlers time
out); S6 oversized/malformed frames (1009/1003/1007, memory bounded); S8 replay
against the app (recorded `auth.begin`+`auth.proof` on a new connection → 4401);
S10 the token never leaves the stub (not in any frame, log line, `ctx`, or a deep
walk of `getgenv()`); S11 stub file ACL (only user SID, SYSTEM, Administrators
remain); S12 quiet exit (no `WebSocket`/`loadstring` → returns, no thread, no
output); S13 one stub per VM (the generation bump leaves one loop); S14 pairing
reset (every connection 4401, old token's proofs fail, stub rewritten); S16 no
secrets in logs (a loadout `script_key` appears only as a length); S17 constant-
time compare (`subtle::ct_eq`, code review); S19 secret inputs (a masked input's
value is in no `values` frame and no MCP `status`); S20 post-auth validator
failure keeps the connection open (a bad `register` → `error`, not a close, and
`run` still works) — the reconnect-loop fix; S21 real executor (manual, handoff):
Potassium joins, the upgrade log shows no `Origin`, the handshake completes,
`hello` links to the tracker, `run` round-trips, and a 512 KiB `run` and a
500-element `register` encode under the frame cap (if not, lower the `run`/
`loadout` caps to 256 KiB).

---

## 16. Deliberately not in this design

- **Per-frame MAC and encryption** (§1.4): connection authentication + exclusive
  bind + port/source-bound proofs + loopback integrity cover the in-scope threat
  model. Upgrade path: encrypt-then-MAC in the served bridge, no stub change.
- **`seq` numbers:** TCP orders frames; with no per-frame MAC they add no
  security.
- **A token per alt, scopes, lockouts, a `Host`/subprotocol check:** every script
  in a client is equally trusted; one token per PC matches the plan; `Origin` +
  token suffice.
- **A separate `ui.*` message family:** the mirror rides `register`/`values`/
  `set`.
- **`kid`/`MIN_STUB_V` version skew machinery:** Reset pairing + the
  `failed_auth` counter cover a stale stub; the bridge source always matches the
  app build.
- **Mirroring Table/Stats/Log/Steps content, setting keybinds/player-pickers from
  the app, install records for bridge-applied cloud configs.**
