# 0005: An Ethos account is a Discord ID, not a license key

Status: accepted (2026-11-05)

Until now an account was a hash of the Luarmor project and license key. A reset
or replaced key therefore became a new account, losing everything tied to the old
one. The app and a future website also need a real login.

We key accounts by the Discord ID that Luarmor already binds to each key:

- **App:** signs in with Discord OAuth. The browser redirects to a loopback port
  and the backend exchanges the code.
- **Roblox clients:** keep logging in with the key, which resolves to the same
  Discord account.
- **Ethos layer:** needs Luarmor to report a paid or trial key for that Discord
  ID.
- **Keys with no Discord link** (ad tier) stay key-hash accounts and work in
  game only.

## Consequences

- Existing key-hash accounts are re-keyed to their Discord ID on their next key
  login. Every service that stores an account ID has to follow: cloud config
  authors, community, profiles, tokens.
- The backend now owns HWID resets and their shared limit of 2 per 24 hours. The
  bot's `/resethwid` calls the backend instead of Luarmor.
- The glossary's **Account principal** entry describes the old model and moves to
  `ethos-platform` updated.
