# Workflow: 指令生成与方案（generate）

**覆盖阶段**：第六阶段 生成 ChangeInstruction + 第七阶段 多修改点合并 + 第八阶段 风险判断

**加载规则**：`../rules/risk-rules.md`

## 输入

- ChangePoint 列表
- locate 输出的 SQL 定位结果（Job / Section / 行号）

## 步骤

### 1. 生成 ChangeInstruction

- AI **不直接重写整个 SQL**。
- 按 `../templates/change-instruction.json` 输出结构化修改指令，只描述“执行器应该怎么改”。
- 每个（Job × 修改点）生成一条 ChangeInstruction。

### 2. 多修改点合并

一个需求可能包含 CP-001、CP-002、CP-003，流程如下：

1. 每个修改点分别分析、分别生成 ChangeInstruction。
2. 检查指令之间的位置冲突。
3. 合并为 ChangePlan：**一个 Job → 一个 ChangePlan → 一个 SQL 修改预览**。

冲突规则：

- 两个修改点修改同一位置且语义冲突 → `CHANGE_CONFLICT`，不得自行选择其中一个，必须交人工确认。

### 3. 风险判断

按 `../rules/risk-rules.md` 对每个修改点评级，再给出合并后的整体风险：

- LOW：普通新增字段、简单别名、简单表达式、常量。
- MEDIUM：JOIN、WHERE、CTE、聚合、来源表修改。
- HIGH：删除字段、主键相关逻辑、目标表修改、分区字段、JOIN 关系重大变化、多表血缘变化、大范围 INSERT 逻辑变化。

```json
{
  "risk_level": "LOW",
  "risk_reasons": [
    "仅新增普通业务字段",
    "没有修改已有字段逻辑",
    "血缘关系明确"
  ],
  "triggered_rules": [
    "LOW_ADD_COLUMN"
  ]
}
```

风险判断必须有依据，必须说明为什么是 LOW / MEDIUM / HIGH，不能只返回等级。

## 输出

- ChangePlan（ChangeInstruction 集合，按 Job 分组）
- 风险评级（每个修改点 + 整体）
- 最终状态：`ANALYSIS_COMPLETE` / `CHANGE_CONFLICT`
