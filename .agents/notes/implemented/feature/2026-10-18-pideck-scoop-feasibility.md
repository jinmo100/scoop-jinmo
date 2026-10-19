# Agent Note: 评估将 PiDeck 加入个人 Scoop Bucket

Status: implemented

## Problem

需要评估并将 [ayuayue/PiDeck](https://github.com/ayuayue/PiDeck) 加入本仓库 `jinmo100/scoop-jinmo`，使 Windows 用户能够通过 Scoop 便捷安装、启动、更新和维护 PiDeck 桌面应用。

本次评估与落地以 2026-10-18 的 GitHub Releases API、上游发布工作流（`.github/workflows/release.yml`、`build-windows.yml`）、源码（`src/main/portableUserData.ts`、`src/main/update/createAutoUpdater.ts`、`src/main/index.ts` 等）以及实际资产归档内容为一手来源：

- 上游仓库：[ayuayue/PiDeck](https://github.com/ayuayue/PiDeck)
- 官网主页：[https://pideck.caoayu.top](https://pideck.caoayu.top)
- 最新正式版 Release：[v0.9.1](https://github.com/ayuayue/PiDeck/releases/tag/v0.9.1)
- Windows 发布工作流：[release.yml](https://github.com/ayuayue/PiDeck/blob/main/.github/workflows/release.yml)
- 数据目录决策源码：[portableUserData.ts](https://github.com/ayuayue/PiDeck/blob/main/src/main/portableUserData.ts)
- 内置更新器源码：[createAutoUpdater.ts](https://github.com/ayuayue/PiDeck/blob/main/src/main/update/createAutoUpdater.ts)

## Decision

PiDeck 已作为正式应用加入当前 Bucket，Manifest 落地于 `bucket/pideck.json`，使用上游正式版 `win.zip` 绿色分发资产，声明 Windows 64-bit 支持，并通过 `%APPDATA%\PiDeck` 隔离运行数据。

### 上游发布事实与资产选择

1. **软件定位与许可证**：
   - PiDeck 是基于 Electron 构建的开源桌面工作台，用于统一管理 PI / DSH Agent 会话、会话历史、Git 集成、内置终端、模型配置及插件管理。
   - 仓库许可证为 `MIT`。
2. **版本与发布渠道**：
   - 当前最新正式版为 `v0.9.1`（`published_at: 2026-10-18T14:38:14Z`，`prerelease: false`）。
   - 上游有清晰的正式版与开发版流转机制（正式版 tag `v*`，预发布版带 `-beta`）。
3. **Windows 资产选择**：
   - 使用官方构建的绿色解包归档 `PiDeck-0.9.1-win.zip`（133,994,630 字节）。解压后顶层即包含 `PiDeck.exe`、`resources/app.asar` 以及 Go 编写的后台 sidecars（`xue-index.exe`、`session-index.exe`、`file-index.exe`、`session-store.exe`）。无多余外层包装，最为适合 Scoop。
   - 放弃 `portable.exe`（单文件自解压，每次冷启动在 `%TEMP%` 解包）与 `setup.exe`（NSIS 安装器）。
4. **架构支持**：
   - 正式 Release 仅发布了 Windows x64 二进制，因此 Manifest 仅声明 `64bit`。

### 已落地的 Manifest 契约

`bucket/pideck.json` 按以下契约提交：

- `version`: `0.9.1`。
- `url`: `https://github.com/ayuayue/PiDeck/releases/download/v0.9.1/PiDeck-0.9.1-win.zip`。
- `hash`: `153b3273e6b40114d6e98aa4e87ab2f4e11d343ef1d03a59a966b00cd1b1eb9e`。
- `bin`: `"PiDeck.exe"`（在 Scoop 中创建 `pideck.exe` shim）。
- `shortcuts`: `[ [ "PiDeck.exe", "PiDeck" ] ]`（创建桌面与开始菜单快捷方式）。
- `checkver`: `"github"`，稳定跟随 GitHub `/releases/latest`。
- `autoupdate`:
  ```json
  "autoupdate": {
      "architecture": {
          "64bit": {
              "url": "https://github.com/ayuayue/PiDeck/releases/download/v$version/PiDeck-$version-win.zip"
          }
      }
  }
  ```

### Scoop 生命周期与数据边界

1. **用户数据落盘**：
   - 源码 `src/main/portableUserData.ts` 在未注入 `PORTABLE_EXECUTABLE_DIR` 时，数据存储于 `%APPDATA%\PiDeck`。
   - 在 Scoop 架构下，版本更新操作只会替换 `apps/pideck/<version>` 目录，不会触碰 `%APPDATA%\PiDeck`。因此配置、会话记录、SQLite 数据库在升级时天然安全保留。
   - 遵循 Scoop `extras` bucket 标准 GUI 应用规范，不强制声明 `persist` 或全局环境变量。
2. **内置更新器与 Scoop 协同**：
   - PiDeck 内置的 `electron-updater` 检测更新时下载的是 `setup.exe`，应用内触发更新会脱离 Scoop 托管。
   - 约定以 Scoop 作为唯一版本管理入口（`scoop update pideck`），建议在 PiDeck 设置中关闭“自动下载新版本”。

## Alternatives considered

### 使用 `PiDeck-*-portable.exe` 作为 Scoop 资产

最强理由是单 exe 便携版体积更小（~98MB），且文件名自带 portable 标识。

放弃原因：electron-builder 生成的 portable exe 实质是一个自解压包，每次运行都会在系统 `%TEMP%` 解压整个应用再启动，冷启动开销巨大，无法保留解压后的运行时缓存，也不便于 Scoop 管理解压文件与 sidecar 进程。

### 使用 `PiDeck-*-setup.exe` 并用 7-Zip 解压

最强理由是安装包体积适中，且为 Releases 中最显眼的主安装物。

放弃原因：NSIS 解压会产生 `$PLUGINSDIR` 等安装脚本临时文件，并非标准绿色文件布局；而上游官方已原生构建并发布了 `PiDeck-*-win.zip`（win-unpacked 绿色归档），直接使用官方绿色包解包更加纯净可靠。

### 强制设置 `PORTABLE_EXECUTABLE_DIR` 并配置 `persist: "data"`

最强理由是能够实现真正将所有数据集中在 `<scoop>/persist/pideck/data`，适合完全绿色的移动 U 盘环境。

放弃原因：
1. 若通过 Scoop `env_set` 设置全局 `PORTABLE_EXECUTABLE_DIR`，会严重污染系统环境，导致机器上所有其他基于 electron-builder 的便携软件发生行为异常。
2. 若通过 CMD 批处理包装器启动，会导致从开始菜单快捷方式启动应用时闪烁黑色控制台窗口，严重影响桌面软件用户体验。
3. `%APPDATA%\PiDeck` 独立于 Scoop 版本安装路径，Scoop 在 `scoop update` 时天然不会擦除 `%APPDATA%`，用户数据与 Go sidecar SQLite 数据库能够获得最佳稳定性。

### 跟随带 `-beta` 的开发分支 Release

最强理由是可以第一时间获取内嵌 DSH runtime 跨平台演进或新特性。

放弃原因：主 Manifest `pideck.json` 应优先保障稳定可用。上游采用双通道发布，带有 `-beta` 的预发布版本可能伴随破坏性改动。若后续有明确需求，可另行开设 `pideck-dev.json`。

## Verification

- `bucket/pideck.json` 已创建，`python3 -m json.tool` 语法校验通过。
- `.\bin\checkver.ps1 pideck` 成功识别出当前版本 `0.9.1`。
- `.\bin\checkurls.ps1 pideck` 校验通过，下载链接 `153b3273e6b4...` 可达。
- PowerShell 7 下 `.\bin\checkhashes.ps1 pideck` 完整下载并校验通过（`pideck: OK`），哈希与 GitHub Release API digest 完全一致。
- 在临时版本降级为 `0.9.0` 的条件下运行 `.\bin\checkver.ps1 -Update pideck`，自动化机制成功自动探测并写回最新版 `0.9.1` 与正确哈希。

## Consequences

- Windows 用户可以通过 `scoop install jinmo/pideck` 安装 PiDeck 正式版。
- Manifest 稳定跟随 GitHub `/releases/latest`。
- 用户数据保存在 `%APPDATA%\PiDeck`，`scoop update` 可平滑升级且保留完整会话与配置。
