# Agent Note: 将 Fei2411/DS-Bot 加入个人 Scoop Bucket

Status: implemented

## Problem

需要把 [Fei2411/DS-Bot](https://github.com/Fei2411/DS-Bot) 加入 `jinmo100/scoop-jinmo`。它是以 DeepSeek Harness 为底座的桌面应用（Electron 44.7.0 / Chromium 152），把 DSH 会话组织成「主 bot + 私有 bot + bot 之间互发消息 + 群聊」的长期团队；同一个仓库还发布同源的 dsh 插件 `ds-bot`（v0.3.5 的 tgz 仅 1,389,560 字节）、Android APK 与 Docker 镜像。

难点不在下载，而在上游**只发布 NSIS 安装器**：`app/electron-builder.yml` 的 `win.target` 只有 `nsis x64`，没有 zip、没有 portable 目标；同时 Electron 包内带着 `resources/app-update.yml`，代码里 `autoDownload = true` 且 UI 无关闭开关。因此加入 bucket 要同时回答两件事：怎么从安装器拿到干净的 `win-unpacked` 布局，以及怎么让内置更新不在 Scoop 目录之外再装一份。

一手来源（核查日 2026-11-12，最新版 v0.3.5，发布于 2026-11-11）：

- 仓库与中文 README：[Fei2411/DS-Bot](https://github.com/Fei2411/DS-Bot)、[`README.zh.md`](https://github.com/Fei2411/DS-Bot/blob/main/README.zh.md)
- 打包配置：[`app/electron-builder.yml`](https://github.com/Fei2411/DS-Bot/blob/main/app/electron-builder.yml)
- 更新实现：[`app/src/updates.mjs`](https://github.com/Fei2411/DS-Bot/blob/main/app/src/updates.mjs)、[`app/src/main.mjs`](https://github.com/Fei2411/DS-Bot/blob/main/app/src/main.mjs)
- 数据默认值：[`app/src/first-run.mjs`](https://github.com/Fei2411/DS-Bot/blob/main/app/src/first-run.mjs)、[`app/src/logs.mjs`](https://github.com/Fei2411/DS-Bot/blob/main/app/src/logs.mjs)
- Scoop 侧范本：[ScoopInstaller/Extras 的 `bucket/notion.json`](https://github.com/ScoopInstaller/Extras/blob/master/bucket/notion.json)（同样用 `#/dl.7z` + `Expand-7zipArchive` 拆 NSIS 取 `app-64.7z`）
- Scoop 的 hash 正则变量替换：[Scoop `lib/autoupdate.ps1`](https://github.com/ScoopInstaller/Scoop/blob/master/lib/autoupdate.ps1)（第 77–78 行 `substitute $regex $substitutions $true`，证明 `$version` 在 `hash.regex` 里也会被替换）

## Decision

已新增 [`bucket/ds-bot.json`](../../../bucket/ds-bot.json)，并在 [`README.md`](../../../README.md#install-ds-bot) 增加安装说明。Manifest 的契约：

- **包名 `ds-bot`**，与 dsh 插件同名，但与 Scoop 里的应用身份无关；发布后再改名等于换一个应用，所以一次定死。
- **资产**用唯一的 Windows 发布物 `DS-Bot-$version-win-x64.exe`，URL 末尾挂 `#/dl.7z` 让 Scoop 走 7-Zip 解包而不是执行安装器；`architecture` 只声明 `64bit`（上游没有 arm64）。
- **两段解包**在 `pre_install` 里完成：先 `Expand-7zipArchive "$dir\`$PLUGINSDIR\\app-64.7z" "$dir"`，再 `Remove-Item "$dir\`$*" -Recurse -Force` 清掉 NSIS 骨架，最后删 `resources\\app-update.yml`。
- **入口** `shortcuts: [["DS Bot.exe", "DS Bot"]]`；不声明 `bin`（应用自带的 dsh CLI 属于运行期内部件，不该进 PATH），不声明 `persist` 与 `env_set`。
- **版本跟随** `checkver: "github"`；`autoupdate` 重建 URL，并从 `SHA256SUMS.txt` 用 `(?m)^([a-fA-F0-9]{64})\\s+DS-Bot-$version-win-x64\\.exe$` 取 hash。

### 安装包结构与两段解包

v0.3.5 的 `DS-Bot-0.3.5-win-x64.exe` 是 304,621,440 字节（291 MiB），SHA-256 `17a52634c0ffa559cfabe16cf6e3698dc9aea6c9b2f6231c0ceac2357a415da2`。`file` 判定为 `PE32 ... Nullsoft Installer self-extracting archive`；7-Zip 显示的 SubType 是 NSIS-3 Unicode，内含两样东西：`$PLUGINSDIR/app-64.7z`（304,005,516 字节，真正的应用负载）和 `$R0/Uninstall DS Bot.exe`。

因此路径是固定的两跳：Scoop 先用 7-Zip 拆 NSIS 外壳（`#/dl.7z`），`pre_install` 再把内层 `app-64.7z` 展开到 `$dir`。展开后是标准 `win-unpacked` 布局，共约 1.2 GB：

- `DS Bot.exe`（应用主程序）
- `resources/app.asar` 309,551,603 字节（296 MB）
- `resources/app.asar.unpacked` 69 MB、`resources/node_modules` 211 MB
- `resources/primary-runtime` 250 MB（随包内置的 DSH 运行时，含独立 Node）
- `resources/office-skills` 80 KB、`resources/elevate.exe`

DSH 运行时随包发布，首次启动不需要联网下载 Node/dsh，所以清单既不需要 `suggest` 也不需要额外依赖。

### 内置更新必须失效，且 Notion 式改法对这里无效

`resources/app-update.yml` 只有 80 字节：

```yaml
owner: Fei2411
repo: DS-Bot
provider: github
updaterCacheDirName: dsbot-updater
```

生效路径在代码里：`app/src/main.mjs:1123` 的 `startUpdates()` 先算 `feed = process.env.DS_BOT_UPDATE_URL || undefined`，再 `if (!app.isPackaged || (throwaway && feed === undefined)) return undefined`；打包态且非 throwaway 时，win32 分支直接把 electron-updater 的 `autoUpdater` 交给 `watchUpdates`，而 `app/src/updates.mjs:172` 起手就是 `updater.autoDownload = true`、`autoInstallOnAppQuit = true`，下载完成后调 `updater.quitAndInstall(true, true)`。UI 里没有开关。

Notion 清单的做法是把 `app-update.yml` 里以 `url` 开头的行注释掉。DS-Bot 的 yml 里**没有 `url` 键**（provider 是 `github`，地址由 owner/repo 派生），那招在这里什么都不做。所以本清单直接删除该文件：electron-updater 在检查时加载配置失败，只会把 About 页的更新状态置为失败并写日志（每 4 小时重试一次），不会安装任何东西，也不会碰 Scoop 目录。

### 数据边界

`app/src/first-run.mjs:60` 的 `defaultPlaces = () => ({ dataDir: join(homedir(), '.ds-bot'), workspace: join(homedir(), 'DS Bot') })`，日志在 `%APPDATA%\DS Bot\logs`（`app/src/logs.mjs`）。安装目录只用于「禁止把数据放进程序目录」这一条校验，运行期数据一律不落在 app 目录，因此不需要 `persist`，`scoop update` 天然保留模型配置、bot、会话与工作区。

## Alternatives considered

### 走 Scoop 的 `installer`，直接执行 NSIS

最强理由是这条最贴近上游意图：安装器会写注册表、创建开始菜单项、注册卸载程序，行为与用户双击安装完全一致，也不用猜内层压缩包的布局。

放弃原因：一是 NSIS 默认装到 `%LOCALAPPDATA%\Programs\DS Bot`，要让 Scoop 接管就得传 `/D=$dir`，把「谁来管版本」变成两套机制；二是安装器一旦运行，electron-updater 的 NSIS 更新就有完整环境，会在 Scoop 目录之外再装一份；三是解包路径反而规避了未签名安装器的 SmartScreen/UAC。官方 extras 的 Notion 走的是同一条解包路，说明这条路在 Scoop 里是被维护的。

### 保留 `app-update.yml`，只把 `provider` 改成 `generic` 指向一个死地址

最强理由是保留了 electron-updater 的正常代码路径，配置层面「关掉」更新比删文件更可逆，也方便日后接自建 feed。

放弃原因：效果与删除等价（都是检查失败），却多出一份需要维护的假配置；而且一旦有人把地址改回 GitHub，应用立刻恢复自动安装。删除是唯一不会「被误改回去」的写法。

### 等上游合并「不打包更新源」的 PR（#695）

最强理由是唯一干净的长期解：上游若让 `publish` 不生成 `app-update.yml`，或在 `startUpdates` 里加一个 `DS_BOT_NO_UPDATES` 之类的开关，清单就不用删文件，About 页也不会常年显示失败。

放弃原因：该 PR 已关闭且未合并，方向不合上游当前意图；bucket 不能等上游。清单先按删除落地，若上游日后加开关，再改一行 `pre_install` 即可，不需要改版本。

### 只提供 dsh 插件 `ds-bot`（1.4 MB），不打包桌面版

最强理由是体积差三个数量级，且插件用的是用户已有的 DSH、模型与会话，没有第二套运行时，也就没有自动更新冲突。

放弃原因：插件形态缺少桌面版独有的能力——独立浏览器与 Cookie 导入、退出后保留网页登录态、电脑操控，以及随包内置的 DSH 运行时；而「加到 Scoop bucket」的诉求本身就是装桌面版。两条路不冲突：想要轻量的人可以直接 `dsh plugin add ds-bot`，清单只负责桌面版。

### 让内置更新照常工作，Scoop 只负责首次安装

最强理由是用户能第一时间拿到上游版本，bucket 的 checkver 压力也小。

放弃原因：electron-updater 的 NSIS 更新会静默安装到默认路径，制造第二份不与 Scoop 关联的副本；Scoop 记录的版本与磁盘实际版本随后长期不一致，`scoop uninstall` 也清不干净。文献上 PiDeck 与 Legado Reader 都选了「Scoop 是唯一更新入口」，这里保持一致。

## Verification

- 安装包已完整下载并核对：本地 SHA-256、Release API 的 digest、`SHA256SUMS.txt` 三方一致，均为 `17a52634…da2`。
- 用 7-Zip 24.08 在 WSL 里实跑了清单依赖的两段解包，结果与清单假设的布局一致（`$PLUGINSDIR/app-64.7z` → `win-unpacked`，1.2 GB，`DS Bot.exe` 在顶层）。
- `bucket/ds-bot.json` 通过 `python3 -m json.tool` 与 Windows PowerShell 的 `ConvertFrom-Json` 解析。
- 用 v0.3.5 的 `SHA256SUMS.txt` 实测 `autoupdate.hash.regex`：替换 `$version` 后只命中带版本号的那一行，不会误取同哈希的旧式资产名 `DS-Bot-win-x64.exe`。
- `curl -I` 下载地址返回 200，`Content-Length` 与 304,621,440 一致。
- **未做**：本机 Windows 侧没有 Scoop（`C:\Users\Administrator\scoop` 不存在），因此没跑 `scoop install jinmo/ds-bot`，也没跑 `bin/test.ps1`（需要 Scoop 核心 + Pester 5.2.0 + BuildHelpers 2.0.1）；「解包后能正常启动并拉起内嵌 DSH Host」只有静态推断，没有真机确认。

## Consequences

- 用户可 `scoop install jinmo/ds-bot` 安装桌面版，`scoop update ds-bot` 是唯一更新入口；数据不随版本目录走。
- 代价是一次 291 MiB 下载、约 1.2 GB 磁盘占用；Scoop 还会保留安装包缓存，首次安装的实际磁盘开销更高。
- 代价是 About 页的更新检查恒为失败状态。这属于清单主动造成的副作用，已写进 `notes`，避免用户当成 bug 上报。
- 卸载不会清理 `%USERPROFILE%\.ds-bot`、`%USERPROFILE%\DS Bot` 与 `%APPDATA%\DS Bot`，同样写进 `notes`。
- 清单依赖上游继续用 `DS-Bot-$version-win-x64.exe` 这个名字（自 v0.3.2 起稳定）与 `SHA256SUMS.txt` 的 `hash + 两个空格 + 文件名` 格式；任一处变化都要同步改 `autoupdate`。
- 未验证的启动风险（内嵌运行时在 Scoop 目录下首次启动、Office 技能首次使用是否往 `resources/primary-runtime` 写依赖）只有在 Windows 上真装一次才能确认；若确实写入，`scoop update` 后需要重新触发，不影响可用性。
