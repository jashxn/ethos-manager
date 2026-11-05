# AGENTS.md

Ethos Manager is a fork of [RoALT](https://github.com/inspectsoftware/RoALT): a Tauri 2 app with a
Rust core in `src-tauri/` and a React 19 UI in `src/`. It adds the Ethos layer: a local bridge to
Roblox clients, the Ethos account, loadouts, stats, multi-PC and a desktop agent.

## Layout

- Keep RoALT's module layout. Ethos code goes in `src-tauri/src/ethos/` and `src/features/<name>/`,
  so upstream merges stay small. The `upstream` remote is inspectsoftware/RoALT.
- `bridge/` holds the Lua side of the bridge (stub, served bridge, crypto) and the shared protocol
  fixtures that both the Rust and the Lune tests read.
- `fixtures/api/` holds backend API fixtures, synced from ethos-platform.

## Specs and decisions

- `docs/bridge-protocol.md` is the bridge spec. Change it in the same commit as the code.
- ADRs live in `docs/adr/`. `CONTEXT.md` is the glossary.

## Build and test

- Windows, Rust 1.95 (MSVC), Node 24 with npm. Run cargo from PowerShell or cmd: Git Bash's
  `/usr/bin/link` shadows the MSVC `link.exe`.
- `npm ci`, then `npm run build` (typecheck, i18n check, Vite build).
- `cargo test --manifest-path src-tauri/Cargo.toml` and
  `cargo clippy --manifest-path src-tauri/Cargo.toml --all-targets -- -D warnings`.
- `lune run bridge/tests/run` runs the Lua bridge tests (Lune 0.10.4, pinned in `aftman.toml`;
  0.10.5 breaks server-side socket closes). The Rust cross test needs `lune` on PATH and fails
  without it.
- `npm run bindings` regenerates the ts-rs types in `src/bindings/` after a Rust type changes.
- `npm run dev` previews the UI in a browser against the fake backend in `src/dev/mockIpc.ts`.
  Every new command gets a fake there.

## Conventions

- No code comments.
- Every UI string is an i18n key in all 18 catalogs in `src/i18n/locales`; `npm run i18n:check`
  must pass. Rust-side strings use `src-tauri/locales`.
- Validate at trust boundaries: bridge frames, the OAuth callback, backend responses, MCP inputs.
- Never log or store Roblox cookies, license keys, the bridge token or AI-tool credentials.
