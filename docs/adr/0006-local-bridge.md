# 0006: Ethos Manager reaches its clients through a local bridge, not the backend

Status: accepted (2026-11-05)

The app has to control each Roblox client on its own PC: status, actions, the
live mirror, loadouts, and raw code from the app and the desktop agent. A small
**bridge stub** sits in the executor's auto-execute folder. It holds the port and
a pairing token, and it loads the full bridge from the app over a WebSocket on
`127.0.0.1`.

The backend never carries raw code. If it did, one stolen Ethos session would
mean running code on every alt the user owns. Fleet already relays declared
actions between clients through the backend, but building on it would route
local control through a server and tie the app to the Ethos library.

## Decision

- **The app is the server.** It listens on loopback only and rejects any upgrade
  that carries an `Origin` header, which shuts out web pages.
- **Both sides prove the pairing token**, so a process squatting on the port
  can't feed code to clients.
- **The bridge API is public:** actions, values and a UI schema. Any script can
  integrate with it, and the Ethos library is its first user. Backend leaderboards
  still accept only stats registered on the backend.
- **The Ethos library keeps its own backend calls:** sign-in with the key, cloud
  configs, and generic stats. Lifetime stats therefore build up for users who
  never run the app.
- **Loadouts are stored on the PC** and pushed through the bridge when an alt
  joins. The library does not fetch them from the backend.
- **Fleet and Pulse are left untouched.** Nothing new builds on them.

## Consequences

- Executors without WebSocket support can't use the bridge, and the stub exits
  quietly on them.
- Commands from somewhere other than the alt's own PC (another PC, the website,
  a phone) need a relay through the backend to that PC's app. That waits for
  phase 3.
