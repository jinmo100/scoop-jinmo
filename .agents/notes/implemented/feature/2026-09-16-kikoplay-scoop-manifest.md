# Agent Note: 为 KikoPlay 添加 Scoop Manifest

Status: implemented

## Problem

宿主机从 `apps` bucket 安装 KikoPlay 2.1.0 时，Scoop 能下载并校验 `2.1.0-windows.7z`，但创建 shim 失败：Manifest 直接把 `KikoPlay.exe` 当作解压根目录下的文件，而上游归档实际包含版本目录 `2.1.0\KikoPlay.exe`。这使安装结果被 Scoop 判定为不完整。当前个人 Bucket 还没有 KikoPlay 的独立 Manifest，无法提供已修复的来源。

## Decision

在 `bucket/kikoplay.json` 中维护上游 KikoPlay 的正式版 Windows x64 绿色归档，沿用个人 Bucket 的架构和维护流程（参见 [个人 Bucket 架构](../architecture/2026-09-14-personal-scoop-bucket.md) 与 [Scoop 维护流程](../process/2026-09-14-scoop-bucket-maintenance-skill.md)）：

- 当前版本为 GitHub 正式 Release `2.1.0`，资产为 `2.1.0-windows.7z`，URL 为 `https://github.com/KikoPlayProject/KikoPlay/releases/download/2.1.0/2.1.0-windows.7z`，SHA-256 为 `ce8f8509a660e35ac20a20609a4e7c67ec264c19075cb8a24e6c5025d609a223`。
- 归档根目录是 `2.1.0`，其中存在 `KikoPlay.exe`；Manifest 使用 `extract_dir: "2.1.0"` 去除版本目录，再将 `KikoPlay.exe` 暴露为 shim，并创建同名快捷方式。
- 使用稳定版 GitHub `checkver`，`autoupdate` 用完整 `$version` 生成 Release URL，并将新版本目录设为动态 `extract_dir`。
- 上游 `globalobjects.cpp` 将 Windows 的用户数据目录设置为应用目录下的 `data/`，`Common/dbmanager.cpp` 与 `Common/logger.cpp` 分别将数据库、设置和日志写入该路径，因此声明 `persist: ["data"]` 保护升级时的用户数据；不持久化包含随版本发布的 `extension/`，避免阻止内置扩展更新。

## Alternatives considered

### 继续使用 `apps` bucket 的 KikoPlay Manifest

优点是无需维护本地 Bucket。放弃原因是现有 Manifest 的初始版本没有配置 `extract_dir`，与归档布局不匹配，已经复现 shim 创建失败。

### 将 shim 路径硬编码为 `2.1.0/KikoPlay.exe`

优点是可以直接匹配当前归档。放弃原因是版本更新后目录名会改变，Manifest 会在更新时再次失效；用当前版本的 `extract_dir` 和自动更新时的 `$version` 更稳定。

### 将 `data` 与 `extension` 一并持久化

优点是可以同时保留 KikoPlay 的用户数据库、设置、日志以及用户可能修改的扩展。放弃整体持久化的方案，因为 Windows 归档中的 `extension/` 同时承载随版本发布的内置扩展，持久化它会阻止新版本覆盖这些文件；最终只持久化已由上游代码确认的 `data/`。

## Consequences

- `jinmo` Bucket 可以独立提供可正确创建 shim 的 KikoPlay Manifest，绕过当前 `apps` Manifest 的解压目录问题。
- 维护者仍需关注上游是否改变归档根目录、可执行文件名或 Windows 发布资产命名；这些变化会使自动更新或安装验证失败。
- `persist: ["data"]` 会将 KikoPlay Windows 的数据库、设置和日志保留在 Scoop 的持久化目录中；`extension/` 不持久化，以便随新版本更新内置扩展。
- GitHub API/资产检查和 Manifest 更新不等于宿主机已安装应用更新；宿主机仍需单独运行 Scoop 命令。

## Verification

- GitHub Releases API 确认 `2.1.0` 是最新非 draft 正式版，并确认 Windows 资产、URL、大小 `362039021` bytes 与 digest；仓库 API 确认许可证文件存在。
- 使用 7-Zip 检查归档：根目录为 `2.1.0`，存在 `2.1.0\KikoPlay.exe`；`7z t` 报告 `Everything is Ok`。
- `python3 -m json.tool bucket/kikoplay.json` 通过。
- PowerShell 7 运行 Scoop `checkver.ps1` 返回 `kikoplay: 2.1.0`，`checkurls.ps1` 返回 1 个 URL 正常，`checkhashes.ps1` 返回 `kikoplay: OK`。
- 在临时复制的 Manifest 中将版本降为 `2.0.0` 后运行 `checkver -Update`，确认完整写回 `2.1.0`、资产 URL、digest 和 `extract_dir: "2.1.0"`；生产 Manifest 未被临时测试改写。
- 仓库自带 `bin/test.ps1` 首次未能执行，因为宿主 PowerShell 环境缺少 `BuildHelpers` 2.0.1；随后在临时目录加载 CI 固定的 `BuildHelpers` 2.0.1 与 `Pester` 5.7.1，并用不含 `.codegraph`/本地未跟踪文件、模拟 Windows CRLF 换行的干净工作树运行完整测试，8 个测试（包含 `kikoplay.json`）全部通过。直接在当前 WSL 工作树运行会把环境文件和 LF 换行纳入 Scoop 风格检查，因此不作为最终测试结果。
- 按 `AGENTS.md` 要求运行 `npm run verify-notes`，但仓库没有 `package.json` 或 `verify-notes` script，命令以 `Missing script: "verify-notes"` 失败；该仓库级笔记校验基础设施缺失，未为本次 Manifest 添加无关的 Node 工具链。
