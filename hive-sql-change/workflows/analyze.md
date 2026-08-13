# Workflow: 需求解析（analyze）

**覆盖阶段**：第一阶段 需求解析 + 第二阶段 目标表/字段匹配 + 第三阶段 作业定位

**加载规则**：`../rules/change-types.md`、`../rules/matching-rules.md`

## 输入

- 业务需求（自然语言，必填）
- 可选：表信息（schema_name / table_name / table_comment / table_type）
- 可选：字段信息（schema_name / table_name / column_name / column_comment / data_type / is_pk）
- 可选：作业信息（job_name）
- 可选：血缘数据（source_schema / source_table / source_column / target_schema / target_table / target_column / job_name）

## 步骤

### 1. 解析需求 → ChangePoint

- 按 `../rules/change-types.md` 判断修改类型。
- 按 `../templates/change-point.json` 输出 ChangePoint。
- 每个独立修改生成一个 ChangePoint（CP-001、CP-002…），一个需求可包含多个修改点。

### 2. 完整性检查（禁止猜测）

缺少以下关键信息时，返回 `NEED_MORE_INFORMATION`，并**逐项列出缺失内容**，不进行任何猜测：

| 修改类型 | 必填信息 |
| --- | --- |
| ADD_COLUMN | target_table、target_column、source_table、source_column（position 可选） |
| DELETE_COLUMN | target_table、target_column |
| RENAME_COLUMN | target_table、原列名、新列名 |
| MODIFY_COLUMN | target_table、target_column、新定义/新表达式 |
| MODIFY_EXPRESSION | job/section、原表达式、新表达式 |
| MODIFY_FILTER | job/section、原条件、新条件 |
| MODIFY_JOIN | job/section、原 JOIN、新 JOIN |
| MODIFY_SOURCE_TABLE | job、原来源表、新来源表 |
| MODIFY_TARGET_TABLE | job、原目标表、新目标表 |

### 3. 目标表/字段匹配

按 `../rules/matching-rules.md` 校验：

- 目标表是否存在；目标字段是否存在；源表是否存在；源字段是否存在。
- ADD_COLUMN 时目标字段已存在 → `TARGET_COLUMN_ALREADY_EXISTS`
- DELETE / RENAME / MODIFY 时目标字段不存在 → `TARGET_COLUMN_NOT_FOUND`
- 禁止仅凭中文名称相似认定同一字段；名称相似但存在歧义时，必须列出候选字段。

### 4. 作业定位

- 使用目标表 + 血缘数据 + Job 信息匹配受影响作业。
- 命中多个 Job 时必须**全部列出**（candidate_jobs），不擅自选择。
- 无法确定 → `NEED_CONFIRMATION`。

## 输出

```json
{
  "change_points": [
    {
      "change_point_id": "CP-001",
      "change_type": "ADD_COLUMN",
      "target_schema": "dwd",
      "target_table": "dwd_customer",
      "target_column": "customer_level",
      "source_schema": "ods",
      "source_table": "ods_customer",
      "source_column": "customer_level",
      "position": { "type": "AFTER", "column": "customer_name" },
      "reason": "客户宽表新增客户等级字段",
      "confidence": 0.95
    }
  ],
  "match_results": {
    "target_table_found": true,
    "target_column_found": false,
    "source_table_found": true,
    "source_column_found": true
  },
  "candidate_jobs": [
    {
      "job_name": "job_customer_daily",
      "reason": "血缘直接命中",
      "confidence": 0.96
    }
  ],
  "final_status": "ANALYSIS_COMPLETE"
}
```

## 最终状态

- `ANALYSIS_COMPLETE`：解析、匹配、作业定位全部完成。
- `NEED_MORE_INFORMATION`：缺少关键信息。
- `NEED_CONFIRMATION`：字段歧义或无法确定作业。
- `TARGET_COLUMN_ALREADY_EXISTS` / `TARGET_COLUMN_NOT_FOUND`：匹配失败（随报告输出，由 SKILL.md 汇总为 NEED_CONFIRMATION 或最终状态）。
