# scoop-jinmo

Personal [Scoop](https://scoop.sh) bucket for applications that are missing from my regular buckets or need a prerelease channel.

## Add the bucket

```powershell
scoop bucket add jinmo https://github.com/jinmo100/scoop-jinmo
```

## Install Any Listen prerelease

This manifest follows the newest non-draft GitHub prerelease of Any Listen Desktop and currently packages the Windows x64 green archive.

```powershell
scoop install jinmo/any-listen-desktop
```

If `any-listen-desktop` was previously installed from another bucket, uninstall it first so the source is unambiguous:

```powershell
scoop uninstall any-listen-desktop
scoop install jinmo/any-listen-desktop
```

## Install AyuGram-Jinmo test builds

This manifest follows the newest non-draft GitHub prerelease of [jinmo100/AyuGramDesktop](https://github.com/jinmo100/AyuGramDesktop), a personal AyuGram fork. The published archives are Windows x64 portable **Debug test builds** with the built-in updater disabled; version updates go through Scoop only.

```powershell
scoop install jinmo/ayugram-jinmo
```

Account data lives in `persist\ayugram-jinmo\TelegramForcePortable\tdata`, so `scoop update ayugram-jinmo` keeps the logged-in session. Quit the application before updating.

## Install DSH Tauri (community DeepSeek Harness desktop)

`dsh-tauri` packages the community Tauri desktop build of [DeepSeek Harness](https://github.com/dsh-tauri/deepseek-harness-desktop). The package name follows the upstream product name (`DSH Tauri`) rather than the repository name, because many projects are called `deepseek-harness-desktop` and DeepSeek also ships its own [official desktop app](https://www.deepseek.com/harness).

```powershell
scoop install jinmo/dsh-tauri
```

The manifest unpacks the vendor MSI into the Scoop app directory. Runtime and user data stay outside it (`%APPDATA%\dsh-tauri` and `%USERPROFILE%\.dsh`), so `scoop update dsh-tauri` keeps settings and sessions.

After the first launch, turn off **Settings → Auto update**: the built-in updater runs the vendor installer and would create a second, non-Scoop installation. Update with `scoop update dsh-tauri` instead. The first launch still downloads the Node runtime and Harness core, and the embedded UI needs the WebView2 Runtime.

## Install Legado Reader

`legado-reader` packages [hadc188/reader](https://github.com/hadc188/reader), a community desktop port of the Android **Legado (阅读 3.0)** reader. It is a single-user local reader: it imports Legado book sources, RSS feeds and backups, but ships no book sources and runs no server.

```powershell
scoop install jinmo/legado-reader
```

The package is deliberately called `legado-reader` instead of `reader`. A plain `reader` manifest already exists in other buckets for a different program (`binbyu/Reader`, which also installs `Reader.exe`), and Scoop resolves app names across all buckets: with a duplicate it only prints a warning and picks the first bucket. The Start Menu entry is `Reader (Legado)` for the same reason — Scoop names the shortcut file after the display name, so a bare `Reader` would overwrite the other program's shortcut and could be removed by its uninstall.

Library data lives in `persist\legado-reader\data`, so `scoop update legado-reader` keeps books, sources and settings. If you previously installed the vendor setup or the winget package, its `data` folder sits next to that copy's `Reader.exe`; copy it into the persist folder before the first launch.

Update through Scoop, not through the app. The in-app update button replaces `Reader.exe` inside the Scoop version directory without updating Scoop's metadata; turning off **Auto check updates** (自动检查更新) in Settings avoids the prompt. The app is x64 only and needs the WebView2 Runtime.

## Install DS Bot

`ds-bot` packages [Fei2411/DS-Bot](https://github.com/Fei2411/DS-Bot), a desktop app that runs a team of long-lived bots on top of DeepSeek Harness: main bots, private bots, bot-to-bot messages and group chats. Upstream publishes **only** an NSIS installer for Windows, so the manifest downloads it, has Scoop unpack the NSIS container with 7-Zip (`#/dl.7z`) and expands the inner `app-64.7z` in `pre_install`. What lands in the Scoop app directory is a plain `win-unpacked` layout: no registry entries, no Start Menu entry beyond Scoop's own shortcut, and no elevation prompt.

```powershell
scoop install jinmo/ds-bot
```

The app carries its own DSH runtime (291 MiB download, about 1.2 GB unpacked), so neither Node.js nor `dsh` has to be installed first; on the first launch you only configure a model in Settings. Models, bots and chats live in `%USERPROFILE%\.ds-bot`, the bot workspace in `%USERPROFILE%\DS Bot` and logs in `%APPDATA%\DS Bot` — nothing is written to the install directory, so `scoop update ds-bot` keeps everything.

`pre_install` deletes `resources\app-update.yml`. The bundled `electron-updater` feed points at GitHub releases, sets `autoDownload` and `autoInstallOnAppQuit`, and has no off switch in the UI: left in place it would download the vendor installer and create a second, non-Scoop installation. The visible cost is that the About page reports a failed update check every few hours; update with Scoop instead. The app is x64 only, and uninstalling leaves `%USERPROFILE%\.ds-bot`, `%USERPROFILE%\DS Bot` and `%APPDATA%\DS Bot` behind.

## Update

Update Scoop and the local bucket clone:

```powershell
scoop update
```

Update the installed application separately:

```powershell
scoop update any-listen-desktop
```

The GitHub Actions Excavator workflow checks manifests every four hours. Scheduled Actions can be delayed; use the workflow's manual dispatch when an immediate refresh is needed.

## Maintain manifests locally

From a Windows PowerShell checkout:

```powershell
.\bin\checkver.ps1 any-listen-desktop
.\bin\checkver.ps1 any-listen-desktop -Update
.\bin\checkhashes.ps1 any-listen-desktop
.\bin\checkurls.ps1 any-listen-desktop
.\bin\formatjson.ps1
```

GitHub API requests are rate-limited when unauthenticated. For a local maintenance run, pass the token from your existing GitHub CLI login only for the current PowerShell process; it is not stored by this repository:

```powershell
$env:SCOOP_GH_TOKEN = gh auth token
try { .\bin\checkver.ps1 any-listen-desktop -Update } finally { Remove-Item Env:SCOOP_GH_TOKEN -ErrorAction SilentlyContinue }
```

GitHub Actions receives an authenticated token through the official Excavator action.

The Any Listen manifest intentionally queries the GitHub Releases API instead of `/releases/latest`, because `/releases/latest` excludes prereleases. Its `autoupdate` URL uses the complete `$version`, including `-beta.N`.

The first version does not depend on helper modules from `kkzzhizhou/scoop-apps`; Any Listen keeps its normal `%APPDATA%\\any-listen` data path.
