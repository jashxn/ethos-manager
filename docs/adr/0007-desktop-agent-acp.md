# 0007: The desktop agent drives user-installed coding agents over ACP

Status: accepted (2026-11-05)

Users want the desktop agent to run on AI subscriptions they already pay for,
the way T3 Code does. The app implements one Agent Client Protocol (ACP) client
in Rust and drives:

- **OpenCode** natively. It covers ChatGPT and Copilot sign-in, OpenRouter,
  DeepSeek, Kimi, Ollama, LM Studio and custom endpoints.
- **Claude Code** through Zed's ACP adapter.
- **Codex** through its ACP adapter.

The app's alt tools reach every agent as one MCP server.

Each user installs and signs in to these CLIs through the vendor's own flow. The
app never reads, stores or forwards their login, and never modifies or bundles
the Claude Code binary. That is the only form Anthropic's terms allow. OpenAI's
Sign in with ChatGPT needs no interest form because the app is open source and
runs locally.

## Considered options

- **Antigravity:** rejected. Its FAQ says wrapping `agy` in a third-party app "is
  not supported under consumer plans" and can get the user's Google and Gemini
  CLI accounts suspended.
- **Muse Code:** waits until it runs on Windows.
- **Gemini CLI:** waits until its terms are checked for this use.
- **Ethos-hosted models on the owner's personal subscriptions:** rejected. Both
  Anthropic's and OpenAI's consumer terms ban account sharing and reselling, and
  one plan's limits can't serve a user base.
- **Syncing API keys between the in-game agent and the app:** dropped. Each agent
  keeps its own settings.
