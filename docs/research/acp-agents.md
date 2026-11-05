# ACP agents research (Ethos Manager)

All sources read on 2026-11-05 unless noted.

## 1. Rust crate `agent-client-protocol`

**Question:** Version, MSRV, client API, spawning, streaming, Send/LocalSet.

**Answer:** v5.0.0 (published 2026-11-02), edition 2024, MSRV 1.88.0. The 5.x API is NOT the old `ClientSideConnection` + `Client` trait. It is a builder: `agent_client_protocol::Client.v1().on_receive_notification(..).on_receive_request(..).connect_with(agent, |cx| async {..})`. Agents are spawned with `AcpAgent` (feature `process`).

**Details**
- Repo moved: `agentclientprotocol/rust-sdk`, crate at `src/agent-client-protocol`. Workspace `edition = "2024"`, `rust-version = "1.88.0"`.
- Features: `process` (spawn subprocess; pulls async-process, windows-sys on Windows), `stdio`, `unstable_*` (e.g. `unstable_mcp_over_acp`, `unstable_subagents`), `unstable_protocol_v2`. Default features: none.
- Spawn: `AcpAgent::from_str("npx -y @agentclientprotocol/claude-agent-acp")` or JSON `{"command":..,"args":[..],"env":{..}}`; builder `AcpAgentConfig::new(cmd).arg(..).env(k,v)`.
- Flow (from `examples/yolo_one_shot_client.rs`):
  - `connection.send_request(InitializeRequest::new(ProtocolVersion::V1)).block_task().await?`
  - `NewSessionRequest::new(cwd)` (MCP servers added on the request; field `mcp_servers`) -> `session_id`
  - `PromptRequest::new(session_id, vec![ContentBlock::Text(TextContent::new(..))])` -> `stop_reason`
- Streaming: handler `on_receive_notification(async |n: SessionNotification, _cx| ..)`; `n.update` is the `SessionUpdate` enum (agent_message_chunk, agent_thought_chunk, tool_call, tool_call_update, plan, ...).
- Permission: `on_receive_request(async |req: RequestPermissionRequest, responder, _cx| responder.respond(RequestPermissionResponse::new(RequestPermissionOutcome::Selected(SelectedPermissionOutcome::new(option_id)))))`; choose by `PermissionOptionKind`, not position.
- fs/terminal: register further `on_receive_request` handlers for `ReadTextFileRequest`, `WriteTextFileRequest`, `CreateTerminalRequest` etc. and advertise them in `InitializeRequest` client capabilities. UNVERIFIED: exact type names in 5.0 (inferred from schema naming; not read in source).
- Runtime: crate depends on `futures`, not tokio; examples use plain `#[tokio::main]` multi-thread with no LocalSet. The 0.x requirement for `LocalSet`/`?Send` futures no longer applies as far as the example shows. UNVERIFIED whether handler closures must be `Send` (lib.rs grep found no `?Send`/`LocalSet`).

## 2. Claude Code ACP adapter

**Answer:** `@zed-industries/claude-code-acp` (0.16.2) and `@zed-industries/claude-agent-acp` (0.23.1) are deprecated; successor `@agentclientprotocol/claude-agent-acp` v0.100.0, bin `claude-agent-acp`. Launch `npx -y @agentclientprotocol/claude-agent-acp`. Standalone binaries per release (Windows x64/arm64) bundle the `claude` CLI; `CLAUDE_CODE_EXECUTABLE` uses an existing one.

**Details**
- Auth: uses the Claude CLI login (README: smoke test "needs a Claude login"). In remote envs (`NO_BROWSER`, `SSH_*`, `CLAUDE_CODE_REMOTE`) it advertises auth method `claude-login` (type `terminal`, runs `claude /login` via `--cli`). Gateway auth methods only if the client opts in. Gateway config blanks `ANTHROPIC_API_KEY`, `ANTHROPIC_AUTH_TOKEN`, `CLAUDE_CODE_OAUTH_TOKEN` for that path. UNVERIFIED: whether plain `ANTHROPIC_API_KEY` is honored outside gateway mode (likely, via Claude Agent SDK).
- MCP: `mcpCapabilities: { http: true, sse: true }` plus stdio; "Client MCP servers" listed as a feature.

## 3. Codex ACP adapter

**Answer:** `@zed-industries/codex-acp` (0.16.0) deprecated; successor `@agentclientprotocol/codex-acp` v2.5.0, bin `codex-acp`. Launch `npx -y @agentclientprotocol/codex-acp`. Bundles `@openai/codex`; `CODEX_PATH` overrides.

**Details**
- Auth methods advertised at initialize: ChatGPT login (hidden by `NO_BROWSER=1`), API key via `CODEX_API_KEY` > `OPENAI_API_KEY`, custom gateway (opt-in). Other env: `CODEX_CONFIG`, `MODEL_PROVIDER`, `DEFAULT_AUTH_REQUEST`, `INITIAL_AGENT_MODE` (`read-only|workspace-write|agent|agent-full-access`), `APP_SERVER_LOGS`. UNVERIFIED: that an existing `~/.codex/auth.json` login is reused without an `authenticate` call (expected, since it runs the Codex app server).
- MCP: "Client-provided MCP servers over command-based stdio config and HTTP transport" (no SSE stated).

## 4. OpenCode ACP

**Answer:** `opencode acp` (stdio JSON-RPC). Windows install: `npm install -g opencode-ai` (v1.19.5, bin `opencode.exe`), `scoop install opencode`, `choco install opencode`; `curl -fsSL https://opencode.ai/install | bash` is for Unix shells.

**Details**
- Ollama in `opencode.json`:
```json
{"$schema":"https://opencode.ai/config.json",
 "provider":{"ollama":{"npm":"@ai-sdk/openai-compatible","name":"Ollama (local)",
   "options":{"baseURL":"http://localhost:11434/v1"},
   "models":{"llama2":{"name":"Llama 2"}}}}}
```
  Select with model id `ollama/<model>`.
- MCP in ACP: docs say MCP servers from the OpenCode config work. Source (`packages/cli/src/acp/sessions.ts`) also registers session/new `mcpServers`: `SupportedMcpServer = Exclude<McpServer, {type: "acp" | "sse"}>`, so stdio maps to `local`, http to `remote`; SSE unsupported.
- Unsupported in ACP: `/undo`, `/redo`.

## 5. MCP servers in `session/new`

**Answer:** `mcpServers` array. Stdio (always required): `{name, command, args, env}` where `env` is an array (spec example `"env": []`; items `{name, value}`). HTTP: `{type:"http", name, url, headers:[{name,value}]}`; SSE: `{type:"sse", ...}`. Agents advertise `agentCapabilities.mcpCapabilities.{http,sse}`; clients must only send what is advertised.

| Agent | stdio | http | sse |
|---|---|---|---|
| claude-agent-acp | yes | yes | yes |
| codex-acp | yes | yes | not stated |
| opencode acp | yes | yes | no (excluded in source) |

UNVERIFIED: the `{name,value}` item shape and the http field list were not re-read in the v1 spec page this session (from prior knowledge of the schema); confirm in `docs/protocol/v1/session-setup.mdx` "MCP servers" section.

## Sources (all read 2026-11-05)
- https://crates.io/api/v1/crates/agent-client-protocol
- https://github.com/agentclientprotocol/rust-sdk/blob/main/Cargo.toml
- https://github.com/agentclientprotocol/rust-sdk/blob/main/src/agent-client-protocol/Cargo.toml
- https://github.com/agentclientprotocol/rust-sdk/blob/main/src/agent-client-protocol/examples/yolo_one_shot_client.rs
- https://github.com/agentclientprotocol/rust-sdk/blob/main/src/agent-client-protocol/src/acp_agent.rs
- npm registry: `npm view` of @zed-industries/claude-code-acp, @zed-industries/claude-agent-acp, @agentclientprotocol/claude-agent-acp, @zed-industries/codex-acp, @agentclientprotocol/codex-acp, opencode-ai
- https://github.com/agentclientprotocol/claude-agent-acp (README, src/acp-agent.ts)
- https://github.com/agentclientprotocol/codex-acp (README, releases/latest v2.5.0)
- https://github.com/anomalyco/opencode/blob/dev/packages/web/src/content/docs/acp.mdx, providers.mdx, index.mdx
- https://github.com/anomalyco/opencode/blob/dev/packages/cli/src/acp/sessions.ts
- https://github.com/agentclientprotocol/agent-client-protocol/blob/main/docs/protocol/v1/session-setup.mdx
