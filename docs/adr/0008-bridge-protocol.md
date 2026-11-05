# 0008: Bridge protocol — handshake and live-mirror model

Status: accepted (2026-11-05)

Extends ADR 0006 (the app reaches its clients over a local bridge, not the
backend) with the concrete v1 wire protocol. The full spec is
`docs/bridge-protocol.md`. This ADR records the two decisions that shaped it
and the options rejected.

## Context

The bridge is the seam between the Ethos library and the app, and the only path
for running code on a client. The fixed constraints: a loopback-only WebSocket on
a port the app picks; any upgrade carrying `Origin` refused; both sides prove the
pairing token; a tiny stub in autoexec that loads the full bridge from the app;
one JSON contract tested in Rust and Lune; the smallest complete design. Five
competing designs were written and judged. The protocol panels split between a
per-frame-MAC design (`protocol-security`) and a connection-only design
(`protocol-minimal`); the mirror panels split between one-row-per-registry-entry
(`mirror-registry`) and snapshot-plus-deltas (`mirror-snapshot`).

## Decision 1: the handshake, and connection-level authentication

The handshake is **client-first and identity-free**: the stub sends only a nonce
(`auth.begin`), the app answers with its nonce (`auth.challenge`), the stub proves
the token (`auth.proof`), and only then does the app answer with its proof and the
bridge source (`auth.ok`); identity (`hello`) follows after the server proof
verifies.

- Client-first avoids the lost-first-frame race an executor's `OnMessage` creates
  (reproduced in two prototypes; it broke the server-first `protocol-operability`
  design).
- Identity-free means a squatter learns no alt identity.
- Both proofs are `HMAC-SHA256(token, "ethos-bridge/1 <role>\n" .. port .. "\n"
  .. Nc .. "\n" .. Ns)`, and the **server proof also binds `H(served source)`**.
  Binding the dialled port defeats a relay on another port; binding the source
  defeats code substitution.

After the handshake, **frames carry no per-frame MAC** (and no `seq`). The
connection is authenticated once. This is sound because three things hold
together: `SO_EXCLUSIVEADDRUSE` is set before `bind` (no second socket can take
the port), the proofs bind the port and the source, and injecting into an
established loopback TCP stream requires admin/kernel, which is out of scope (a
same-user process already has the token). This is `protocol-minimal`'s thesis
hardened with `protocol-security`'s crypto binding. It keeps the design the
"smallest complete" one the plan requires and avoids the unmeasured ~33 ms-per-
512 KiB cost of signing every frame in pure Luau.

A leaked token is handled by **Reset pairing** (new token, rewrite the stub, close
every connection). The stub file's ACL is restricted to the owner, SYSTEM and
Administrators.

### Options rejected

- **Per-frame MAC on every frame (`protocol-security`'s wire):** rejected as
  beyond the smallest-complete design once the port and source are bound into the
  handshake and the exclusive bind is set; it adds a frame format, a key schedule
  and real per-frame CPU for no in-scope gain. Kept as the documented upgrade path
  (encrypt-then-MAC in the served bridge) if the bridge ever leaves loopback.
- **Server-first handshake (`protocol-operability`):** rejected; it loses its
  first frame to the executor `OnMessage` race.
- **Proofs that omit the port or the source (`protocol-operability`):** rejected;
  they allow a token-less relay on a stale port to substitute code — a code-
  execution hole that breaks a fixed constraint.
- **Identity in the first frame (`protocol-minimal`, `protocol-operability`):**
  rejected; it leaks which account is on which server to an unauthenticated
  squatter.
- **`kid`/`MIN_STUB_V` version-skew machinery (`protocol-operability`):**
  rejected as not smallest-complete; Reset pairing plus a failed-proof counter
  cover a stale stub, and the served bridge always matches the app build.

## Decision 2: the live-mirror model

The mirror is **one element per non-internal registry entry**
(`mirror-registry`), carried **inside the protocol's own `register` (schema),
`values` and `set`/`invoke` messages** rather than a separate `ui.*` family.
Schema elements are a flat list, each with a `path` from `Registry.place`, so the
library's categories and sub-tabs survive. Value changes are cheap `values`
merges; structure/lock/title changes resend that owner's schema (debounced). Edits
run through the element's own `SetValue`, so they behave like in-game clicks.

Grafted fixes adopted into the model: never send masked-input values (a `secret`
flag, validator rejects secret+value); the loadout config replaces the autoload
(wrap `LoadAutoload`) so toggle callbacks fire once; a no-op guard so a re-set
value does not re-fire a game callback; the in-game toggle key un-hides a hidden
root; latest-value-wins with one `set` in flight per element; the Rust side
validates a `set` value against its stored element before sending (MCP trust
boundary); one owner per handle so a second script cannot evict the Ethos mirror;
`register` frames split at 100 elements with an atomic swap; the loadout outcome
reported as a value.

### Options rejected

- **Snapshot + patch deltas with polling (`mirror-snapshot`):** rejected; two
  update paths with "absent means default vs unchanged" rules, a 0.1 s poll on
  every alt, a 34 KB unsplit snapshot frame, and (in its base) a masked-value
  leak. Its good ideas (no-op guard, un-hide toggle, atomic swap, the library's
  own output as the golden fixture) are grafted in.
- **A separate minimal `ui.*` message family (`mirror-minimal-ui`):** rejected as
  redundant with `register`/`values`/`set`; its over-restrictive mapping
  (read-only Range/Colorpicker, dropped Text, masked leak) was also a flaw. Its
  latest-value-wins pacing, flush-before-reply and trust-boundary value check are
  grafted in.
- **A fixed tabs→sections schema tree (`protocol-security`):** rejected; it drops
  the library's categories and sub-tabs. Replaced by the path-based flat schema.

## Consequences

- One wire protocol with no per-frame MAC and no mirror-specific message type —
  smaller to build and test in Rust and Luau, and within the plan's one-week
  phase-1 budget.
- A loopback sniffer that installs Npcap without admin capture could read a
  loadout `script_key`; this is accepted (a same-user process already has the
  token) and has a no-stub-change upgrade path.
- The library gains one app-layer adapter (`src/app/bridge.luau`) plus small
  element-builder field exposures; it holds no transport and no token.
- The MCP endpoint is authenticated separately (stdio child, or HTTP on loopback
  with a per-session bearer and the same `Origin` rule), because it is a second
  way into `run`.
