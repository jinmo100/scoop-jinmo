---
name: scoop-bucket-maintenance
description: Maintain this repository's Scoop bucket: add or update manifests, package missing Windows applications, follow GitHub stable/prerelease/Nightly releases, repair checkver/autoupdate/hash issues, verify local Scoop installs, or validate GitHub Actions updates. Use when the user asks to add software to this bucket, update a manifest, package a GitHub release, or diagnose a Scoop bucket update/install failure.
---

# Scoop Bucket Maintenance

## Iron law

**Anchor every Manifest to a verified upstream release asset and its digest before claiming success.** For prereleases, read the GitHub Releases API, preserve the complete version (including `-alpha`, `-beta`, `-rc`, or build suffixes), and make the generated URL resolve to the exact asset.

## Workflow

### 1. Establish the target and channel ⚠️ REQUIRED

- Inspect the existing `bucket/`, `bin/`, `.github/workflows/`, and `README.md` before editing.
- Identify the upstream repository, Windows architecture, packaging format, executable path, and release channel: stable, prerelease, preview, or nightly.
- Use `gh` for GitHub repositories, releases, assets, Actions, and API calls. Use browser tools only when the task genuinely requires rendered-page interaction.

**Done when:** the desired channel and exact Windows asset are known, or a concrete upstream blocker is reported.

### 2. Verify upstream release facts ⚠️ REQUIRED

For a GitHub release, inspect the list and then the selected tag:

```bash
gh api "repos/OWNER/REPO/releases?per_page=100" \
  --jq '.[] | [.tag_name, (.prerelease|tostring), .draft, .published_at] | @tsv'

gh api "repos/OWNER/REPO/releases/tags/TAG" \
  --jq '{tag: .tag_name, prerelease: .prerelease, assets: [.assets[] | {name, digest, url: .browser_download_url, size}]}'
```

Select the newest release according to the requested channel and `published_at`; inspect asset names and digests from the selected release. Do not infer an asset name from the tag alone.

For a prerelease channel, the default `checkver` shape is:

```json
"checkver": {
    "url": "https://api.github.com/repos/OWNER/REPO/releases?per_page=100",
    "script": [
        "$releases = ConvertFrom-Json $page",
        "$release = $releases | Where-Object { $_.prerelease -and -not $_.draft -and $_.published_at } | Sort-Object { [DateTime]$_.published_at } -Descending | Select-Object -First 1",
        "$release.tag_name"
    ],
    "regex": "^v(\\d+(?:\\.\\d+)*-[0-9A-Za-z][0-9A-Za-z.-]*)$"
}
```

Adapt the filter when the upstream has a distinct preview/nightly rule. A simple `"checkver": "github"` is appropriate only when the requested channel is the stable `/releases/latest` channel.

**Done when:** the chosen tag, exact asset URL, digest, and executable/archive layout are recorded from a primary source.

### 3. Author or update the Manifest ⚠️ REQUIRED

- Keep the Manifest name stable unless stable and preview channels must coexist.
- Put the exact current version, URL, and hash in the architecture block.
- Use the complete `$version` in `autoupdate` URLs. For `0.9.0-beta.4`, `$version` must remain `0.9.0-beta.4`; do not use `$matchHead` where the asset or tag includes the suffix.
- For GitHub release assets, let Scoop's GitHub hash handling read the asset digest; use an upstream checksum file when one is more reliable.
- Reuse only helpers present in this repository. Do not copy a third-party bucket's private `AppsUtils.psm1` or silently create a cross-bucket dependency.
- Add `bin`, `shortcuts`, `persist`, installer, or uninstaller entries only after verifying the archive's actual layout and runtime behavior.

**Done when:** every URL template expands to a real upstream asset for the selected version, and every executable/shortcut path is justified by the archive or an installation smoke test.

### 4. Validate locally ⚠️ REQUIRED

First validate syntax without changing the Manifest:

```bash
python3 -m json.tool bucket/APP.json >/dev/null
```

GitHub API calls may be rate-limited. For local Scoop checks, use the existing `gh` login only for the current PowerShell process; never print or commit the token:

```powershell
$env:SCOOP_GH_TOKEN = gh auth token
try {
    .\bin\checkver.ps1 APP
    .\bin\checkurls.ps1 APP
    .\bin\checkhashes.ps1 APP
}
finally {
    Remove-Item Env:SCOOP_GH_TOKEN -ErrorAction SilentlyContinue
}
```

Test `-Update` on a temporary copy or a deliberately lowered temporary version before touching the production Manifest. Confirm that it writes the full version, URL, and hash. On this host, use `pwsh` for Scoop hash/install checks when Windows PowerShell 5.1 lacks `Get-FileHash`.

**Done when:** JSON parsing, `checkver`, URL checks, hash checks, and the temporary autoupdate path all pass, or each failure is attributed to a reproducible environment/upstream blocker.

### 5. Verify Actions and host boundaries ⚠️ REQUIRED

After publishing a requested repository change:

```bash
gh run list --repo OWNER/BUCKET --workflow CI --limit 5
gh run list --repo OWNER/BUCKET --workflow Excavator --limit 5
gh workflow run Excavator --repo OWNER/BUCKET --ref main
```

Wait for the run and inspect its conclusion/log. Excavator updates the repository Manifest; it does **not** update software already installed on a user's machine. The local commands remain separate:

```powershell
scoop update
scoop update APP
```

Treat adding/removing buckets, installing/updating software, creating a GitHub repository, and pushing commits as external state changes. Perform them only when the user requested or confirmed them; otherwise report the exact command for the user.

**Done when:** the relevant CI/Excavator conclusion is known and the report clearly distinguishes repository Manifest updates from local application updates.

## Anti-patterns

- Do not use `/releases/latest` to discover a prerelease.
- Do not guess asset filenames, architecture support, executable paths, or hashes.
- Do not drop a prerelease suffix by substituting `$matchHead` for `$version`.
- Do not use a browser or `agent_browser` for a GitHub fact that `gh` or the GitHub API can provide.
- Do not claim that GitHub Actions automatically updates the user's installed application.
- Do not claim success without a passing validation result or a clearly stated blocker.
- Do not expose `gh auth token`, put it in a file, or commit it.

## Completion report

Report, in order:

1. Manifest path, package version, channel, architecture, exact asset, and digest.
2. `checkver` strategy and why it matches the requested channel.
3. Local validation results and any host-specific limitation.
4. CI/Excavator result and repository URL, if published.
5. Exact commands for adding the bucket, updating the bucket, and updating the installed app.
6. Any remaining upstream or user-only action.

## Final checklist

- [ ] Upstream facts came from `gh`/GitHub API or another primary source.
- [ ] Requested channel is explicit; prerelease uses Releases API filtering.
- [ ] Current URL and digest match the selected release asset.
- [ ] `$version` preserves the full upstream version.
- [ ] Manifest JSON and local Scoop checks pass.
- [ ] Host installation changes and remote pushes were authorized.
- [ ] CI/Excavator status is verified before success is reported.
- [ ] The report separates automatic Manifest updates from local app updates.
