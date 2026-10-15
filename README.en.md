<p align="center">
  <img src="docs/images/icon.png" alt="" width="112">
</p>

<h1 align="center">KeepMyMacAwake</h1>

<p align="center">
  <b>Keep your Mac working while you're away.</b><br>
  Your AI coding agent, build or download is still running? Lock the screen, go to sleep, even close the lid — your Mac stays awake, then returns to normal sleep when time is up.
</p>

<p align="center">
  <a href="https://github.com/diguike/KeepMyMacAwake/releases"><img src="https://img.shields.io/github/v/release/diguike/KeepMyMacAwake?include_prereleases&label=download&color=FF6A2B" alt="Download"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-FF6A2B?logo=apple&logoColor=white" alt="macOS 14+">
  <a href="https://github.com/diguike/KeepMyMacAwake/actions/workflows/ci.yml"><img src="https://github.com/diguike/KeepMyMacAwake/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-FEA82F" alt="MIT"></a>
</p>

<p align="center">
  <a href="https://github.com/diguike/KeepMyMacAwake/releases">Download for Mac</a> ·
  <a href="README.md">中文</a> ·
  Native macOS menu bar app · Free and open source
</p>

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/images/overview-dark.png">
    <img src="docs/images/overview-light.png" alt="KeepMyMacAwake control window and menu bar status panel" width="860">
  </picture>
</p>

> The interface is currently in Simplified Chinese. An English UI is not available yet.

## Why

You ask Claude Code, Codex or Cursor to run a long refactor or test suite, or start a large download, then step away for lunch, a meeting or the night. When you come back, the Mac fell asleep and the task stopped halfway.

KeepMyMacAwake turns "don't let the Mac sleep" into one button. When the time is up it ends by itself and the Mac sleeps normally again — no settings to remember to revert, no `caffeinate` in a terminal.

## Three steps

1. **Pick a scene**: Daily, Night, Lid closed on power, or Lid closed on the go. Duration and rules can be adjusted.
2. **Press Start** and lock the screen. Before the first closed-lid session, install the background component when prompted.
3. **It ends on time** and your Mac sleeps normally again. To check progress, stop, or add 15 minutes, click the cup icon in the menu bar.

## Features

- **One-click keep-awake** for 30 minutes, 1/2/8 hours, a custom 1–1440 minutes, or until you stop it; extend by 15 minutes at any time.
- **Menu bar status panel**: remaining time, expected end, elapsed time, power and battery, network, thermal state and the last session's end reason — plus start, stop and extend.
- **Lock the screen and leave**: lock-screen rules are untouched.
- **Keep running with the lid closed** after a one-time approval of the background component, on power or on battery.
- **Three screen modes**: let the display sleep, keep it on, or keep it on and dimmed for the night.
- **Automatic stop conditions**: unplugged power, battery at your limit, high thermal pressure, network loss (optional), or when these states cannot be read.
- **Reliable recovery**: the closed-lid sleep setting is owned by an independent helper that restores it if the app quits, crashes or stops responding for 20 seconds.
- **Last result**: see when and why last night's session ended.
- **Local only**: no telemetry; only your preferences and the most recent result are stored on your Mac.

| Scene | Defaults |
| --- | --- |
| 日常 Daily | 1 hour · lid open · power only · display may sleep |
| 夜间 Night | 8 hours · lid open · power only · dimmed display |
| 接电合盖 Lid closed on power | until stopped · lid closed · power only |
| 外出合盖 Lid closed on the go | 2 hours · lid closed · battery allowed · stops on network loss |

## Install

1. Download the latest `KeepMyMacAwake-…-macOS-universal.dmg` from [Releases](https://github.com/diguike/KeepMyMacAwake/releases) (macOS 14+, Apple Silicon and Intel).
2. Drag KeepMyMacAwake into Applications and open it.
3. Preview builds are signed with a development certificate and not notarized yet. If macOS blocks the first launch, choose **Open Anyway** in System Settings → Privacy & Security ([Apple guide](https://support.apple.com/en-us/102445)).
4. For closed-lid use, pick a lid scene, install the background component, allow KeepMyMacAwake in System Settings → General → Login Items & Extensions, and confirm with Touch ID or your password. Start once the component shows as connected.

**Upgrading**: in the old version, uninstall the background component under Settings (卸载后台组件…), replace the app, then install the component again from a lid scene. In the author's tests the existing system approval was kept.

Use it on a ventilated desk, never inside a bag. The thermal state comes from macOS and is not a temperature reading. KeepMyMacAwake keeps your Mac awake; it does not decide whether your AI task finished.

## FAQ

**Can't find the cup icon in the menu bar?** On MacBooks with a notch, extra menu bar icons can hide behind it. Quit a few menu bar apps or ⌘-drag the icon to the right. The control window that opens with the app can do everything too.

**Does it affect lock-screen or company device policies?** No. It only prevents idle sleep; it does not change lock-screen rules or bypass device management.

**How do I uninstall it?** Uninstall the background component under Settings first, then move the app to the Trash. Don't delete or move the app while a session is running.

## Status

The latest preview is [v0.5.0](https://github.com/diguike/KeepMyMacAwake/releases/tag/v0.5.0), with a warm orange theme, a number-first status card and the menu bar status panel; it is signed with a development certificate and not notarized yet. Ordinary keep-awake, expiry and night dimming are tested on a real Mac; closed-lid mode has worked in the author's own use, while a full multi-model validation matrix is still in progress ([status](docs/status.md), in Chinese). A Windows developer preview (WPF + system tray, plugged in with the lid open only) lives in the same repository without a public release.

## How it works

- Ordinary mode holds a public IOPMAssertion to prevent idle sleep and releases it when stopped.
- Closed-lid mode uses a signed, independent helper that sets the system-wide `pmset disablesleep`, with a time-limited lease, a 20-second disconnect deadline and a persisted recovery record. It refuses to take over if another tool already enabled it.
- Dimming is a temporary software overlay, not a hardware brightness change. "Connected" means macOS has a usable network path, not that the internet or your task's service is reachable.

## Build from source

<details>
<summary><b>Mac</b></summary>

Requires macOS 14+ and Xcode or the Command Line Tools (Swift 5.9+).

```sh
git clone https://github.com/diguike/KeepMyMacAwake.git
cd KeepMyMacAwake
swift test
./scripts/build-macos.sh
open dist/KeepMyMacAwake.app
```

The default build is unsigned and supports lid-open use only. Closed-lid mode needs a certificate-signed build:

```sh
CONFIGURATION=release SIGN_IDENTITY='Apple Development: Your Name (TEAMID)' ./scripts/build-macos.sh
```

README images are rendered offscreen by `AWAKE_SCREENSHOTS=/tmp/shots swift test --filter ScreenshotTests` and composed with `macos/scripts/compose-overview.swift`.

</details>

<details>
<summary><b>Windows developer preview</b></summary>

Requires the .NET 10 SDK. See [windows/README.md](windows/README.md) and [the GitHub build guide](docs/github-windows-build.md) (in Chinese).

</details>

See [AGENTS.md](AGENTS.md) and [CONTRIBUTING.md](CONTRIBUTING.md) before contributing. Made by [diguike](https://github.com/diguike), released under the [MIT License](LICENSE). If it helps you, a star or a share is very welcome.
