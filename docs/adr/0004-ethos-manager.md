# 0004: Ethos Manager is an open-source general tool, and the backend gets its own repo

Status: accepted (2026-11-05)

Ethos needs an external app to manage alts and the script. We fork RoALT
(MIT, Tauri 2 with a Rust core and a React UI) as a public GitHub fork,
`jashxn/ethos-manager`, that keeps pulling upstream. We keep Ethos code in its
own folders so those merges stay clean. The app is a general tool anyone can use.
Signing in with an Ethos account only unlocks the Ethos layer.

The backend leaves this repo for a private `jashxn/ethos-platform`, because it now
serves the app, the bot and later a website. Publishing it would hand out a map
of its Luarmor checks, moderation and rate limits.

## Considered options

- **A private hard fork.** It keeps the app closed but loses upstream's
  fast-moving fixes. For an app that holds people's Roblox cookies, open source
  is what earns trust. The value we sell is the backend and the key, not the
  app's code.
- **One public monorepo holding the app and the backend.** It shares types for
  free but publishes the backend.
- **Keep the backend in the library.** The library is Luau, and the backend
  already has more consumers than the library.

## Consequences

- The bridge protocol and the app's view of the backend API live in the public
  repo. The backend checks itself against shared fixtures, the same pattern
  `backend/fixtures` already uses for the fleet protocol.
- Releases and RoALT's signed self-update run from the fork's own GitHub
  releases, with our own signing key. Builds are unsigned for Windows, so
  SmartScreen warnings are expected.
- RoALT's MIT notice stays in `LICENSE` and on the About screen.
