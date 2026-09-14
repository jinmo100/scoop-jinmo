# Agent Note: 将 Scoop 维护流程固化为项目 Skill

Status: implemented

## Problem

个人 Scoop Bucket 的维护包含固定但容易被遗漏的边界：GitHub prerelease 不能用 `/releases/latest`，Manifest 必须保留完整 prerelease 版本号，hash 应与 Release asset digest 对齐，GitHub Actions 更新 Manifest 不等于本机更新已安装应用。若只依赖聊天上下文，后续新增软件时容易重复犯错或把宿主机变更、远程推送和本地验证混在一起。

## Decision

项目内使用 `.agents/skills/scoop-bucket-maintenance/SKILL.md` 作为维护入口。Skill 是 model-invoked 项目能力，description 覆盖新增/更新 Scoop Manifest、打包 GitHub stable/prerelease/Nightly Windows 软件、修复 checkver/autoupdate/hash 和验证 Actions 等场景。

Skill 使用正向铁律、五阶段清单和每阶段完成条件，固化以下顺序：用 `gh` 获取一手 Release 与 asset/digest 事实；先判断 stable、prerelease、preview 或 nightly 渠道；按渠道编写 `checkver`；使用完整 `$version` 编写 `autoupdate`；用临时 Manifest 验证更新；再分别验证本地 Scoop、CI、Excavator 和宿主机边界。它明确记录当前仓库的 GitHub API、`SCOOP_GH_TOKEN`、PowerShell 7 hash 检查和 `scoop update` 分层约束，但不复制 README 或 Scoop 通用文档。

## Alternatives considered

### 只把流程写进 README

优势是用户可直接阅读。放弃原因是 README 主要面向 Bucket 使用者，而 Skill 需要给后续 agent 提供触发条件、执行顺序和完成门，二者受众与信息层级不同。

### 修改项目 AGENT.md 让流程始终加载

优势是规则不容易被漏读。放弃原因是整个流程不是每次任务都相关，放入常驻上下文会增加无关负担；Skill 的 description 可以按维护场景触发。

### 添加自动化脚本替代 Skill

优势是命令更确定。未采用为唯一入口，因为不同上游的 Release 资产命名、稳定版/预发布筛选规则和安装方式仍需要 agent 判断；现有 `bin/` 工具负责重复检查，Skill 负责决策与顺序。

## Consequences

- 后续 agent 有一个项目内、可按场景触发的 Scoop 维护流程，不必依赖本次对话上下文。
- Skill 明确把 GitHub 仓库 Manifest 自动更新与本机已安装应用更新分开，降低错误地宣称“自动更新已完成”的风险。
- Skill 包含通用 prerelease 模板，但复杂上游仍需按实际 Release API、资产布局和安装行为调整；模板不是事实源。
- Skill 的 description 会产生少量常驻上下文，但触发词限定在 Bucket/Manifest/Release 维护场景，收益高于将流程放进常驻项目指令。

## Verification

- `.agents/skills/scoop-bucket-maintenance/SKILL.md` 存在且少于 500 行。
- frontmatter 仅包含 `name` 与 `description`；正文包含铁律、阶段清单、完成条件、反模式、报告格式和最终检查表。
- 项目 Note tree、Note format 与 archived-note 校验均通过。
- Skill 内容已结合已验证的 Any Listen prerelease 流程、GitHub Actions 成功运行结果、PowerShell 5.1/7 差异和当前 Bucket 脚本结构编写。
- CI 将 `BuildHelpers` 与 `Pester` 固定到兼容版本（`2.0.1` / `5.7.1`），避免 `psmodulecache` 自动取得 Pester 6 后与 Scoop 的 `Import-Bucket-Tests.ps1` 发生空测试集合兼容错误。
