# Workflow: 局部修改执行（execute）

**覆盖阶段**：第十阶段 SQL 修改原则

**加载规则**：`../rules/sql-rules.md`

## 输入

- 原始 SQL（Original SQL）
- ChangePlan（ChangeInstruction 集合）

## 原则（最重要约束）

- **禁止**让 LLM 重新生成整个 Hive SQL。
- 必须：原始 SQL + ChangeInstruction → 定位目标区域 → **只生成局部修改** → 合并回原 SQL。
- 尽可能保证以下内容**不变**：
  - SET 不变
  - 注释不变
  - 无关字段不变
  - 无关 JOIN 不变
  - 无关 WHERE 不变
  - 无关 CTE 不变
  - 无关 INSERT 不变

## 步骤

1. 按指令的 target_section 与 position 定位到具体行。
2. 仅对目标区域执行局部编辑（按 operation 类型）。
3. 同一 Job 的指令按 ChangePlan 顺序依次应用，应用前检查位置冲突。
4. 合并完成后输出**完整**修改后 SQL 预览。

## 输出

- 修改后 SQL 完整预览（状态 `PATCH_PREVIEW`）
- 若无法保证局部修改安全（目标区域无法精确定位 / 修改会波及无关区域）→ 返回 `PATCH_NOT_SAFE`，不输出整段重写结果。
