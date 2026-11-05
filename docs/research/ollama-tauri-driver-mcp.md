# Research: Ollama on Windows, tauri-driver, Rust MCP server

All sources read 2026-11-05 unless noted. Checks on this machine were run the same day.

## 1. Ollama on Windows and LM Studio detection

**Question.** Does OllamaSetup.exe install per user without admin? Which silent flags work? Is there a standalone zip? Which REST calls detect Ollama and pull a model? Which small model handles tool calls on CPU? How do we detect LM Studio?

**Answer.** Yes. The installer is Inno Setup with `PrivilegesRequired=lowest` and installs to `%LOCALAPPDATA%\Programs\Ollama` without admin. `/DIR=` is documented. `/SILENT` and `/VERYSILENT` are standard Inno Setup switches, but Ollama's docs do not mention them. Zips exist. Detect with `GET /api/version`. Pull with `POST /api/pull`, which streams NDJSON. For a small model, use `qwen3:0.6b` (523MB, tools tag) or `qwen2.5:0.5b` (398MB, tools tag).

**Details**
- The latest release is `v0.40.14`, published 2026-11-03. Its assets include `OllamaSetup.exe`, `ollama-windows-amd64.zip`, `ollama-windows-amd64-rocm.zip`, `ollama-windows-amd64-mlx.zip` and `ollama-windows-arm64.zip`.
- Download URL: `https://ollama.com/download/OllamaSetup.exe` 307 redirects to `github.com/ollama/ollama/releases/latest/download/OllamaSetup.exe`, which redirects to the v0.40.14 asset. The asset is **about 1.68 GB** (Content-Length 1675999728, checked with curl). Plan the download UX around that size.
- Installer script `app/ollama.iss`:
  - `DefaultDirName={localappdata}\Programs\{#MyAppName}`
  - `PrivilegesRequired=lowest`
  - `OutputBaseFilename="OllamaSetup"`
- From windows.mdx:
  - "does not require Administrator, and installs in your home directory".
  - The documented way to change the install folder is `OllamaSetup.exe /DIR="d:\some\location"`.
  - The installer adds the binaries folder to the user PATH.
  - Logs go to `%LOCALAPPDATA%\Ollama` (`server.log`).
  - Set `OLLAMA_MODELS` to move model storage.
- Silent install: `/SILENT` and `/VERYSILENT` (plus `/SUPPRESSMSGBOXES` and `/NORESTART`) are generic Inno Setup command-line switches. **Not verified against Ollama.** No Ollama doc mentions them, and I did not run the installer. I did not read the `[Run]` section either, so the tray app may still start after a silent install.
- Zip: windows.mdx says it contains "only the Ollama CLI and GPU library dependencies for Nvidia". For AMD, extract the rocm zip into the same folder. The docs pitch it for embedding Ollama in other apps or running it as a service (for example with NSSM). Run it with `<dir>\ollama.exe serve`. `OLLAMA_HOST` sets the bind address (default `127.0.0.1:11434`) and `OLLAMA_MODELS` sets model storage.
- REST API (docs/openapi.yaml):
  - `GET http://127.0.0.1:11434/api/version` returns `{"version":"..."}`. Use it for detection.
  - `GET /api/tags` lists the installed models.
  - `POST /api/pull` takes a body like `{"model":"qwen3:0.6b"}`. Add `"stream": false` to get a single reply instead of a stream. It responds with `application/x-ndjson` StatusEvent lines: `{status, digest?, total?, completed?}`. Show progress as `completed/total` per digest. The stream ends with `{"status":"success"}`, following the Ollama convention. I did not confirm that last line in this read of the spec.
- Small models (sizes from ollama.com/library pages; all three carry the "tools" tag):

  | Model | Size |
  |---|---|
  | `qwen2.5:0.5b` | 398MB |
  | `qwen3:0.6b` | 523MB |
  | `llama3.2:1b` | 1.3GB |

  How well they actually call tools at this size was not benchmarked. qwen3 is the newer family. `qwen3:1.7b` is the step up if 0.6b misfires.
- LM Studio: the docs show the OpenAI-compatible base `http://localhost:1234/v1`, `GET /v1/models` and `/v1/chat/completions`. The native REST API also has `/api/v1/models`, `/api/v1/models/download`, `/api/v1/models/load` and others. Detect LM Studio by probing `GET http://127.0.0.1:1234/v1/models`.

**Sources**
- https://github.com/ollama/ollama/releases/tag/v0.40.14
- https://github.com/ollama/ollama/blob/main/docs/windows.mdx
- https://github.com/ollama/ollama/blob/main/app/ollama.iss
- https://github.com/ollama/ollama/blob/main/docs/openapi.yaml
- https://ollama.com/library/qwen3:0.6b
- https://ollama.com/library/qwen2.5:0.5b
- https://ollama.com/library/llama3.2:1b
- https://lmstudio.ai/docs/developer/openai-compat
- https://lmstudio.ai/docs/developer/rest
- Inno Setup switches (not fetched; from general knowledge): https://jrsoftware.org/ishelp/index.php?topic=setupcmdline

## 2. tauri-driver for Tauri 2 end-to-end tests on Windows

**Question.** How do we install and run tauri-driver with msedgedriver, which capabilities does it need, and what are the known issues?

**Answer.** Install with `cargo install tauri-driver --locked`. The latest stable is 2.1.0, with a 3.0.0-alpha.1 also published. Put an `msedgedriver.exe` that exactly matches WebView2 on PATH, or pass `--native-driver`. Point WebdriverIO or Selenium at `127.0.0.1:4444` with the capability `tauri:options.application`. The Tauri docs now recommend `@wdio/tauri-service`, which syncs Edge Driver for you.

**Details**
- crates.io lists `max_version` 3.0.0-alpha.1. The latest stable tag is `tauri-driver-v2.1.0` (edition 2024, MSRV 1.90).
- Changelog notes:
  - 2.0.4 auto-appends `.exe` to `tauri:options.application`.
  - 2.0.5 stops the native driver's stdout from polluting tauri-driver's stdout.
  - 2.0.6 supports `eq-separator`.
- Ports: `--port` (default 4444) and `--native-port` (default 4445). Use `--native-driver <path>` if msedgedriver is not on PATH.
- Finding the WebView2 version: read registry value `pv` under `HKLM\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}`. On this machine it returned `156.0.4314.58`. Per-user installs live under the HKCU equivalent (not verified here).
- Download: `https://msedgedriver.microsoft.com/<version>/edgedriver_win64.zip`. The 156.0.4314.58 zip returned 200 (11.6MB). `https://msedgedriver.microsoft.com/LATEST_STABLE` returns the version as UTF-16 text (156.0.4314.58 today). Alternatively, the docs suggest `cargo install --git https://github.com/chippers/msedgedriver-tool`.
- WebdriverIO setup from the docs example:
  - Config: `host:'127.0.0.1'`, `port:4444`, `maxInstances:1`, and `capabilities:[{ maxInstances:1, 'tauri:options': { application: '../src-tauri/target/debug/<app>' } }]`.
  - Build the binary in `onPrepare` with `tauri build --debug --no-bundle`.
  - Spawn `~/.cargo/bin/tauri-driver` in `beforeSession` and kill it in `afterSession` and on shutdown.
  - A Selenium example also exists at `Example/selenium.mdx`.
- Known issues:
  - If the driver and WebView2 versions don't match, the session hangs while connecting (manual-setup docs).
  - The README calls tauri-driver "pre-alpha".
  - Driven directly, it supports Windows and Linux only.
  - `afterSession` may not run if the session fails to start, so the docs also kill the driver on shutdown.
- Recommended alternative: `npm create wdio@latest`, then Desktop Testing, then Tauri. The config uses `services:[['tauri',{appBinaryPath, driverProvider:'embedded'}]]` with `tauri-plugin-wdio-webdriver`. Without that plugin, use `driverProvider:'external'`, which goes through tauri-driver and keeps Edge Driver in sync.

**Sources**
- https://github.com/tauri-apps/tauri/blob/dev/crates/tauri-driver/README.md
- https://github.com/tauri-apps/tauri/blob/dev/crates/tauri-driver/CHANGELOG.md
- https://crates.io/api/v1/crates/tauri-driver
- https://github.com/tauri-apps/tauri-docs/blob/v2/src/content/docs/develop/Tests/WebDriver/index.mdx
- https://github.com/tauri-apps/tauri-docs/blob/v2/src/content/docs/develop/Tests/WebDriver/manual-setup.mdx
- https://github.com/tauri-apps/tauri-docs/blob/v2/src/content/docs/develop/Tests/WebDriver/Example/webdriverio.mdx
- https://msedgedriver.microsoft.com/LATEST_STABLE

## 3. Minimal Rust MCP server

**Question.** Is rmcp the right crate? What is its latest version? How do we serve tools over stdio and over streamable HTTP?

**Answer.** Yes. `rmcp` is the official SDK at modelcontextprotocol/rust-sdk. The latest is **3.8.0** (tag `rmcp-v3.8.0`, 2026-10-26), and it supports MCP `2026-07-28`. Hand-rolled JSON-RPC is only worth it for a stdio-only server with a few tools, and you would have to track spec changes yourself.

**Details**
- Install: `cargo add rmcp --features server,macros,transport-io` for stdio. Add `transport-streamable-http-server` for HTTP, along with `axum` and `tokio`. Feature names are from `crates/rmcp/Cargo.toml`.
- Tools-only stdio server (from the README):
  ```rust
  use rmcp::{handler::server::wrapper::Parameters, schemars, tool, tool_router, ServiceExt, transport::stdio};
  #[derive(serde::Deserialize, schemars::JsonSchema)] struct AddParams { a: i32, b: i32 }
  #[derive(Clone)] struct Calculator;
  #[tool_router(server_handler)]
  impl Calculator {
      #[tool(description = "Add two numbers")]
      fn add(&self, Parameters(AddParams { a, b }): Parameters<AddParams>) -> String { (a + b).to_string() }
  }
  // main: Calculator.serve(stdio()).await?.waiting().await?;
  ```
  Use `#[tool_router]` together with `#[tool_handler(name=..., version=..., instructions=...)]` for custom metadata.
- Streamable HTTP (from examples/servers/src/counter_streamhttp.rs):
  ```rust
  let service = StreamableHttpService::new(|| Ok(Counter::new()), LocalSessionManager::default().into(),
      StreamableHttpServerConfig::default().with_cancellation_token(ct.child_token()));
  let router = axum::Router::new().nest_service("/mcp", service);
  axum::serve(tokio::net::TcpListener::bind("127.0.0.1:8000").await?, router).await;
  ```
  - In stateless mode the factory runs per request, so keep shared state in a cloned handle.
  - Options: `with_json_response(true)` and `with_legacy_session_mode(false)`.
- Not verified: whether rmcp validates Origin/Host headers by default to stop DNS rebinding on localhost HTTP. Check this before shipping, or add an axum layer.

**Sources**
- https://github.com/modelcontextprotocol/rust-sdk (README)
- https://github.com/modelcontextprotocol/rust-sdk/releases/tag/rmcp-v3.8.0
- https://github.com/modelcontextprotocol/rust-sdk/blob/main/crates/rmcp/Cargo.toml
- https://github.com/modelcontextprotocol/rust-sdk/blob/main/examples/servers/src/counter_streamhttp.rs
- https://crates.io/api/v1/crates/rmcp
