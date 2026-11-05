<div align="center">

# Ethos Manager

### Every Roblox account you own, signed in, checked and one click from any game.

An open-source account manager and multi-client launcher for Windows, with the Ethos layer on top.<br>
Your cookies stay encrypted on your PC and go only to Roblox.

[![Latest release](https://img.shields.io/github/v/release/jashxn/ethos-manager?style=for-the-badge&color=b4f000&labelColor=1a1a1a&label=release)](https://github.com/jashxn/ethos-manager/releases/latest)
[![Windows 10 | 11](https://img.shields.io/badge/Windows-10%20%7C%2011-0078d4?style=for-the-badge&logo=windows&labelColor=1a1a1a)](#-install)
[![Based on RoALT](https://img.shields.io/badge/based%20on-RoALT-2b2b2b?style=for-the-badge&labelColor=1a1a1a)](https://github.com/inspectsoftware/RoALT)

[![CI](https://img.shields.io/github/actions/workflow/status/jashxn/ethos-manager/ci.yml?branch=main&style=flat-square&label=CI)](https://github.com/jashxn/ethos-manager/actions/workflows/ci.yml)
![Tauri 2](https://img.shields.io/badge/Tauri-2-24c8db?style=flat-square&logo=tauri&logoColor=white)
![Rust](https://img.shields.io/badge/Rust-2024-dea584?style=flat-square&logo=rust&logoColor=white)
![React 19](https://img.shields.io/badge/React-19-61dafb?style=flat-square&logo=react&logoColor=white)

<br>

[**⬇ Download**](https://github.com/jashxn/ethos-manager/releases/latest) &nbsp;·&nbsp;
[Quick start](#-quick-start) &nbsp;·&nbsp;
[Privacy](#-safety-and-privacy) &nbsp;·&nbsp;
[Build from source](#-build-from-source) &nbsp;·&nbsp;
[Upstream](#-upstream)

<br>

<img src="docs/images/home.png" alt="Ethos Manager's Home page: account tabs, running clients with live previews, and dials for what the clients use" width="900">

</div>

<br>

## 📑 Contents

| For everyone | For developers |
|---|---|
| [What is Ethos Manager?](#-what-is-ethos-manager) | [Architecture](#-architecture) |
| [Features](#-features) | [Tech stack](#-tech-stack) |
| [Install](#-install) | [Build from source](#-build-from-source) |
| [Quick start](#-quick-start) | [Project layout](#-project-layout) |
| [Safety and privacy](#-safety-and-privacy) | [Testing](#-testing) |
| [FAQ](#-faq) | [Upstream](#-upstream) |
| [Community](#-community) | [Cut a release](#-cut-a-release) |

<br>

## 💡 What is Ethos Manager?

Ethos Manager is a Windows app for people who play Roblox on more than one account. It is a fork of
[RoALT](https://github.com/inspectsoftware/RoALT) by inspectsoftware (MIT), and keeps pulling RoALT's updates.

- **Everything RoALT does, free and without an account.** Add each account once through Roblox's own sign-in
  page, see them all at a glance, paste any game link and launch one account or ten, run several clients side by
  side, and let Ethos Manager bring back any that crash or get kicked.
- **The Ethos layer, with an Ethos account.** Signing in with Discord, backed by a paid or trial Ethos key, unlocks
  the parts that talk to the Ethos backend: license tools, cloud configs, add-ons, the live mirror of the Ethos
  window, stats and multi-PC. Without signing in, none of that runs and nothing goes to the Ethos backend.

Cookies go only to Roblox, signed in or not.

<table>
<tr>
<td width="50%"><img src="docs/images/accounts.png" alt="Accounts: every account with its status, groups and a details panel"><br><sub><b>Accounts:</b> status, groups and details at a glance</sub></td>
<td width="50%"><img src="docs/images/play.png" alt="Play: pick who plays, then paste where to"><br><sub><b>Play:</b> who plays, where, then the big button</sub></td>
</tr>
<tr>
<td><img src="docs/images/performance.png" alt="Performance: FPS cap, lowest graphics and graphics flags"><br><sub><b>Performance:</b> FPS cap, graphics flags, presets and profiles</sub></td>
<td><img src="docs/images/settings.png" alt="Settings: theme, accent colour, background image and more"><br><sub><b>Settings:</b> dark or light, any accent, your own background</sub></td>
</tr>
</table>

<br>

## ✨ Features

<table>
<tr>
<td width="50%" valign="top">

### 🔐 Encrypted vault
Cookies are encrypted with **Windows DPAPI**, or with your own **master password** (Argon2id + AES-256-GCM)
with auto-lock and an optional **recovery code**. Reveal and copy sit behind **Windows Hello** or the master password.

</td>
<td width="50%" valign="top">

### 👥 Accounts at a glance
Avatars, live presence, Robux, Plus, friends, followers and 2-step status. Groups, aliases, notes,
favourites, search and filters. Check sign-ins, one or all, in a click.

</td>
</tr>
<tr>
<td valign="top">

### 🚀 Launch anything
Paste a game link, place ID, job ID, private server or share link, a profile or `@username`:
Ethos Manager works out what it is. Join a friend, or save a target as a favourite.

</td>
<td valign="top">

### 🪟 Multi-instance
Run several clients side by side. Launch a batch one after another, all into **the same server**
if you like, with live progress per account.

</td>
</tr>
<tr>
<td valign="top">

### 🔁 Auto-rejoin and restart
A disconnected client rejoins the same game on its own. Opt-in: crashed, frozen or memory-hungry
clients restart too. A crash breaker gives up on an account after too many tries.

</td>
<td valign="top">

### 🗺️ Server browser
Browse public servers by players or ping, see your private servers, and send any accounts into
the one you pick.

</td>
</tr>
<tr>
<td valign="top">

### 📈 Monitor
CPU, memory, disk/network and uptime per client, with sparklines and totals, refreshed every 2 seconds.

</td>
<td valign="top">

### 🎚️ Performance tab
FPS cap, lowest graphics and graphics flags (MSAA, textures, no grass, gray sky), with presets and
shareable profiles. **Max alts** runs clients tiny, at 10 FPS, with a CPU share that scales with how many
you run and memory trims. The one you're playing stays free of it. CPU and memory settings have their own
panel, most useful first. Cap one client's CPU, pin cores or trim memory.

</td>
</tr>
<tr>
<td valign="top">

### 🔔 Discord alerts
Crashes, disconnects, restarts and finished batches posted to **your own** webhook, kept encrypted
in the vault. Opt-in.

</td>
<td valign="top">

### ⬆️ Roblox updates
Shows when Roblox is out of date and installs the update with Roblox's own installer, after checking
it is signed by Roblox Corporation. Optional auto-update when no client runs.

</td>
</tr>
<tr>
<td valign="top">

### 🖥️ Home
Browser-style **account tabs**, each with its own game and options. Every running client as a live preview,
even hidden ones, in cards you can drag and resize, with dials for what your clients use. Right-click one to
focus, minimize, shrink it, limit it or close it. Tile all clients in one click. Anti-AFK has its own switch here.
Prefer vertical tabs? Put your accounts on the side and Ethos Manager's sections along the top, and drag either into your own order.

</td>
<td valign="top">

### 🛡️ Public networks
Windows calls some networks **Public** (café, hotel, school Wi-Fi). Turn off **Allow public networks** in Settings,
Security, and Ethos Manager won't launch on them and a master-password vault locks there. It is on by default.

</td>
</tr>
<tr>
<td valign="top">

### ↔️ Free resizing
Drag a client's edges to any size, past the 800×600 minimum Roblox holds it to, and move small windows
without them snapping back. Or start every client tiny.

</td>
<td valign="top">

### 🎨 Soft Deck design
A soft, very dark interface with a floating page, or a light theme. Pick any accent colour and your own
background image, and skip the splash screen if you'd rather not wait.

</td>
</tr>
<tr>
<td valign="top">

### 🌍 18 languages
English, Arabic (fully right to left), Bosnian, Chinese (Simplified), Filipino, French, German, Indonesian,
Japanese, Korean, Polish, Portuguese (Brazil), Russian, Spanish, Swedish, Thai, Turkish and Vietnamese.

</td>
<td valign="top">

### ❤️ Support RoALT
Ethos Manager is free. The **Donate** button in the sidebar supports RoALT's author: it opens a [Roblox gamepass](https://www.roblox.com/games/102259086923102/Donation-Experience#!/store)
for the amount you pick, and you confirm the purchase on Roblox.

</td>
</tr>
</table>

<details>
<summary><b>All features, in detail</b></summary>
<br>

| Area | What you get |
|---|---|
| 🔐 **Vault** | DPAPI by default (opens silently). Optional master password with auto-lock after idle, and an optional one-use recovery code for it. Encrypted `.roalt` backups you can export and import. Copied cookies are kept out of clipboard history and cleared after 30 s. |
| 👥 **Accounts** | Add through Roblox's sign-in page (passkeys and security keys work), by pasting a cookie, by pasting many cookies at once, or by importing from Roblox Account Manager (an unlocked `AccountData.json`). Groups, alias, notes, colour, favourite, drag to reorder. Presence, Robux, Plus / Premium (legacy), friend and follower counts, join date, email and 2-step status. "Open on roblox.com" signed in as that account. |
| 🚀 **Play** | Game links, place IDs, `roblox://` links, job IDs, private server links, `roblox.com/share` links (both formats), universes, profiles, `@username`. Join a friend or one of your other accounts. Favourites on the Play page and in the tray. `Ctrl+Enter` to launch. |
| 🪟 **Batches** | Accounts launch strictly one after another with a stagger (default 6 s). **Same server**: *Pick a server* finds one with room for everyone first; *Follow the first* sends the rest to wherever the first account landed. Cancel at any time; one click re-picks the accounts that didn't launch. |
| 🔁 **Recovery** | Auto-rejoin after kicks, shutdowns and lost connections (not after you leave on purpose). Opt-in auto-restart for crashes, frozen windows (30 s) and a memory limit. Crash breaker: default 3 relaunches in 10 minutes, with growing backoff. Per-account "Allow disconnect". Crash history with the log's reason. |
| ↔️ **Free resizing** | Drag a client's edge to any size, past the minimum Roblox holds its window to, and move a small window by its title bar without it growing back. Ethos Manager sizes the window itself (a mouse hook in Ethos Manager's own process); nothing goes into the client. **Start clients tiny** opens every new client at a size you choose. |
| 🖥️ **Home** | Live preview for every client at 5, 15, 30 or 60 FPS, even hidden ones, with state, game, uptime, CPU and RAM. Drag cards to sort them and resize them from the corner; **Detailed view** off shows only the preview and username. Dials show what all Roblox clients use together. Browser-style **account tabs** give each account its own game and options, and launch one or all of them. **Tab layout** (Settings or the title bar) moves accounts to a list on the side and Ethos Manager's sections to tabs along the top. Drag accounts and sections to sort them, or use `Alt` and the arrow keys; the order is saved, and a launch of all tabs follows it. The **⋯** key, right-click, the menu key or `Shift+F10` for focus, minimize, restore, tiny window (any size, 320×240 by default) and back, CPU limit, efficiency mode, anti-AFK, close. **Tile** fits all clients in a grid on the screen; **Tile micro** lays out micro windows. Minimize all, Restore all. |
| 🛑 **Stop all** | Hold one button in the sidebar, use the tray, or press a global **panic hotkey** you choose (off by default) to end every Roblox process and stop pending launches and rejoins. |
| 🌍 **Languages** | English, Arabic (right to left), Bosnian, Chinese (Simplified), Filipino, French, German, Indonesian, Japanese, Korean, Polish, Portuguese (Brazil), Russian, Spanish, Swedish, Thai, Turkish, Vietnamese. |
| ⏲️ **Automation** | Minimize each new client on launch. Auto-shutdown timer: close the clients and shut the PC down at a set time (survives an Ethos Manager restart, can be cancelled). Hourly Roblox log cleaner (logs older than a day or over 50 MB). Open logs button; Ethos Manager's own logs rotate at 5 MB. |
| ⚙️ **Launch control** | Custom launch arguments (default and per account, checked before use and never logged), a cooldown between launches, a configurable close grace (1–60 s). |
| 🎚️ **Limits** | Per client: CPU cap, efficiency mode, core affinity, working-set trim (every N minutes and sooner if a background client grows, or "Page memory out now"). A trim lowers the Memory column for a while; commit size doesn't change. Adaptive manager for background clients; a limit you set on a client wins for that limit. **Memory throttle**: a client whose commit size is over a limit gets a CPU cap, which lowers its frame rate, until it drops under 90 % of the limit. It doesn't free memory; only **Restart on high memory** does, and that disconnects the client. |
| 🎞️ **FPS cap & graphics** | A default frame-rate cap (5–360), a per-account override and a per-launch one under Play's More options (a rejoin keeps it), plus the lowest graphics for every client (on by default). Set through Roblox's own Maximum Frame Rate and Graphics Quality just before each client starts; your own Roblox settings are put back once it has read them, and again when such a client closes (or when Ethos Manager next starts, if it wasn't running then). Everything performance-related lives in its own **Performance** tab. |
| 🪶 **Lighter rendering** | Clients Ethos Manager starts get low geometry detail and the graphics flags below (on by default): less GPU time and memory per client. Written just before each client starts and put back once it has read them; skipped under a bootstrapper. |
| 🎚️ **Graphics flags** | Pick MSAA, texture quality, rendering mode, gray sky, no grass and lowest render quality, from the FastFlags Roblox still allows. Roblox may ignore Vulkan and OpenGL. |
| 👑 **Main account** | Mark an account **Full quality** and its clients keep your own Roblox graphics, without lowest graphics or lighter rendering. |
| 🕘 **Recent servers** | Each account remembers the servers it reached (stored on this PC); rejoin a public one in a click. |
| 🩺 **Diagnostics** | Copy or save a report for bug reports, from Debug: tickets, cookies, your Windows user name and IP addresses are removed. A client that ends badly leaves an autopsy in the log: how long it lived, any crash dump, Windows' record of the fault and the end of its logs. Each trim logs its memory before and after. |
| 📤 **Performance profiles** | Export your performance settings to a file or a share code, or import someone else's: you see what changes, then apply it. Only performance settings travel, never accounts, passwords, launch arguments or hotkeys. |
| 📶 **Bandwidth** | One upload cap for all Roblox clients through a Windows QoS policy. Applied only when you click Apply (admin prompt); cleared when Windows restarts. |
| 💤 **Anti-AFK** | Off by default, with a switch on Home. While you are away from the PC, every few minutes each client is briefly brought to the front and gets one F13 press (no game uses it, so the character stays put), so Roblox doesn't kick it after 20 idle minutes. A minimized client is restored for the press and minimized again. Stops the moment you touch the mouse. Roblox only counts a real key press in the window in front: keys posted to a background window don't stop the idle kick (measured). Per-client opt-out. |
| 🔔 **Discord** | Crash, disconnect, restart and batch alerts, plus an opt-in alert when a client gets into a game. Mute alerts per account. |
| 🔄 **Ethos Manager updates** | Looks for a new Ethos Manager on GitHub Releases at start and every 6 hours (can be turned off; *Check now* in Settings). A banner offers it; *Update now* downloads it, checks its release signature, installs it silently and restarts Ethos Manager. Never installs on its own. |
| 🧰 **Comfort** | Tray menu with favourites, close to tray, relaunch an ended client in one click, movable data folder, keyboard shortcuts. Dark, light or system theme, any accent colour, and your own background image, with a choice of how much the theme covers it. Optional skip of the splash screen. Your Ethos Manager and Roblox versions at the top of Settings. |

</details>

<br>

## 📥 Install

1. Download **`EthosManager-Setup-<version>.exe`** from the [latest release](https://github.com/jashxn/ethos-manager/releases/latest).
2. Run it. No admin rights needed; it installs to `%LOCALAPPDATA%\Programs\Ethos Manager`.
3. Start Ethos Manager from the Start menu or the desktop icon.

| Requirement | |
|---|---|
| Windows | 10 (1809 or later) or 11, x64 |
| WebView2 Runtime | Built into Windows 11. Setup offers to download it when missing. |
| Roblox | Installed normally (Ethos Manager can install or update it for you) |

> [!NOTE]
> The installer isn't code-signed yet, so Windows SmartScreen warns on first run. To be sure the file is genuine,
> compare its SHA-256 with `SHA256SUMS.txt` on the release page, then choose **More info → Run anyway**.
>
> ```powershell
> Get-FileHash .\EthosManager-Setup-0.1.0.exe -Algorithm SHA256
> ```

Your accounts and settings live in `%LOCALAPPDATA%\EthosManager`. Uninstalling keeps them unless you tick
**"also delete my data"**.

<br>

## 🏁 Quick start

<details open>
<summary><b>1. Add your first account</b></summary>
<br>

Press **Add account** (or `Ctrl+N`). A clean Roblox sign-in window opens: sign in as usual, including 2-step or
passkeys. Ethos Manager keeps the sign-in, closes the window and throws its browser profile away. You can also paste a
`.ROBLOSECURITY` cookie; it is checked before it is saved.

</details>

<details>
<summary><b>2. (Optional) Set a master password</b></summary>
<br>

By default the vault is locked to your Windows account, so it opens silently. For extra protection, set a master
password in **Settings**. Ethos Manager then asks for it on start and locks itself after you've been idle.

</details>

<details>
<summary><b>3. Launch a game</b></summary>
<br>

Go to **Play** (`Ctrl+3`), pick an account, paste a game link and press the big **Play** key (`Ctrl+Enter`).
Pick several accounts to launch a batch. Under **More options**, turn on **Same server** to put them all in one server.

</details>

<details>
<summary><b>4. Run several clients at once</b></summary>
<br>

**Multi-instance** is on by default (the switch is in **Settings → Launching**); start Ethos Manager before Roblox. If Roblox is already open, Ethos Manager says so and offers
**Close Roblox** or **Take over**. Every client Ethos Manager starts shows up on **Home**
(`Ctrl+1`), with its state, server and uptime.

</details>

<details>
<summary><b>5. Let it look after your clients</b></summary>
<br>

In **Settings → Launching**, turn on **Auto-rejoin** (and, if you like, **Auto-restart**). Open **Monitor**
(`Ctrl+6`) to see what each client uses, and **Discord** (`Ctrl+7`) to get alerts on your phone.

</details>

<details>
<summary><b>⌨️ Keyboard shortcuts</b></summary>
<br>

| Keys | Action |
|---|---|
| `Ctrl+1` … `Ctrl+9` | Home, Accounts, Play, Servers, Settings, Monitor, Discord, Debug, Performance |
| `Ctrl+N` | Add account |
| `Ctrl+F` | Search accounts |
| `Ctrl+Enter` | Play |
| `F5` | Refresh |

</details>

<br>

## 🔒 Safety and privacy

<table>
<tr>
<td width="50%" valign="top">

#### ✅ What Ethos Manager does

- Talks **only** to `*.roblox.com` and `*.rbxcdn.com`, plus GitHub to look for Ethos Manager updates (can be turned off), your Discord webhook, and the Ethos backend once you sign in to the Ethos layer.
- Encrypts every cookie with **AES-256-GCM** under a key protected by **Windows DPAPI**, plus your master password if you set one.
- Encrypts the **whole database** too (SQLCipher, AES-256), with its own DPAPI-protected key: a copied `ethos-manager.db` can't be read on another PC or Windows account.
- Signs you in through **Roblox's own page**, in a throw-away browser profile.
- Installs Roblox updates **only** when the installer is signed by Roblox Corporation.
- Updates itself **only** when you click Update now, and only with an installer that carries Ethos Manager's release signature.
- Redacts launch tickets from anything it reads in Roblox's logs.

</td>
<td width="50%" valign="top">

#### 🚫 What Ethos Manager never does

- **Never** reads or writes the Roblox client's memory or files, with two exceptions for the clients it starts: Roblox's own settings file (`GlobalBasicSettings_13.xml`, only the frame-rate cap and graphics quality) and the allowlisted rendering flags in the version folder's `ClientSettings\ClientAppSettings.json`. Both are put back as they were once the client has read them.
- **Never** sends telemetry. The account manager needs no account and no server: only the Ethos layer, once you sign in, talks to the Ethos backend.
- **Never** writes cookies, tickets or launch arguments to its logs.
- **Never** changes Windows settings, except the opt-in bandwidth limit.
- **Never** contacts Discord's servers unless you paste a webhook.

</td>
</tr>
</table>

<details>
<summary><b>The details</b></summary>
<br>

- **Discord alerts (opt-in).** If you paste a webhook in the Discord tab, alerts go to that webhook on `discord.com`. The URL is
  kept encrypted in the vault, and messages name accounts by display name and username only, with mentions disabled.
  Nothing is sent while the vault is locked.
- **Roblox updates** come from Roblox only: the version from `clientsettingscdn.roblox.com`, the installer from
  `setup.rbxcdn.com`, run only when its signature checks out as Roblox Corporation's.
- **Ethos Manager updates** are looked up on GitHub (`api.github.com`, this repository's latest published release) as soon
  as Ethos Manager starts and every 6 hours, unless you turn *Check for Ethos Manager updates* off in Settings. The request carries only
  `EthosManager/<version>` as its user agent. When you click Update now, the installer and its `.sig` are downloaded from
  `github.com` (GitHub's own download hosts only), and the installer runs only if its ECDSA P-256 signature checks out
  against the public key built into Ethos Manager. The signature covers the version too, so the release must be newer than
  the Ethos Manager you run and the installer must be the one signed for that version. It installs silently, and Ethos Manager starts again.
  Roblox clients keep running through it, and the restarted Ethos Manager follows them again (also after you close and reopen
  Ethos Manager). Their limits are lifted while Ethos Manager is closed and set again when it starts.
- **Multi-instance** works by creating one named Windows object before Roblox starts. Ethos Manager also holds Roblox's shared
  sign-in files while its clients run, so clients can't sign each other out.
- **Limits** go through Windows itself (job objects, priority, affinity). Ethos Manager only ever opens a client with the
  narrow rights a change needs, never to read its memory.
- **Take over (on request)** closes the one "Roblox is already running" lock inside an open Roblox, so Ethos Manager's clients
  can run next to it. It needs to copy that one handle (`PROCESS_DUP_HANDLE`) and never reads or writes the client's memory.
- **Anti-AFK (opt-in)** briefly brings a client to the front and presses F13 the way a keyboard does.
- **Window tools** (previews, hide, micro, tile) use ordinary Windows calls: Windows.Graphics.Capture for previews, and
  `ShowWindow`, `SetWindowPos`, `SetWindowLongPtr` and `SetLayeredWindowAttributes` for the rest. A hidden client gets the
  layered and click-through window styles at alpha 1. Clean exit and panics clear them; if Ethos Manager is killed outright, the
  client stays invisible until Ethos Manager starts again.
- **Free resizing and hidden clients** use a low-level mouse hook and window-event hooks (foreground, Alt-Tab, minimize,
  drags) in Ethos Manager's own process. They see where the mouse is and which window changes across the PC, and store and send
  nothing. A press only acts on the edge or title bar of a client Ethos Manager started; a press on the taskbar or its thumbnails
  is only noted, for a moment, as you asking for a hidden client back.
- **Bandwidth limit (opt-in)** adds a Windows QoS policy named `EthosManager-Roblox` through an admin prompt, only when you click
  Apply. Windows drops it on restart. It is the only change Ethos Manager makes to Windows.

</details>

> [!IMPORTANT]
> Your `.ROBLOSECURITY` cookie is the key to your account. Ethos Manager keeps it encrypted, but never share a cookie,
> a `.roalt` backup or its password with anyone, including people who say they are helping you.

<br>

## ❓ FAQ

<details>
<summary><b>Is Ethos Manager safe to use with my account?</b></summary>
<br>

Ethos Manager signs in the same way the Roblox website does and never touches the Roblox client. Roblox has said that
multi-instance methods which don't modify the client are not affected by its modified-client enforcement, but it
doesn't officially support running several clients at once. Use Ethos Manager only with accounts you own.

</details>

<details>
<summary><b>Why does Windows warn me when I run the installer?</b></summary>
<br>

The installer isn't code-signed yet, so SmartScreen doesn't recognise it. Check the SHA-256 against
`SHA256SUMS.txt` on the release, then choose **More info → Run anyway**.

</details>

<details>
<summary><b>Multi-instance says Roblox is already running.</b></summary>
<br>

Roblox's tray app or an open client already holds the lock Ethos Manager needs. Click **Close Roblox** when Ethos Manager offers it, then
launch from Ethos Manager. To keep that client open, click **Take over** instead.

</details>

<details>
<summary><b>An account shows "Cookie expired" or needs verification.</b></summary>
<br>

Roblox ended that sign-in, or wants a human check. Open the account on roblox.com from its menu and complete the
check, or remove it and add it again.

</details>

<details>
<summary><b>I forgot my master password.</b></summary>
<br>

If you made a **recovery code**, press **Forgot password?** on the unlock screen, enter the code and choose a new
password. The code works once and you get a new one. It's optional: make one when you set the password, or later in
**Settings**.

- A code file on the same PC opens the vault for anyone who finds it, so keep it on a USB stick, a phone or paper.
- It works only for the same Windows user on the same PC. After a Windows reinstall or on a new PC it won't help; a
  `.roalt` backup does.

Without a code the password can't be recovered: that is what makes it safe. Remove the data folder
(`%LOCALAPPDATA%\EthosManager`) and add your accounts again, or import a `.roalt` backup whose password you know.

</details>

<details>
<summary><b>Does it work with Bloxstrap?</b></summary>
<br>

Yes. Ethos Manager launches through the registered bootstrapper and follows its clients. It won't install Roblox updates over a
bootstrapper, since the bootstrapper keeps Roblox up to date itself. Ethos Manager's graphics flags are skipped there, because a
bootstrapper writes its own.

</details>

<details>
<summary><b>Where is my data? Can I move it?</b></summary>
<br>

In `%LOCALAPPDATA%\EthosManager`. **Settings → Data** opens it or moves it to another folder or drive.

</details>

<br>

## 💬 Community

Questions, ideas or bug reports? [Open an issue](https://github.com/jashxn/ethos-manager/issues).

<br>

---

<div align="center">

# 🔧 For developers

</div>

## 🧭 Architecture

Ethos Manager is a [Tauri 2](https://tauri.app) app: a Rust backend that owns every secret, process and network call, and a
React UI that talks to it over typed IPC. The UI never sees a cookie unless you reveal one.

```mermaid
flowchart LR
    UI["React UI<br/>src/features/*"] -- "invoke / events<br/>(src/api.ts, ts-rs types)" --> CMD["commands.rs"]
    CMD --> VAULT["vault<br/>DPAPI · Argon2id · AES-GCM"]
    CMD --> API["roblox_api<br/>CSRF · rate limits · cookie rotation"]
    CMD --> LAUNCH["launcher<br/>target · uri · bulk · update"]
    CMD --> INST["instances<br/>tracker · limits · rejoin · metrics"]
    CMD --> DISC["discord<br/>webhook alerts"]
    VAULT --> DB[("SQLite<br/>ethos-manager.db")]
    LAUNCH --> API
    LAUNCH --> RBX["RobloxPlayerBeta.exe"]
    INST -- "PID + log file" --> RBX
    INST --> DISC
    API --> NET(("*.roblox.com"))
```

| Module | Role |
|---|---|
| [`vault/`](src-tauri/src/vault) | Envelope encryption: one random data key encrypts every secret (AES-256-GCM, row-bound AAD). The key is wrapped with DPAPI, or with an Argon2id key from the master password and then DPAPI. Windows Hello re-auth, `.roalt` backups. |
| [`roblox_api/`](src-tauri/src/roblox_api) | The one typed Roblox client. Every URL in `endpoints.rs`. CSRF from the real request's 403, per-route queues driven by `x-ratelimit-*`, rotated `.ROBLOSECURITY` saved atomically, three error-body shapes parsed. |
| [`launcher/`](src-tauri/src/launcher) | `target.rs` parses any pasted link locally; `uri.rs` builds the `roblox-player:` URI exactly like the website; `bulk.rs` runs batches and same-server; `client_settings.rs` the FPS cap and lowest graphics; `flags.rs` the rendering flags; `update.rs` + `authenticode.rs` install Roblox updates after `WinVerifyTrust`. |
| [`instances/`](src-tauri/src/instances) | `tracker.rs` ties each client to its account by PID, start time and log file; `logwatch.rs` reads job IDs and disconnects; `rejoin.rs` and the crash breaker; `limits.rs` CPU caps, affinity, efficiency mode, trims; `metrics.rs`; `multi.rs` the singleton lock and take-over; `capture.rs` live previews; `window.rs` hidden clients, micro and tile; `resize.rs` free resizing; `qos.rs`; `afk.rs`. |
| [`discord.rs`](src-tauri/src/discord.rs) | Webhook alerts: host-checked URL, events coalesced every 2 s, `retry_after` honoured. |
| [`webview.rs`](src-tauri/src/webview.rs) | Sign-in and session windows on temporary WebView2 profiles, deleted after use. |
| [`storage/`](src-tauri/src/storage) | SQLite through `rusqlite` with numbered migrations. Running clients live in memory only. |

<details>
<summary><b>How a launch works</b></summary>
<br>

1. Validate the account, then resolve a share link or universe with **that account's** cookie.
2. `GET auth.roblox.com/v1/client-assertion/`, then POST `authentication-ticket` with it, as the website does.
3. Build the `roblox-player:` URI with a fresh `browsertrackerid`, then start the client from the path in
   `HKCU\Software\ROBLOX Corporation\Environments\roblox-player`.
4. Record the PID and creation time and close the process handle at once.
5. Bind the client's `_Player_` log by that tracker ID, then read its job ID, user ID and disconnects. If Roblox
   relaunches itself during an update, the tracker re-binds through the log's `userid:`.

</details>

<details>
<summary><b>Process-handle rules</b></summary>
<br>

Every sample or change opens a short-lived handle checked against the client's start time, with only the right it
needs: `PROCESS_QUERY_LIMITED_INFORMATION` for metrics, `PROCESS_SET_QUOTA` for trims, `PROCESS_SET_INFORMATION` for
affinity and efficiency mode. Never `PROCESS_VM_READ`; `PROCESS_DUP_HANDLE` only for a take-over you start. Only the
CPU-cap job handle is kept.

</details>

The full design, with every Roblox behaviour verified and its source, is in [docs/DESIGN.md](docs/DESIGN.md).
What each milestone added and how to test it is in [docs/MILESTONES.md](docs/MILESTONES.md).

<br>

## 🧱 Tech stack

| Layer | Tools |
|---|---|
| Shell | Tauri 2.12, WebView2 |
| Backend | Rust (edition 2024), tokio, reqwest (rustls), rusqlite + rusqlite_migration, `windows` 0.62 |
| Crypto | aes-gcm, argon2, zeroize, Windows DPAPI and Windows Hello |
| Frontend | React 19, TypeScript, Vite, Tailwind CSS 4, TanStack Query 5 |
| IPC types | [ts-rs](https://github.com/Aleph-Alpha/ts-rs): Rust types exported to `src/bindings/` |
| Installer | Inno Setup 6.6, GitHub Actions (CI and tagged draft releases) |

<br>

## 🔨 Build from source

**Needs**, all on Windows 10 or 11 x64:

| Tool | Install |
|---|---|
| Rust 1.95 or newer, through rustup | `winget install Rustlang.Rustup`, then `rustup default stable` |
| Visual Studio Build Tools with the C++ workload | `winget install Microsoft.VisualStudio.2022.BuildTools --override "--passive --wait --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"` |
| Node.js 24 | [nodejs.org](https://nodejs.org) |
| Strawberry Perl (OpenSSL for the encrypted database builds from source with it) | `winget install StrawberryPerl.StrawberryPerl` |
| Inno Setup 6.6 or newer, for the installer | `winget install JRSoftware.InnoSetup` |

Open a new terminal after installing them, then build the installer from a clean clone:

```powershell
git clone https://github.com/jashxn/ethos-manager.git
cd ethos-manager
npm ci
powershell -ExecutionPolicy Bypass -File scripts\build-installer.ps1
```

That writes `dist-installer\EthosManager-Setup-<version>.exe` and prints its SHA-256.

| Command | What it does |
|---|---|
| `npm run tauri dev` | Runs the full app with hot reload. |
| `npm run dev` | Runs the UI alone in a browser, against a built-in mock of the backend (`src/dev/mockIpc.ts`). |
| `npm run build` | Type-checks, checks every translation, and builds the UI into `dist/`. |
| `npm run bindings` | Regenerates the TypeScript types in `src/bindings/` from the Rust types. Run it after changing a `#[ts(export)]` type. |
| `powershell -ExecutionPolicy Bypass -File scripts\build-installer.ps1` | Release build plus installer: `dist-installer\EthosManager-Setup-<version>.exe` and its SHA-256. |
| `…\build-installer.ps1 -Dev` | Also keeps `installers\EthosManager-Setup-<version>-dev-<stamp>.exe`, one per change. |

> [!TIP]
> Set `ETHOS_MANAGER_DATA_DIR` to a scratch folder to run a build without touching your real accounts. A build
> started that way skips the single-instance check, so it runs beside your normal Ethos Manager, and two of them
> on different folders run side by side.

<br>

## 📁 Project layout

```text
├─ src/                    React UI
│  ├─ App.tsx              window shell, navigation, shortcuts
│  ├─ api.ts               one typed wrapper per backend command
│  ├─ bindings/            ts-rs generated types (committed)
│  ├─ dev/mockIpc.ts       mock backend for `npm run dev`
│  ├─ ui/                  shared components
│  └─ features/            dashboard · accounts · launch · servers · performance · monitor · discord · debug · settings · splash · vault
├─ src-tauri/              Rust backend
│  ├─ src/
│  │  ├─ main.rs           builder, plugins, managed state
│  │  ├─ commands.rs       IPC layer
│  │  ├─ model.rs          shared types (exported to TS)
│  │  ├─ vault/  roblox_api/  launcher/  instances/  storage/
│  │  ├─ discord.rs  webview.rs  tray.rs  error.rs
│  ├─ locales/             the backend's translations
│  └─ tauri.conf.json
├─ installer/EthosManager.iss  Inno Setup script
├─ scripts/                build-installer.ps1, check-i18n.mjs
├─ docs/                   DESIGN.md · MILESTONES.md · research/
└─ .github/workflows/      ci.yml · release.yml
```

<br>

## 🧪 Testing

```powershell
npm ci
npm run build                                                     # TypeScript, translations, and dist/ for the Rust build
cargo test --locked --manifest-path src-tauri/Cargo.toml          # Rust unit tests
cargo clippy --all-targets --locked --manifest-path src-tauri/Cargo.toml -- -D warnings
```

`cargo test` needs `dist/`, so run `npm run build` first. The Rust tests cover link parsing, URI building
(byte-for-byte against the website's output), vault and backup round-trips, the self-updater's signature check, and
response parsing from recorded fixtures. They never use real cookies. CI runs all of the above on `windows-latest`
for every push and pull request.

<br>

## 🔀 Upstream

Ethos Manager is a GitHub fork of [inspectsoftware/RoALT](https://github.com/inspectsoftware/RoALT) and keeps pulling
it:

```powershell
git remote add upstream https://github.com/inspectsoftware/RoALT.git
git fetch upstream
git merge upstream/main
```

To keep those merges clean, Ethos code lives in its own folders, `src-tauri/src/ethos/` and `src/features/ethos/`,
and RoALT's files change only where Ethos Manager needs a hook. File formats and hidden names keep RoALT's spelling
on purpose, so RoALT's files still import and merges stay small: encryption labels, the `.roalt` backup, the
`roalt-performance` profile and its `RoALT-PERF:` share code, and `localStorage` keys.

<br>

## 🤝 Contributing

Bug reports, ideas and pull requests are welcome.

1. Open an [issue](https://github.com/jashxn/ethos-manager/issues) first for anything big. A fix for something RoALT
   does too belongs [upstream](https://github.com/inspectsoftware/RoALT/issues).
2. Keep changes small and focused, and match the surrounding code.
3. Run the [tests](#-testing) and `npm run bindings` if you changed a shared type.
4. Never commit a real cookie, ticket, key or webhook, including in fixtures or screenshots.

<br>

## 📦 Cut a release

<details>
<summary><b>Steps</b></summary>
<br>

1. Set the same version in `src-tauri/tauri.conf.json`, `package.json` and `src-tauri/Cargo.toml`,
   then run `cargo update -p ethos-manager --offline` in `src-tauri` so `Cargo.lock` matches (CI builds `--locked`).
2. Commit all four files, then tag and push the tag: `git tag vX.Y.Z && git push origin vX.Y.Z`.
3. The Release workflow builds the installer, signs it for the self-updater with the `ETHOS_UPDATE_KEY` secret, and
   puts it with its `.sig` and `SHA256SUMS.txt` on a draft release. Check it, then publish the draft.

</details>

<br>

## ⚖️ License

[MIT](LICENSE). Ethos Manager is based on [RoALT](https://github.com/inspectsoftware/RoALT), © 2026 inspectsoftware,
whose MIT notice `LICENSE` keeps and Settings › About shows.

<br>

## 📜 Disclaimer

Ethos Manager is an independent project, not affiliated with or endorsed by Roblox Corporation or by RoALT's
author. Use it only with accounts you own. Roblox doesn't officially support running several clients at once and
may change how its client behaves at any time.

<div align="center">
<br>
<sub>Made for people with too many alts. &nbsp;·&nbsp; <a href="https://github.com/jashxn/ethos-manager/releases/latest">Download</a> &nbsp;·&nbsp; <a href="https://github.com/inspectsoftware/RoALT">RoALT</a></sub>
</div>
