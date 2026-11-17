# Agent Note: 将 DEEIX-AI/Winc 加入个人 Scoop Bucket

Status: implemented

## Problem

需要把 [DEEIX-AI/Winc](https://github.com/DEEIX-AI/Winc) 加入 `jinmo100/scoop-jinmo`。Winc 是用 Rust 写的 Windows 文本编辑器，自带渲染引擎（官网 https://winc.si），上游同时发布 NSIS 安装器、MSI 与便携 ZIP，全部是 Windows x64 构建。

加入 bucket 的关键问题不是下载，而是三件事：便携 ZIP 的内置更新会不会与 Scoop 抢版本目录；`winc.exe` 没有 Authenticode 签名，要不要改走安装器；数据目录放哪才能让 `scoop update` 保留设置。

一手来源（核查日 2026-11-17，以当时最新 release 为样本）：

- 发布资产与校验文件：[DEEIX-AI/Winc releases](https://github.com/DEEIX-AI/Winc/releases)
- 更新实现：[`crates/winc-app/src/updates/installer.rs`](https://github.com/DEEIX-AI/Winc/blob/dev/crates/winc-app/src/updates/installer.rs)
- 启动器：[`bin/winc.cmd`](https://github.com/DEEIX-AI/Winc/blob/dev/bin/winc.cmd)
- Scoop 侧范本：[hoilc/scoop-lemon 的 `bucket/winc.json`](https://github.com/hoilc/scoop-lemon/blob/master/bucket/winc.json)
- Schema：[Scoop `schema.json`](https://github.com/ScoopInstaller/Scoop/blob/master/schema.json)

## Decision

新增 [`bucket/winc.json`](../../../bucket/winc.json)，并在 [`README.md`](../../../README.md#install-winc) 加一节安装说明。契约：

- 包名 `winc`，只声明 `64bit`；上游没有 arm64 构建。
- 资产用 portable ZIP `Winc-$version-windows-x64-portable.zip`，直接解到应用目录，不需要 `extract_dir`。
- `bin: "winc.exe"` 与 `shortcuts: [["winc.exe", "Winc"]]`；`persist: "data"`。
- `suggest: extras/vcredist2022`，因为导入表里有 `VCRUNTIME140.dll`。
- `checkver` 用 `{"github": "..."}` 对象形式；`autoupdate.hash.url = "$baseurl/SHA256SUMS"`。

### 便携版自己不会更新

`installer.rs` 的 `locate()` 只认与 exe 同目录、内容为 `nsis` 或 `msi` 的 `winc-installation` 标记文件；便携 ZIP 里没有这个文件，`start()` 直接返回 false，源码注释也写明便携版不检查更新。所以不需要像 dsh-tauri 那样在 `pre_install` 里删更新配置。

### hash 从 SHA256SUMS 取

上游 `SHA256SUMS` 是 `hash  filename` 两列格式，Scoop 的 `find_hash_in_textfile` 原生支持这种格式，因此 autoupdate 只需要 `hash.url`；上游若改成单列格式，再补 `hash.regex`。

### checkver 必须写对象形式

`homepage` 是 https://winc.si 而不是 GitHub；`"checkver": "github"` 会把 homepage 当仓库地址去查 release，必然失败。对象形式才是「检查这个 GitHub 仓库」。

### 无签名不影响装，但要提前说明

便携 ZIP 里的 `winc.exe` 是 PE GUI 子系统、证书表为空；同版本 `setup.exe` 有 Authenticode 签名。Scoop 只下载 ZIP，所以签名与否只影响首次启动的 SmartScreen 提示，不影响安装完整性（hash 已校验）。README 与清单 `notes` 都写明这一点。

### 数据目录

设置、最近目录、未保存内容备份都在 exe 旁的 `data\`。Scoop 的 `persist: "data"` 会把该目录搬到 `persist\winc\data`，升级不丢；卸载会留下 persist 目录。

## Alternatives considered

### 用 NSIS 安装器 + `installer` 脚本

最强理由是上游签了名，SmartScreen 与杀软信任链完整，用户看到的就是官方安装体验。

放弃原因：安装器会写注册表、创建卸载项，并让内置更新机制获得完整环境，可能制造第二份不受 Scoop 管理的副本；而 portable ZIP 的更新器本来就是关的。

### `bin` 指向 `bin\winc.cmd` 而不是 `winc.exe`

最强理由是厂商自己的启动器用 `--launcher` 把控制台与编辑器进程分离，`winc .` 从终端启动时语义更接近 `code .`。

放弃原因：Scoop 给 GUI 子系统 exe 生成的是 GUI shim，本身不会让 PowerShell 等待；`winc.cmd` 只是一个 `start` 包装。lemon 的清单也用 `winc.exe`。若实测发现从 PowerShell 启动后终端被占用，再改成 shim `bin\winc.cmd` 并补 `--launcher` 测试。

### 不写 `persist`，让 data 留在版本目录

最强理由是少一层目录映射，升级时 Scoop 直接换整个版本目录，行为最直白。

放弃原因：`data\` 里有未保存内容备份与设置，换版本即丢；persist 是这类编辑器清单的标准做法。

### 等上游提供带签名的 portable

最强理由是彻底消掉 SmartScreen 提示。

放弃原因：上游当前只签安装器，portable 不签是发布流水线的选择，bucket 不能等；hash 校验已保证下载完整性。

## Verification

- 从 GitHub 下载 portable ZIP：SHA-256 `49c00899b599fd5db5859c08b5ccc1fd9259de2b0113141281fcc4f4724302f3`，与上游 `SHA256SUMS` 一致。
- 解压核对根布局：`winc.exe`、`winc-pty.exe`、`conpty.dll`、`OpenConsole.exe`、`bin/winc.cmd`、`bin/winc`、`winc-server-Linux-*`、`data/README.txt`、`LICENSE`、`NOTICE`；无 `winc-installation`。
- `winc.exe` 证书表 size=0（无签名）、subsystem=2；导入表含 `VCRUNTIME140.dll`。
- 清单通过 Scoop master `schema.json` 校验（jsonschema，0 错误）。
- 本机 WSL 无 `pwsh`、`E:\Scoop` 受沙箱限制，未跑真实 `checkver`/`checkhashes`；推送后由 Windows 侧 Excavator 首次执行时验证。
