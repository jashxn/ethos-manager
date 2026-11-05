# Context

Glossary for Ethos Manager. Wider terms (Ethos library, add-ons, cloud configs) are defined in the
Ethos-Suite-Library CONTEXT.md.

- **Account**: a Roblox account saved in the app, with its cookie in the vault.
- **Alt**: an account the user runs alongside their main, usually many at once.
- **Client**: one running Roblox player process (RoALT's instance tracker).
- **Ethos account**: the user's Discord-identified account on the Ethos backend. Paid and trial
  keys unlock the Ethos layer; ad-tier and missing keys do not.
- **Ethos layer**: the parts that need an Ethos account: cloud configs, add-ons list, loadout
  presets, stats, multi-PC.
- **Bridge**: the local WebSocket between the app (server, 127.0.0.1 only) and the Lua running in
  each client. See `docs/bridge-protocol.md`.
- **Stub**: the small file in the executor's autoexec folder. It proves it holds the pairing token,
  checks the app's proof and only then loads the served bridge.
- **Pairing token**: the per-PC secret shared by the app and the stub. Reset pairing replaces it.
- **Served bridge**: the full bridge Lua the app sends after the handshake.
- **Owner**: a named registrant on the bridge (a script, or `Ethos` for the library). Each owner
  has actions, values and a schema.
- **Schema / live mirror**: the Ethos owner's list of UI elements, drawn in the app and kept in
  sync both ways.
- **Loadout**: what an alt runs when its client joins: a startup script, and for Ethos users a
  config, add-ons and whether the window is hidden.
- **Status board**: the app's live view of connected clients.
- **Device**: one PC running the app, with its own device ID. **Roster**: a device's list of
  alts and their live status, shared read-only with the user's other devices.
- **Desktop agent**: the in-app chat that drives an ACP agent (OpenCode, Claude Code, Codex) with
  the app's MCP tools for alts.
