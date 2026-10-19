# Agent Note: 将 AyuGram-Jinmo 加入个人 Scoop Bucket

Status: implemented

## Problem

需要把 [jinmo100/AyuGramDesktop](https://github.com/jinmo100/AyuGramDesktop) 的 Windows 测试版纳入本仓库 `jinmo100/scoop-jinmo`。该 fork 是 `AyuGram/AyuGramDesktop` 的定制分支（领先上游 ChannelTopPost 等提交），由维护者在本机 Windows 环境手工构建，发布为 GitHub Pre-release，内置更新器已在编译期关闭。

评估与落地的一手来源：

- fork 仓库与同步流程：[jinmo100/AyuGramDesktop](https://github.com/jinmo100/AyuGramDesktop)，同步工作流 `dev` 分支 `sync-upstream.yml`
- 发布设计：[docs/fork-release.md](https://github.com/jinmo100/AyuGramDesktop/blob/dev/docs/fork-release.md)、打包脚本 `tools/fork_release.py`
- 首个测试版：[v7.2.9-jinmo.1](https://github.com/jinmo100/AyuGramDesktop/releases/tag/v7.2.9-jinmo.1)
- 便携模式判定源码：`Telegram/SourceFiles/core/launcher.cpp` 的 `CheckPortableVersionFolder`
- Scoop 侧行为：`lib/install.ps1` 的 `persist_data`、`lib/versions.ps1` 的 `SplitVersion` / `Compare-Version`

## Decision

`bucket/ayugram-jinmo.json` 以 Pre-release 通道跟踪该 fork，只声明 Windows x64，使用官方测试版 ZIP 直接解包，并通过 `persist` 把 `TelegramForcePortable` 固定到 Scoop 的 persist 目录。

### 上游发布事实与资产选择

- 首个也是当前唯一发布：`v7.2.9-jinmo.1`，`prerelease: true`，`draft: false`，`published_at: 2026-10-19T23:44:02Z`。
- 资产 `AyuGram-Jinmo-v7.2.9-jinmo.1.zip`（135,934,303 字节，sha256 `c4ccd21e12663637decbf60d0b88066fde1cf688811bd3f6082dfbf8efda0a2e`），解包后顶层为 `AyuGram-Jinmo-v7.2.9-jinmo.1/`，内含 `AyuGram.exe`（Debug，520,676,352 字节）、`LICENSE`、`README.txt`、空目录 `TelegramForcePortable/`。
- 同一发布还有 `SHA256SUMS` 与 `build-info.json`（含 `source_sha`、Debug 配置、验证门禁与限制声明），用于追溯，不进入 Manifest。
- 包内不含 `Updater.exe`，因为构建时打开了 `DESKTOP_APP_DISABLE_AUTOUPDATE=ON`；这与 Scoop 独占版本管理的前提一致。
- 许可证为 GPL-3.0，源码提交在发布说明中可追溯，个人桶再分发可接受。

### 便携数据边界

`CheckPortableVersionFolder` 的判定是：可执行文件同目录下存在名为 `TelegramForcePortable` 的**目录**时，`cForceWorkingDir(portable)`，之后 `tdata` 落在该目录内。因此 Manifest 声明：

```json
"persist": "TelegramForcePortable"
```

这样账号数据实际保存于 `persist\ayugram-jinmo\TelegramForcePortable\tdata`，`scoop update` 只替换版本目录，不影响账号。

不额外写 `pre_install` 创建 marker：`persist_data` 在源目录缺失时会自行在 persist 目标建目录并创建 junction（`lib/install.ps1`），解压后 junction 本身就是 marker；实测 7-Zip 26.02 解包也保留了这个空目录。`pre_install` 只有在需要"persist 一个文件而非目录"时才必要。

不声明 `bin`：`AyuGram.exe` 是纯 GUI 程序，没有可用命令行接口，创建 shim 只会多出一个无意义的控制台入口。快捷方式命名为 `AyuGram (Jinmo)`，避免与其他桶里的 `ayugram` 混淆。

### 版本与 checkver

版本完整保留上游 tag 的预发布后缀：`version` 为 `7.2.9-jinmo.1`，`autoupdate` 的 URL 与 `extract_dir` 都使用完整 `$version`（tag 自带 `v` 前缀，所以是 `AyuGram-Jinmo-v$version`），不得改用 `$matchHead`。

`checkver` 必须走 Releases API 而不是 `github`：`/releases/latest` 排除 Pre-release。Manifest 采用按 `published_at` 倒序挑最新非草稿 Pre-release 的脚本，正则 `^v(\d+(?:\.\d+)*-[0-9A-Za-z][0-9A-Za-z.-]*)$` 保留完整后缀，与 `bucket/any-listen-desktop.json` 同一形态。

序号增长在 Scoop 侧可比较：`SplitVersion` 会把纯数字段转成 `[Long]`，`jinmo.10 > jinmo.9` 成立；`jinmo` 不在 Scoop 的 `alpha|beta|rc|pre` 关键字表里，所以"无后缀版本大于带后缀版本"，而本通道只发布带后缀版本，不产生歧义。

## Alternatives considered

**打包上游正式版 `AyuGram.zip`（另开 `ayugram`）。** 最强理由：上游 v7.2.9 的 `AyuGram.zip` 就是 Windows x64 便携包（含 `modules/x64/d3d/d3dcompiler_47.dll` 与 `Updater.exe`），体积 76MB、Release 稳定性更高，`kkzzhizhou/scoop-apps` 已有可参考清单。放弃原因：本次需求是维护者自己的定制功能；而且该上游包没有 `TelegramForcePortable` 目录，现有第三方清单的 `persist: "tdata"` 与真实数据路径不符（数据会落到 `%APPDATA%`），照抄会得到一个 persist 失效、且允许应用在 Scoop 版本目录内自更新的清单。若日后确实要加上游正式版，按"保留 `Updater.exe`、README 说明内置更新会脱离 Scoop 托管"处理，不在本次范围内。

**使用 `pre_install` 显式创建 `TelegramForcePortable` 目录。** 最强理由：语义更直白，也不依赖解压器保留空目录。放弃原因：`persist_data` 已经保证目录存在，多一段清单脚本只增加失败面；真正的健壮性改进属于上游打包——`tools/fork_release.py` 在首个发布后改为写入 `TelegramForcePortable/.keep`，使压缩包本身不再依赖"解压器保留空目录"这一行为，而不必让每个消费方重复补偿。

**用 `checkver: "github"` 简化清单。** 最强理由：一行搞定，无需维护脚本。放弃原因：`/releases/latest` 会跳过 Pre-release，本通道永远检测不到更新。

**等待首个 Release 再评估与落地分开处理。** 最强理由：发布前无法取得 URL 与 hash，写成清单也只是空壳。放弃原因（流程上的实际做法）：评估阶段先确认阻塞点与设计，Release 发布后再一次性写入并用 Scoop 工具验证，避免空壳清单进仓库。

## Verification

- `bucket/ayugram-jinmo.json` 已创建，`python3 -m json.tool` 语法校验通过。
- `.\bin\checkver.ps1 ayugram-jinmo` 在 Windows PowerShell 5.1 + `E:\Scoop` 下识别出 `7.2.9-jinmo.1`。
- `.\bin\checkurls.ps1 ayugram-jinmo` 通过（Ok 1 / Failed 0）。
- `.\bin\checkhashes.ps1 ayugram-jinmo` 完整下载 129.6MB 并校验通过（`ayugram-jinmo: OK`），与 Release API 的 `sha256` digest、`SHA256SUMS`、本地 `sha256sum` 三者一致。
- 在临时副本把版本降为 `7.2.9-jinmo.0` 后运行 `checkver.ps1 -Update`，成功写回 `version`、`url`、`hash`、`extract_dir`，输出与生产清单逐字节一致（hash 由 Github Mode 取得），证明 `autoupdate` 模板可展开。
- 用 7-Zip 26.02 解包真实资产，确认外层目录名与 `extract_dir` 一致且 `TelegramForcePortable/` 空目录被保留。
- fork 侧同批把 `tools/fork_release.py` 改为写入 `TelegramForcePortable/.keep`，并更新 `tools/test_fork_release.py` 的 zip 白名单断言；`python3 -m unittest tools.test_fork_release` 20 项全部通过，`npm run verify-notes` 三线通过。该改动只影响后续发布的 zip 内容，已发布资产的 hash 不变。
- 未在本机执行 `scoop install`（会引入真实的系统安装状态），也未运行 `bin/test.ps1`（本机 Scoop 未安装 `Pester`/`BuildHelpers`，CI 覆盖这一步）。干净机器上的启动与第三方 DLL 依赖仍由 fork 的 `build-info.json` 标注为未验证。

## Consequences

- 用户可以 `scoop install jinmo/ayugram-jinmo` 安装维护者的定制版，`scoop update ayugram-jinmo` 升级，账号数据留在 persist 目录并跨版本保留。
- 该包是 Debug 测试版（解压后约 496MB），下载量明显大于上游正式版；内置更新已禁用，版本升级只能经 Scoop 完成。
- 发布完全由维护者手工触发，清单只能被动跟随；Excavator 每四小时轮询一次，Pre-release 出现后可能在数小时内被写入。
- 若上游 tag 规则或 ZIP 内部目录名变化（`v` 前缀、`AyuGram-Jinmo-` 前缀），`extract_dir` 与 `autoupdate` 会一起失效，需要同批修正；这些命名由 `tools/fork_release.py` 固定，属于跨仓库契约。
- 通道只有 x64；未来若加 arm64 或正式版通道，应另开清单文件而不是在同名清单里混排。
