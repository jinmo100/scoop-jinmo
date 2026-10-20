# Agent Note: 将 DSH Tauri 桌面端加入个人 Scoop Bucket

Status: implemented

## Problem

需要把 [dsh-tauri/deepseek-harness-desktop](https://github.com/dsh-tauri/deepseek-harness-desktop) 纳入 `jinmo100/scoop-jinmo`，并把它作为本机后续更新的首选渠道。这个仓库是社区维护的 DeepSeek Harness（DSH）Tauri 桌面端，Windows 侧只提供安装器，没有绿色包；同时它的名字与大量第三方包装仓库、以及 DeepSeek 官方桌面端重名，Manifest 不能沿用上游仓库名。

本次评估与落地以 2026-10-20 的一手资料为准：

- 上游仓库与 Release：[dsh-tauri/deepseek-harness-desktop](https://github.com/dsh-tauri/deepseek-harness-desktop)，最新正式版 [v0.24.5](https://github.com/dsh-tauri/deepseek-harness-desktop/releases/tag/v0.24.5)（2026-10-18T12:07:23Z）
- 安装包配置：[src-tauri/tauri.conf.json](https://github.com/dsh-tauri/deepseek-harness-desktop/blob/main/src-tauri/tauri.conf.json)（`productName: DSH Tauri`、`identifier: dsh-tauri`）
- 自带更新器：[src-tauri/src/service/update/mod.rs](https://github.com/dsh-tauri/deepseek-harness-desktop/blob/main/src-tauri/src/service/update/mod.rs)、`install.rs`、`pending.rs`
- 自启动注册：[src-tauri/src/desktop/autostart.rs](https://github.com/dsh-tauri/deepseek-harness-desktop/blob/main/src-tauri/src/desktop/autostart.rs)
- CLI shim 与 PATH：[src-tauri/src/service/cli/path/mod.rs](https://github.com/dsh-tauri/deepseek-harness-desktop/blob/main/src-tauri/src/service/cli/path/mod.rs)
- 运行时/数据目录：[src-tauri/resources/README.md](https://github.com/dsh-tauri/deepseek-harness-desktop/blob/main/src-tauri/resources/README.md)
- Scoop 解压分派：[Scoop/lib/decompress.ps1](https://github.com/ScoopInstaller/Scoop/blob/master/lib/decompress.ps1)
- 官方桌面端：[deepseek-ai/deepseek-harness `apps/desktop`](https://github.com/deepseek-ai/deepseek-harness/tree/master/apps/desktop)，下载入口 <https://www.deepseek.com/harness>

## Decision

新增 `bucket/dsh-tauri.json`，跟踪上游**正式版**通道，只声明 Windows x64，使用 `_x64_en-US.msi` 作为安装源，靠 Scoop 的 MSI 管理员安装解包，并用 `extract_dir` 去掉安装器目录层级。包名取 `dsh-tauri`，快捷方式显示名取 `DSH Tauri`。

### 命名：为什么不用 `deepseek-harness-desktop`

GitHub 上以 `deepseek-harness-desktop` 命名的仓库有 582 个（`dsh-tauri` 3.3k star 只是其中最大的一个），官方桌面端也在 `deepseek-ai/deepseek-harness` 内提供。若以仓库名作为 Scoop 包名，安装路径、`scoop update` 命令和开始菜单项都会与官方桌面端及其他社区包装混淆。

`dsh-tauri` 是上游自己使用的产品名（`tauri.conf.json` 的 `productName: "DSH Tauri"`）与 bundle identifier，既唯一又不自造词。README 与 Manifest `notes` 明确标注“非官方社区构建”，并给出官方下载入口。

### 资产与解包路径

- v0.24.5 的 Windows 资产：`_x64-setup.exe`（NSIS，9,470,146 B）、`_x64_en-US.msi` / `_x64_zh-CN.msi`（13,967,612 B）、`Deepseek.Harness.Desktop_Bundle_0.24.5.exe`（126 MB 离线包）。
- 选用的 MSI sha256 为 `ff48a5627087edd83506af08ff46ed02f92f026849b8cc16edadca21bc3a1f58`，与 Release 页 `expanded_assets` 公布的摘要一致。
- 实测 `msiexec /a <msi> /qn TARGETDIR=<临时目录>` 成功，产物为 `<临时目录>\PFiles\DSH Tauri\{deepseek-harness-desktop.exe, resources\, icons\}`（1299 个文件），非管理员可执行。
- Scoop `Expand-MsiArchive` 在设置 `extract_dir` 时会解到 `<app>\_tmp\SourceDir` 再搬移 `SourceDir\<extract_dir>`，因此 Manifest 使用 `"extract_dir": "PFiles\\DSH Tauri"`。
- 资产命名在 v0.20.0 至 v0.24.5 的 16 个连续正式版中保持 `Deepseek.Harness.Desktop_<version>_x64_en-US.msi` 形式，`autoupdate` 可以稳定拼接。

### 为什么必须走 MSI

Scoop 的 `Invoke-Extraction` 只对 `.zip`、`.msi` 和带 `innosetup` 标记的 `.exe` 做解压；`.exe` 分支只认 Inno Setup。上游的 `_x64-setup.exe` 是 NSIS（7-Zip 可解，但 Scoop 不会调用），`Bundle_*.exe` 同样是 NSIS。若直接声明 `.exe`，Scoop 会把安装器本体放进应用目录，既不能启动也不是安装结果。

### 运行数据与升级安全

- 运行时（Node）、Harness 内核、插件、日志与 `.store.dat` 全部落在 `%APPDATA%\dsh-tauri`；会话与凭据使用 `$DSH_HOME`（默认 `~/.dsh`）。
- 因此不需要 `persist`：Scoop 升级替换的是版本目录，不会碰上述数据。
- CLI 集成写到 `%LOCALAPPDATA%\deepseek-harness\bin` 并改用户 PATH，与安装目录无关，也不需要 `bin` 声明（避免与官方 `dsh` 命令争名）。

### 已知边界

- **自带更新器与 Scoop 冲突**：`auto_update` 默认开启，更新器把官方安装器下到 `%APPDATA%\dsh-tauri\updates`，退出时可能自动拉起；由于 Scoop 安装没有 MSI 注册信息，运行后会额外装出一份 Program Files 副本（per-machine 还需提权）。Manifest 只能通过 `notes` 要求用户关闭“设置 → 自动更新”，更新统一走 `scoop update`。
- **首启仍需联网**：安装包不含运行时与内核，首次启动会下载；离线 Bundle 是 NSIS，无法 Scoop 化，故不提供。
- **自启动路径**：HKCU Run 记录的是版本目录中的 exe；应用每次启动会刷新该项，所以 `scoop update` 后需手动启动一次，或保持自启动关闭。
- **卸载残留**：`scoop uninstall` 不清理 `%APPDATA%\dsh-tauri` 与 `~/.dsh`，`notes` 已说明。
- **extract_dir 依赖管理员安装布局**：若 Scoop 配置 `USE_LESSMSI`，`lessmsi` 的目录布局可能不同；当前默认 `msiexec /a` 已验证。
- 未做首次启动的实机冒烟：启动会写 `%LOCALAPPDATA%\deepseek-harness\bin` 并改用户 PATH，属于系统级副作用，留待用户确认后验证。

## Alternatives considered

### 使用 `_x64-setup.exe`（NSIS）

最强理由是它只有 9.4 MB，明显小于 13.9 MB 的 MSI，且上游 README 以它作为主推下载。放弃原因是 Scoop 只对 `innosetup` 的 `.exe` 解压，NSIS 会被原样放进应用目录，无法形成可运行安装；在 Manifest 里伪造 `innosetup` 会直接失败。

### 使用 `Bundle_*.exe` 离线包

最强理由是免去首次启动下载运行时与内核，最接近“装完即用”。放弃原因是它同样是 NSIS 安装器，Scoop 无法解包，而且体积 126 MB。

### 沿用上游仓库名 `deepseek-harness-desktop`

最强理由是名称与用户看到的下载文件名一致，便于对照。放弃原因是同名仓库有 582 个、官方桌面端也存在，包名会在安装目录、更新命令和开始菜单上与官方及其他社区构建混淆。

### 同时提供 nightly 通道（第二个 Manifest）

最强理由是上游 nightly 更新频繁，适合追新。放弃原因是 nightly 复用同一个 `nightly` tag 反复覆盖发布，没有稳定的版本号或资产版本串，`autoupdate` 无法可靠拼接；且本项目主要用途是作为稳定更新渠道。

### 等待上游提供 portable zip

最强理由是 zip 方案能绕开 MSI/NSIS 差异，`autoupdate` 更简单，也能做 `persist`。放弃原因是这依赖上游排期；当前 MSI 路径已经实测可用，不构成阻塞，可作为后续改进建议。
