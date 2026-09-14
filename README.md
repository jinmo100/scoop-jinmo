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
