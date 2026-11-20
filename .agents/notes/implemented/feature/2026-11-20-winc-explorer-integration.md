# Agent Note: Winc 的 Explorer 右键与文件关联脚本

Status: implemented

## Problem

`bucket/winc.json` 只能把 Winc 装进 Scoop，装完以后用户在资源管理器里仍然只能双击默认程序打开文件，右键菜单里没有 Winc。想要的是两件事：

1. 在文件夹/文件上右键出现「Open with Winc」；
2. 常用代码与文本格式的「打开方式」里有 Winc，可选地设成默认。

另外 DSH 侧边栏的「在应用中打开」只接受 URL scheme，而 Winc 便携版不注册任何协议，所以需要把 `winc://` 处理器也做成可复现的脚本，而不是手工写注册表。

## Decision

新增 `bin/winc/` 下的三个脚本，全部只写 `HKCU`（不需要管理员、只影响当前用户），每个都带 `-Uninstall` 与 `-DryRun`：

- `context-menu.ps1`：给 `Directory\shell`、`Directory\Background\shell`、`*\shell` 写 `Winc` 动词，命令分别是 `"%1"` 与 `"%V"`。
- `file-associations.ps1`：注册 `Winc.Text` ProgID 与 `Applications\winc.exe`，为内置的代码/文本扩展名写 `OpenWithProgids`；`-SetDefault` 才改默认值，并把旧默认记录到 `%LOCALAPPDATA%\winc-setup\defaults.json` 供卸载还原。
- `url-handler.ps1`：写 `%LOCALAPPDATA%\winc-setup\winc-open.ps1` 并注册 `HKCU\Software\Classes\winc`，把 `winc://open/?path=...` 转成 Winc 可执行文件的参数；WSL 路径映射到 `\\wsl.localhost\<distro>\...`。

三个脚本都用 `.NET` 的 `Microsoft.Win32.Registry` 直接写注册表，避免 PowerShell 注册表 provider 对 `*`、`Directory\Background` 这类路径的通配符与转义差异。

## Alternatives considered

### 只写一个 setup.ps1，用开关区分功能

最强理由是用户只需要跑一条命令，README 也短。

放弃原因：三个功能互相独立，分开关闭/卸载更清楚；分开后单个脚本可以单独复制到别的 bucket 或机器上，不依赖共享模块。

### 用 MSIX / IExplorerCommand 注册现代右键菜单

最强理由是 Windows 11 的一级右键菜单更显眼，不用进「显示更多选项」。

放弃原因：需要打包应用标识与 `AppxManifest`，Scoop 装的是便携目录，没有包身份；维护成本远高于一个注册表动词。经典的 `*\shell` 动词在 Win10/11 都能用，只是 Win11 默认收在二级菜单里，README 已说明。

### 直接改文件默认关联

最强理由是双击即用 Winc，体验最完整。

放弃原因：Windows 10/11 的 `UserChoice` 带哈希保护，脚本改 `HKCU\Software\Classes\.ext` 默认值会被系统忽略或提示重置；所以默认是 opt-in（`-SetDefault`），并把选择权留给用户在「打开方式 → 始终使用」里确认。

## Verification

- 三个脚本都用 Windows PowerShell 5.1 的 `[ScriptBlock]::Create` 做了语法解析（无语法错误）。
- 每个脚本都以 `-DryRun` 实跑，确认只打印计划、不写注册表。
- `winc://` 处理器在真机上验证过：`rundll32 url.dll,FileProtocolHandler "winc://open/?path=/home/jinmo/project/scoop-jinmo"` 让 Winc 窗口标题变成 `scoop-jinmo [WSL: Ubuntu]`，带空格的路径也正常。
- 未在仓库 CI 里跑：这些脚本只面向本机配置，CI 的 Windows runner 没有安装 Winc。
