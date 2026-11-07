# Agent Note: 将 hadc188/reader 以 legado-reader 加入个人 Scoop Bucket

Status: implemented

## Problem

需要判断 [`hadc188/reader`](https://github.com/hadc188/reader) 是否适合加入本仓库的个人 Scoop bucket，并同时定下包名。它是一款 Windows 桌面阅读器（Rust + Tauri v2 + Vue 3），面向「阅读 3.0」（Legado）生态：可导入 Legado 的书源、RSS 与备份，本身不含书源、不提供服务器端。

两个问题必须一起回答，因为 Scoop 的包名就是安装身份：应用目录、`persist` 目录、`scoop list` 记录都跟着它走，发布后再改名等于换一个应用。

本次核查的一手来源：

- 上游仓库与 README：[hadc188/reader](https://github.com/hadc188/reader)
- 最新 Release API：[releases/latest](https://api.github.com/repos/hadc188/reader/releases/latest)
- 打包配置：[desktop/src-tauri/tauri.conf.json](https://github.com/hadc188/reader/blob/main/desktop/src-tauri/tauri.conf.json)
- Windows 便携包组装脚本：[scripts/collect-desktop-artifacts.mjs](https://github.com/hadc188/reader/blob/main/scripts/collect-desktop-artifacts.mjs)
- 数据目录与便携判定：[desktop/src-tauri/src/portable.rs](https://github.com/hadc188/reader/blob/main/desktop/src-tauri/src/portable.rs)
- 应用内更新：[src/api/commands/update.rs](https://github.com/hadc188/reader/blob/main/src/api/commands/update.rs)、[src/service/update_service.rs](https://github.com/hadc188/reader/blob/main/src/service/update_service.rs)
- 前端更新入口：[frontend/src/stores/app.ts](https://github.com/hadc188/reader/blob/main/frontend/src/stores/app.ts)、[frontend/src/components/SettingsDrawer.vue](https://github.com/hadc188/reader/blob/main/frontend/src/components/SettingsDrawer.vue)
- Scoop 的名称解析与快捷方式实现：[Scoop/lib/manifest.ps1](https://github.com/ScoopInstaller/Scoop/blob/master/lib/manifest.ps1)、[Scoop/lib/shortcuts.ps1](https://github.com/ScoopInstaller/Scoop/blob/master/lib/shortcuts.ps1)

## Decision

已加入 [`bucket/legado-reader.json`](../../../bucket/legado-reader.json)，并在 [`README.md`](../../../README.md#install-legado-reader) 增加安装说明。Manifest 的契约是：

- **包名 `legado-reader`**：Manifest 文件名即应用名，也是 `persist` 目录名。
- **资产**用上游的 `Reader-v<ver>-windows-x64-portable.zip`，`architecture` 只声明 `64bit`。
- **版本**用 `checkver: "github"`；`autoupdate` 按 `v$version/Reader-v$version-windows-x64-portable.zip` 重建 URL。
- **持久化** `persist: "data"`：书库（`reader.db`）、书源、`webview` profile 都固定在 `persist\legado-reader\data`，跨 `scoop update` 保留。
- **入口** `shortcuts` 为 `["Reader.exe", "Reader (Legado)"]`；不声明 `bin`，避免 PATH 里出现第二个 `reader`。
- **提示** `suggest` 指向 `extras/webview2`；`notes` 写明非官方移植、命名原因、内置更新的风险与旧安装的数据迁移路径。

版本号与 hash 以 Manifest 为准；当前值来自 v1.6.4，hash 与 GitHub API digest、本地下载三方一致。

## 上游发布物与运行契约

核查时间 2026-11-07，最新版本 v1.6.4（`published_at` 2026-11-07T07:38:55Z，非 prerelease）。仓库 tag 形如 `v1.6.4`，所有近期 release 都是正式版，因此 `checkver: "github"` 可用（tag 去掉 `v` 即版本）。

Windows 发布物：

| 资产 | 大小 | 说明 |
| --- | --- | --- |
| `Reader-v1.6.4-windows-x64-portable.zip` | 17,306,859 B | Manifest 采用，GitHub API digest 为 `sha256:725403de…c8e1`，本地下载后 SHA-256 一致 |
| `Reader-v1.6.4-windows-x64-setup.exe` | 12,773,675 B | NSIS 安装器，winget 与 SpecterShell/Dumplings 走这条 |
| AppImage / deb / dmg / macOS zip | — | 非 Windows，与本 bucket 无关 |

便携包只含 3 个条目：`./`、`./Reader.exe`（46,422,528 B）、`./.reader-portable`（24 B，内容为 `Reader portable package`）。它由 CI 在 Windows bundler 产出 NSIS 之后用 `tar.exe -a -c -f … -C stage .` 手工组装，所以条目带 `./` 前缀；已实测该前缀不会让解压结果多出一层目录。包内没有安装器残留，解压即等于安装。

运行契约：

- **数据目录**：非 macOS 下，程序取 `exe_dir()/data`，用「在目录里建 `.write-test`」判断可写；不可写才回退 `%LOCALAPPDATA%\reader\data`。因此在 Scoop 里必须 `persist: "data"`——否则库文件落在版本目录，`scoop update` 换版本时会丢。
- **单实例标识**由数据目录路径的 FNV-1a 派生；persist 后路径跨版本稳定，单实例互斥与多副本隔离都不受影响。
- **WebView2**：Tauri 应用，运行依赖 WebView2 Runtime；WebView2 的 profile 被显式指向 `<data>/webview`，会一并进入 persist。
- **应用内更新**：设置里有「自动检查更新」开关，启动时若开启会检查 GitHub `releases/latest` 并弹窗；用户确认后，portable 模式会下载同一个 zip，用 PowerShell 脚本等待进程退出、备份并原位覆盖**目标目录里的** `Reader.exe` 与 `.reader-portable`，然后重启。它不会更新 Scoop 的安装记录，因此会制造「Scoop 记的是 1.6.4、磁盘上已是更新版本」的偏差；数据在 persist 里，不会丢。
- **架构**：只发布 x64，无 arm64，Manifest 只声明 `64bit`。
- **发布节奏**：v1.6.0（2026-10-24）到 v1.6.4（2026-11-07）共 5 个版本，属于高频但正常的桌面应用；Excavator 每 4 小时跑一次足够跟上。

## 命名分析

### Scoop 里「名字」意味着什么

Manifest 文件名就是 app 名（`lib/manifest.ps1` 的 `manifest_path` 直接找 `"$app.json"`），而这个身份是**跨 bucket 全局**的：

- `scoop install reader` 不带 bucket 时走 `Find-AppBucket`，命中多个 bucket 时只打一条黄色警告，然后按 bucket 顺序取第一个——不是报错，是**静默装错程序**。
- 应用目录、`persist` 目录都以包名命名；改名等于换一个应用，旧的 persist 不会自动跟过来。
- 开始菜单快捷方式的文件名直接用 shortcut 的显示名（`lib/shortcuts.ps1` 里是 `"$shortcutName.lnk"`），两个包都叫 `Reader` 会互相覆盖；卸载其中一个时 `rm_startmenu_shortcuts` 还会按名字把另一个的快捷方式删掉。
- `bin` 的 shim 名可以独立于包名，所以真正的 PATH 撞名风险来自 `Reader.exe` 这个可执行文件名，而不是包名。

结论：包名必须同时满足「现在唯一」「将来不容易被抢」「说得清是哪个程序」；快捷方式名还得单独再唯一一次。

### 现状：`reader` 是饱和命名空间

- 官方 `ScoopInstaller/Main`、`Extras`、`Versions` 都没有裸 `reader.json`；Extras 有 9 个 `*-reader` 清单（`yacreader`、`anx-reader`、`linux-reader`、`koodo-reader`、`raven-reader`、`foxit-reader`、`fluent-reader`、`thorium-reader`、`foxit-pdf-reader`），官方惯例是「品牌-reader」复合名。
- 社区 bucket 里裸 `reader.json` 已有两个收录：`lzwme/scoop-proxy-cn` 与 `anderlli0053/DEV-tools`，都指向 `binbyu/Reader`——一个 win32 的 txt/epub 阅读器，可执行文件同样叫 `Reader.exe`，快捷方式同样叫 `Reader`。与本项目形成清单名、exe 名、快捷方式名三重撞名。
- `xvvz/snow` 的 `bucket/reader-desktop.json` 指向 `hectorqin/reader` 3.2.14（「阅读 3 服务器版」，MSI）——正是本项目的直系前身，所以 `reader-desktop` 也已不可用。
- GitHub 代码搜索里 `filename:reader.json path:bucket` 有 242 条模糊命中，说明这个名字在社区 bucket 里被大量复用，不是个别现象。
- winget 已经用 `hadc188.Reader` 收录，说明「厂商限定名」是另一条已被采用的路，但它不符合 Scoop 的短名习惯。

候选名核查（GitHub code search 计数）：`legado`、`legado-desktop`、`reader-legado`、`hadc-reader` 均为 0，`reader-desktop` 为 1（见上）。

### 结果：`legado-reader` + `Reader (Legado)`

理由按重要性排序：

1. **唯一且可预期**：`legado-reader` 在官方与社区 bucket 中都没有占用；命名空间里带 `legado` 的几乎为空，短期被抢的概率低。
2. **符合官方命名惯例**：Extras 里同类软件统一是「品牌-reader」，`legado-reader` 与 `koodo-reader`、`fluent-reader` 同构，用户看到名字就能判断类别。
3. **描述的是生态兼容性，而不是冒充官方**：这个应用的价值就是 Legado 书源/备份互通；README 与 `notes` 明确写「社区移植、非官方」，避免让 `legado-reader` 读起来像 Legado 官方桌面端。
4. **比仓库名更适合长期存在**：仓库叫 `reader`，但产品名、维护者、形态都可能变；`legado-reader` 绑定的是「Legado 阅读器」这个稳定的使用场景，上游改产品名时不必跟着改包名。
5. **搜索与输入都友好**：`scoop search legado` / `legado-reader` 都能命中；`scoop install jinmo/legado-reader` 可读、可记。

配套的两处命名处理：

- **快捷方式显示名用 `Reader (Legado)`**，不用 `Reader`。原因是快捷方式文件按显示名落盘，与 `binbyu/Reader` 的 `Reader.lnk` 会互相覆盖、并可能被对方的卸载流程删掉；加后缀后既唯一，又保留了应用自己的窗口标题。
- **不声明 `bin`**，避免 PATH 里出现第二个 `reader`。

### 改名的代价

包名一旦发布就被 `persist` 目录、`scoop list` 记录、用户脚本和 README 引用。之后再改等于新应用：需要卸载重装，手动把 `persist\旧名\data` 搬到 `persist\新名\data`，否则用户会以为「更新后书库没了」。这是要在第一次发布前就把名字定下来的原因。

## Alternatives considered

### 直接用 `reader`

最强理由是它就是上游产品名，`scoop install reader` 最直觉，也最贴近「一个阅读器」的语义。

放弃原因是撞名不是理论风险而是既成事实：两个社区 bucket 已经用 `reader` 收录了另一个 `Reader.exe`，装错时 Scoop 只给黄色警告；快捷方式还会互相覆盖/误删。把裸名留在这里，等于让每个用户都必须记得写 `jinmo/reader`。

### 用 `reader-desktop`

最强理由是它准确描述「桌面版」，并且延续了 `hectorqin/reader` 那条线的叫法，老用户容易联想。

放弃原因是这个名字已经被 `xvvz/snow` 用在直系前身（阅读 3 服务器版）上。同一个名字指向两个不同代的程序，比被无关项目占用更糟——用户无法从名字判断自己装的是 Web 服务版还是桌面版。

### 用 `legado-desktop`

最强理由是它强调「Legado 的桌面端」，且完全避开 `reader` 这个词，撞名概率同样接近零。

不作为首选的原因：Scoop 官方同类命名都以 `-reader` 结尾，`legado-desktop` 丢掉了「阅读器」这个类别词，`scoop search reader` 只能靠快捷方式名兜底；如果更看重「别和 Android 版混淆」，它可以作为备选。

### 用 `hadc188-reader` / `hadc-reader`

最强理由是来源绝对无歧义，和 winget 的 `hadc188.Reader` 思路一致，也不涉及借用 Legado 品牌。

放弃原因是把维护者 ID 放进了用户每天要敲的名字里，可读性和可记忆性都差；`hadc` 这个缩写对用户没有意义，而 `legado` 至少说明了它能用 Legado 的书源。

### 用 NSIS `setup.exe` 打包（`innosetup` 解包或静默安装）

最强理由是这是上游 Windows 的主发布物，winget 和 SpecterShell/Dumplings 都选它，安装体验最接近厂商预期。

放弃原因是 NSIS 会写 `%LOCALAPPDATA%\Programs`、注册卸载项并创建自己的快捷方式，落在 Scoop 的 appdir/version/persist 生命周期之外；而便携 zip 只有 3 个文件、解压即用，hash 与 digest 也都已核实。

### 不加入，继续用 winget

最强理由是 winget 已经有 `hadc188.Reader`，官方源、自动更新，用户不必再加一个 bucket。

不采纳的原因是本 bucket 的定位就是「官方 bucket 缺失或需要可移植安装」：winget 装的是 NSIS 版本，数据落在安装目录或 `%LOCALAPPDATA%`，既不便携也不归 Scoop 管；Scoop 版能提供 persist、免管理员、`scoop update` 统一升级。代价是维护一个高频发布的上游，但 Excavator 已覆盖这类场景。

## Testing

在 WSL 侧与 Windows PowerShell 5.1（本机 Scoop 根为 `E:\Scoop`）执行：

- `python3 -m json.tool bucket/legado-reader.json` 通过。
- `bin/checkver.ps1 legado-reader` 输出 `legado-reader: 1.6.4`，即能从 GitHub 取到最新正式版。
- `bin/checkurls.ps1 legado-reader` 输出 `[1][1][0]`：1 个 URL、1 个可达、0 个失败。
- `bin/checkhashes.ps1 legado-reader` 输出 `OK`：重新下载 16.5 MB 并比对 hash。
- 用 PowerShell 5.1 的 `Expand-Archive`（Scoop 未安装 7zip helper 时走的解压路径）把同一个 zip 解到临时目录：根目录直接得到 `Reader.exe`（46,422,528 B）与 `.reader-portable`，`./` 前缀没有产生额外层级；测试后删除临时目录。
- 未验证：真实 `scoop install`（会写入本机的 Scoop 根）、首次启动与 `data` 实际创建、persist 跨版本保留、内置更新按钮的实际行为、GitHub Actions 的 Windows CI（尚未推送）。这些留给首次安装或推送后的 CI。

## Consequences

收益：

- 官方 Scoop bucket 没有这个应用；本 bucket 提供了可移植、免管理员、能用 `scoop update` 统一升级的安装方式，数据在 persist 里跨版本保留。
- 命名符合官方 `*-reader` 惯例，且不会与已有 `reader`、`reader-desktop` 混淆；快捷方式名不会覆盖别人的 `Reader.lnk`。

代价与风险：

- **内置更新绕过 Scoop**：用户点了应用内更新后，版本目录里的 exe 会被原位替换，Scoop 记录的版本变旧；下次 `scoop update` 会覆盖回去。数据在 persist 中，损失有限，但已在 README 与 `notes` 里明确劝阻。
- **zip 布局依赖上游 CI 脚本**：`./` 前缀、`.reader-portable`、单文件 exe 都来自 `collect-desktop-artifacts.mjs`；上游若改成带子目录或多文件，`shortcuts` 目标会失效。`checkver` 只验证版本，因此每次 Excavator 更新后仍要看 CI 的 URL/hash 结果。
- **高频发布**：两周 5 个版本，bucket 的提交历史会比较吵；如果之后出现破坏性变更，需要人工介入而不只是自动 bump。
- **仅 x64、依赖 WebView2**：老系统或未装 WebView2 的机器首次启动会失败；用 `suggest` 提示，不强行写 `depends`。
- **命名仍有轻微品牌借用**：`legado-reader` 会让人以为是 Legado 官方桌面端。缓解手段是 README、`notes`、`description` 三处都标明社区移植；若上游未来真的发布官方桌面端，应重新评估是否让位。
- **既有安装的数据迁移**：从 winget/安装器转过来的用户，书库在旧安装目录里，不会自动出现在 persist；只能文档提示手动复制，无法在 Manifest 里安全自动化。
