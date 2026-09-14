# Agent Note: 维护个人 Scoop Bucket 与测试版自动更新

Status: implemented

## Problem

Scoop 的公共 Bucket 不一定包含用户需要的软件，或只包含正式版。当前需要安装 `any-listen-desktop` 的最新 GitHub prerelease，并希望以后能够以相同方式维护其他缺失软件。直接依赖 `kkzzhizhou/scoop-apps` 会受其收录、合并和 Manifest 更新节奏影响，也不能把 `releases/latest` 用作测试版来源。

## Decision

个人 Bucket 使用 `jinmo100/scoop-jinmo`，遵循 `ScoopInstaller/BucketTemplate` 的结构。当前 Bucket 维护 `any-listen-desktop` 的 Windows x64 green 归档，并包含官方 CI 与 Excavator workflow；Excavator 每 4 小时检查一次 Manifest，发现更新后提交版本、URL 和 hash 变更。

Any Listen 的 `checkver` 直接读取 GitHub Releases API（`per_page=100`），筛选非 draft 的 prerelease，按 `published_at` 倒序取最新版本，再提取完整的 prerelease 版本号（例如 `0.9.0-beta.4`）。`autoupdate` 使用 `$version` 生成完整的 Release asset URL，不使用会丢失 `-beta.N` 的 `$matchHead`。Scoop 的 GitHub hash 处理逻辑读取对应 asset 的 digest，失败时可退回本地计算。

第一版不复制 `kkzzhizhou/scoop-apps` 的外部 `AppsUtils.psm1` 数据挂载脚本，避免个人 Bucket 依赖另一个 Bucket 的内部模块；Any Listen 保持默认 `%APPDATA%\\any-listen` 数据路径。Manifest 初期只声明 x64，ARM64 与数据持久化封装留待真实安装验证后再决定。

## Alternatives considered

### 复制或继续依赖 `kkzzhizhou/scoop-apps`

优势是无需维护独立仓库，且其中已有 Any Listen Manifest。放弃原因是当前 Manifest 版本滞后，测试版筛选依赖不可靠，并且外部聚合仓库的变更和脚本模块不受个人控制。

### 使用 `checkver: github` 或 `/releases/latest`

优势是配置简单、符合多数正式版 Manifest。放弃原因是 GitHub `latest` 不代表 prerelease，无法稳定发现 Any Listen 的 beta 版本。

### 仅在本机建立本地 Bucket并手动维护

优势是最快、不需要 GitHub Actions。放弃原因是无法跨设备同步，也无法自动检查和提交版本、URL、hash 更新。

### 使用 `any-listen-desktop-beta` 作为独立 Manifest 名称

优势是与正式版在 Scoop 的版本比较中完全隔离。当前未采用，因为它会带来重复的 shim、快捷方式和 `%APPDATA%` 目录竞争；现阶段使用同名 Manifest，并通过 `jinmo/any-listen-desktop` 明确 Bucket 来源。

## Consequences

- 可用 `scoop bucket add jinmo https://github.com/jinmo100/scoop-jinmo` 添加 Bucket，并用 `scoop install jinmo/any-listen-desktop` 安装。
- `scoop update` 负责拉取 Scoop 与 Bucket；`scoop update any-listen-desktop` 才会更新已安装应用。测试版不会因为 Bucket Manifest 更新而自动替换本机程序。
- GitHub API 的本地匿名请求会受到速率限制；维护命令可以临时将现有 `gh auth token` 放入 `SCOOP_GH_TOKEN`，命令结束后删除环境变量。GitHub Actions 使用其内置 token。
- 上游改变 asset 命名、删除 prerelease 或发布没有预期 Windows 资产的 prerelease 时，自动更新会失败或需要修改 Manifest；CI、`checkver` 和安装测试是更新门禁。
- Scoop 将正式版视为高于相同基础版本的 prerelease；从稳定版切换到 beta 可能需要卸载重装。Any Listen 的稳定版与测试版不建议同时运行。

## Verification

- `bucket/any-listen-desktop.json` 通过 Python JSON 解析。
- Manifest 的 `0.9.0-beta.4`、x64 green asset URL 和 SHA256 与 GitHub Release API 的 `digest` 一致。
- 在 Windows PowerShell 5.1 中使用 `SCOOP_GH_TOKEN` 执行 `bin/checkver.ps1 any-listen-desktop`，结果为 `0.9.0-beta.4`。
- 使用临时的 beta.3 Manifest 执行 `checkver -Update`，验证了完整的 `-beta.4` URL、版本号和 digest 会被自动写回。
- 推送到 `https://github.com/jinmo100/scoop-jinmo` 后，GitHub Actions 的 CI push run 成功，手动触发的 Excavator run 也成功且没有产生无关更新。
- 宿主机执行 `scoop bucket add jinmo ...` 与 `scoop info jinmo/any-listen-desktop` 成功；使用 PowerShell 7 的 Scoop 实际安装成功，`anylisten.exe` shim、快捷方式和应用根目录可执行文件均已验证。Windows PowerShell 5.1 在本机缺少 `Get-FileHash`，导致第一次 hash 校验失败；这属于宿主 PowerShell 环境问题，改用 `pwsh` 后校验与安装成功。
