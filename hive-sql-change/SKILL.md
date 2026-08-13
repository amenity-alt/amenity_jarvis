---
name: hive-sql-change
description: 验证“业务需求驱动 Hive SQL 作业修改”全流程的 V1 Skill。当用户提出 Hive SQL 作业变更需求（新增/删除/重命名字段、修改表达式/过滤条件/JOIN/来源表/目标表），需要完成“需求解析 → 修改点 → 目标表/字段 → 受影响作业 → SQL 修改位置 → 血缘校验 → 修改指令 → 风险判断 → 修改方案 → SQL 预览 → Diff/验证”链路时使用。也适用于 Hive SQL 血缘校验、变更风险分级、修改方案生成与 SQL Patch 预览验证。不用于直接修改生产环境。
---

# hive-sql-change

> 验证“业务需求 → 修改点 → 目标表/字段 → 受影响作业 → SQL 修改位置 → 血缘校验 → 修改指令 → 风险判断 → 修改方案 → SQL 预览 → Diff/验证”链路是否可行的 V1 Skill。

## 使用前提

- 输入可包含：业务需求（必填）、表信息、字段信息、作业信息、Hive SQL、血缘数据。
- 本 Skill 只做分析与预览验证，**不修改生产环境、不保存平台、不自动部署**。

## 整体流程

1. **需求解析**：加载 `workflows/analyze.md`，将自然语言需求转换为 ChangePoint，校验目标/源表字段，定位受影响 Job。
2. **SQL 分析与定位**：加载 `workflows/locate.md`，解析 Hive SQL，定位具体修改区域，完成血缘校验。
3. **指令与方案生成**：加载 `workflows/generate.md`，生成 ChangeInstruction，合并多修改点，判断风险。
4. **局部修改执行**：加载 `workflows/execute.md`，原始 SQL + 指令 → 只改目标区域 → 修改后 SQL 预览。
5. **Diff 验证**：加载 `workflows/validate.md`，比较 Original vs Proposed，只允许目标区域变化。
6. **报告输出**：按 `templates/analysis-report.md` 组装完整分析报告。

## 按需加载

| 阶段 | 加载文件 |
| --- | --- |
| 需求解析 / 表字段匹配 / 作业定位 | `workflows/analyze.md` + `rules/change-types.md` + `rules/matching-rules.md` |
| SQL 分析 / 血缘校验 | `workflows/locate.md` + `rules/sql-rules.md` + `rules/matching-rules.md` |
| 指令生成 / 多修改点合并 / 风险 | `workflows/generate.md` + `rules/risk-rules.md` |
| 局部修改执行 | `workflows/execute.md` + `rules/sql-rules.md` |
| Diff 验证 | `workflows/validate.md` |

## 执行规则

1. 信息不足时**禁止猜测**，返回 `NEED_MORE_INFORMATION` 并逐项列出缺失内容。
2. 需要人工决策时返回 `NEED_CONFIRMATION`，不擅自选择。
3. 修改点冲突返回 `CHANGE_CONFLICT`，血缘冲突返回 `LINEAGE_CONFLICT`，均要求人工确认。
4. 无法保证局部修改安全时返回 `PATCH_NOT_SAFE`，禁止重写整个 SQL。
5. 验证不通过返回 `VALIDATION_FAILED`。

## 最终状态

只能输出以下状态之一：

`ANALYSIS_COMPLETE`、`PATCH_PREVIEW`、`NEED_MORE_INFORMATION`、`NEED_CONFIRMATION`、`CHANGE_CONFLICT`、`LINEAGE_CONFLICT`、`PATCH_NOT_SAFE`、`VALIDATION_FAILED`

## 参考文件

- 修改点结构：`templates/change-point.json`
- 修改指令结构：`templates/change-instruction.json`
- 分析报告模板：`templates/analysis-report.md`
- 完整示例：`examples/example.md`
