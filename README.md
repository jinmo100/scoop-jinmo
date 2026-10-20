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
