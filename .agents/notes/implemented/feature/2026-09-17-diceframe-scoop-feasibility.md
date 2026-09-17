# Agent Note: 评估将 DiceFrame 加入个人 Scoop Bucket

Status: implemented

## Problem

需要判断 `diceframe/diceframe` 是否适合加入当前 `jinmo100/scoop-jinmo`，目标是让 Windows 用户通过 Scoop 安装、启动、更新和保留 DiceFrame 的本地运行数据，而不是把上游源码重新打包进 Bucket。

本次评估以 2026-09-17 的 GitHub Releases API、上游 README、发布工作流和源码为一手来源：

- [上游仓库](https://github.com/diceframe/diceframe)
- [最新正式版 v2.6.0](https://github.com/diceframe/diceframe/releases/tag/v2.6.0)
- [最新预览版 v2.6.1-beta.1](https://github.com/diceframe/diceframe/releases/tag/v2.6.1-beta.1)
- [Windows 发布工作流](https://github.com/diceframe/diceframe/blob/main/.github/workflows/release.yml)
- [Windows 便携版说明](https://github.com/diceframe/diceframe/blob/main/README_EN.md)
- [便携版启动器源码](https://github.com/diceframe/diceframe/blob/main/src/launcher/DiceFrameLauncher.cs)
- [运行时路径定义](https://github.com/diceframe/diceframe/blob/main/src/webui/runtime_config.py)
- [运行日志路径定义](https://github.com/diceframe/diceframe/blob/main/src/runtime_logging.py)

## Decision

DiceFrame 已加入当前 Bucket，Manifest 使用上游正式版 `windows-portable` 资产，仅声明 Windows x64，并通过 `persist` 保留运行数据。当前实现建议用户以 Scoop 作为唯一应用更新入口；上游 WebUI 内置更新器作为已知边界，不在 Manifest 中额外包装。

### 上游发布事实

- 仓库许可证为 `AGPL-3.0`，项目是可自部署的 AI TRPG/WebUI 应用；Bucket 只引用上游 Release 资产，不重新分发改造后的二进制。
- GitHub API 返回的最新正式版为 `v2.6.0`，发布时间为 `2026-09-15T13:52:39Z`；最新预览版为 `v2.6.1-beta.1`。仓库近期活跃，但正式版本从 2026-08-12 到 2026-09-15 发布频率很高。
- 正式版便携资产为：
  - URL：`https://github.com/diceframe/diceframe/releases/download/v2.6.0/DiceFrame-v2.6.0-windows-portable.zip`
  - GitHub asset 大小：`32082194` bytes
  - GitHub API digest：`sha256:58a2aa50d61bc40eaad8ab4dd7c8bc883316bd1b7bd9a6f864c887a841da8517`
  - [SHA256SUMS](https://github.com/diceframe/diceframe/releases/download/v2.6.0/SHA256SUMS) 给出的 hash 与 API digest 相同；下载后的本地 SHA-256 也相同，`unzip -t` 通过。
- 该压缩包是 Windows x64 的自包含便携版：根目录为 `DiceFrame-v2.6.0-windows-portable/`，其中有 `DiceFrame.exe`、`python/python.exe`、`app/web_server.py` 和已安装的 Python site-packages。解压后约 2,188 个文件；`file` 将启动器和 bundled Python 都识别为 PE32+ x86-64。
- 另一个 `DiceFrame-v2.6.0-windows.zip` 虽然体积较小，但根目录只有源码、`web_server.py`、`web_ui.bat` 和前端源文件，没有 `DiceFrame.exe` 或 bundled Python；上游 README 将其标为源码运行包，不应作为普通 Scoop 应用的资产。
- 发布工作流在 Windows runner 上构建 portable 包、附带 bundled Python 3.11 runtime 和依赖，并为每个 zip 生成 SHA-256 sidecar；正式版与带 `-beta` 的预览版由 tag 区分。

### 已落地的 Manifest 契约

`bucket/diceframe.json` 已按以下契约落地：
Manifest 直接提交到 `bucket/diceframe.json`，不再只是建议形状：

- `version`: `2.6.0`。
- 仅声明 `64bit`；portable 构建使用 `python-*-embed-amd64.zip`，当前没有 ARM64 资产。
- 64-bit URL 指向 `DiceFrame-v$version-windows-portable.zip`，hash 使用同一 Release 的 digest。
- 当前版本的 `extract_dir` 为 `DiceFrame-v2.6.0-windows-portable`；`autoupdate` 中必须使用动态的 `DiceFrame-v$version-windows-portable`，不能硬编码当前版本目录。
- `bin` 指向 `DiceFrame.exe`，并提供 `DiceFrame.exe` 的快捷方式；不需要 `installer`、`post_install` 或外部 Python/Node 依赖。
- `persist` 至少包含 `data`，建议同时包含 `logs`。启动器在安装根目录创建这两个目录，并通过 `TRPG_DATA_DIR` 把应用数据指向 `data`；运行时日志默认写入安装根目录的 `logs`。`data` 包含配置、凭据、访问 token、存档/模板以及 updater 状态，不能随 Scoop 版本目录删除。
- 正式版使用 `checkver: "github"` 即可让 Scoop 跟随 GitHub 的 stable/latest 版本；不要把 `v2.6.1-beta.1` 混入正式版 Manifest。`autoupdate` URL 需保留完整 `$version`，包括未来可能出现的预发布后缀（如果另行维护 preview Manifest）。

### Scoop 生命周期边界

上游便携版的 `DiceFrame.exe` 不是纯 shim，而是一个启动器：它从自身安装根目录启动 `app/web_server.py` 和 bundled Python，默认 WebUI 端口为 `18000`，并会打开浏览器。它还实现了自己的旁路更新、健康检查、版本目录和回滚机制。

因此 Scoop Manifest 可以安装它，但用户必须选择一个更新入口：推荐由 Scoop 管理版本，避免在 DiceFrame WebUI 的“版本更新”中再进行一次应用自更新。上游 updater 会在安装根目录下使用 `versions/` 和 `data/_updater/current.json`；`data` 持久化后，Scoop 更新仍能保留用户数据，但内部 updater 可能让实际运行版本暂时偏离 Manifest 版本，且下一次 Scoop 更新会替换 Scoop 的版本目录。该冲突不是当前加入 Bucket 的技术阻塞，但必须在 Windows smoke test 和使用说明中明确。

## Alternatives considered

### 使用 `windows.zip` 作为 `diceframe` Manifest

最强理由是下载包约 15 MB，且包含完整源码和 `web_ui.bat`，看起来更接近仓库的主发布物。

放弃原因是它没有 Windows 可执行启动器和 bundled Python；运行需要用户自己安装 Python、Node.js、npm 依赖并构建前端，不能由普通 Scoop Manifest 保证可重复安装、卸载和升级。

### 直接使用 `windows-portable.zip`，但不声明 `persist`

最强理由是 Manifest 最简单，且 portable 包已经能自包含启动。

放弃原因是启动器会把配置、密钥、存档、模板和 updater 状态写入安装目录的 `data`，Scoop 版本升级会删除旧目录，未持久化会造成用户数据和凭据丢失；日志也会写入安装根目录。

### 跟随 `v2.6.1-beta.1` 等预览版

最强理由是上游更新很快，预览版能更早获得功能和修复；当前预览资产同样提供 Windows portable zip 和 digest。

当前不采用的原因是 Bucket 现有正式版与预览版职责尚未分离，而上游短期发布频率很高；把 beta 当正式版会造成版本噪声和稳定性预期错误。如果以后要提供预览渠道，应使用独立命名的 Manifest，并保留完整的 `-beta.N` 版本。

### 改为提供 Docker 镜像或源码包

最强理由是 DiceFrame 同时维护 Docker 发布流，Docker 更适合服务器部署且数据卷边界更明确。

放弃原因是当前项目是 Windows Scoop Bucket，Scoop Manifest 不负责安装 Docker/容器运行时；这会改变软件类型和用户操作边界。Docker 应作为另一个部署渠道，不应替代 Windows portable Manifest。

### 等上游稳定并停止自更新后再加入

最强理由是可以避开高频 Release 和内置 updater 与 Scoop 的双重更新问题。

当前不视为技术阻塞：上游已经有稳定 tag、完整的 x64 portable 资产、哈希和启动器；应把高频更新和双更新器记录为风险，并用验收测试决定是否接受维护成本。

## Verification

- `bucket/diceframe.json` 已创建，`python3 -m json.tool`、版本/hash/`extract_dir` 语义检查通过；Manifest schema 在 Scoop Pester 测试中通过。
- PowerShell 7 运行 `checkver.ps1 diceframe` 返回 `2.6.0`；`checkurls.ps1 diceframe` 通过；`checkhashes.ps1 diceframe` 返回 `diceframe: OK`。PowerShell 5.1 因宿主缺少 `Get-FileHash` 无法完成 hash 检查，改用仓库 CI 同样支持的 PowerShell 7 完成。
- 在临时复制并降级到 `2.5.9` 的 Manifest 上运行 `checkver -Update`，确认写回 `2.6.0`、portable URL、正确 hash 和动态 `extract_dir`；生产 Manifest 未被临时测试改写。
- 在排除 WSL `.codegraph` 文件、模拟 Windows CRLF 的临时工作树中运行完整 Scoop Pester 测试：9 个测试全部通过，其中包含 `diceframe.json` schema 测试。直接 WSL 工作树的测试会被 `.codegraph` socket/WAL 和 LF 换行干扰，因此不作为最终结果。
- 在真实 Windows x64 Scoop 环境从本地 Manifest 安装 `diceframe`，启动 `DiceFrame.exe` 后 `http://127.0.0.1:18000/` 返回 HTTP 200，并确认 `data`、`logs` 被持久化；测试应用随后已卸载并清理。
- 使用临时本地测试 Bucket 验证了 `2.5.9 -> 2.6.0` 的真实 Scoop 更新：hash 校验通过，写入 `data/scoop-update-sentinel.txt` 的哨兵文件在更新后仍保留；测试 Bucket、应用和持久化数据均已清理。
- 未主动触发 DiceFrame WebUI 内置更新器；实现和使用约定以 Scoop 为唯一版本管理入口，内置 updater 与 `versions/` 的冲突仍作为后续维护风险记录。

## Consequences

- `jinmo` Bucket 现在可以通过 `scoop install jinmo/diceframe` 安装 DiceFrame 正式版；Manifest 只跟随 stable GitHub Release，当前版本为 `2.6.0`。
- Scoop 更新会保留 `data` 与 `logs`；用户仍需在 DiceFrame WebUI 中配置 AI provider、模型和网络服务，安装成功不代表无需配置即可开始对局。
- 上游正式版发布频率高，Excavator 可能产生较多 Manifest 更新；上游内置 updater 与 Scoop 双重更新的边界需要在未来 README/Manifest 文案中持续提醒。
- 当前只提供 Windows x64；portable 资产使用 bundled Python，不提供 ARM64 原生 Manifest。
- 上游为 AGPL-3.0-or-later；本 Bucket 只引用官方 Release，不修改或重新打包二进制。
