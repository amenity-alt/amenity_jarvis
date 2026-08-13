# Workflow: SQL 分析与定位（locate）

**覆盖阶段**：第四阶段 Hive SQL 分析 + 第五阶段 血缘校验

**加载规则**：`../rules/sql-rules.md`、`../rules/matching-rules.md`

## 输入

- ChangePoint 列表
- 受影响 Job（job_name）
- Hive SQL 原文

## 步骤

### 1. 解析 Hive SQL

按 `../rules/sql-rules.md` 识别并标注以下元素（记录各自行号范围）：

SET、COMMENT、CREATE TEMPORARY TABLE、CREATE TABLE AS、WITH / CTE、INSERT OVERWRITE、INSERT INTO、SELECT、JOIN、WHERE、GROUP BY、UNION / UNION ALL、子查询。

### 2. 定位具体修改区域

不能只报“修改 INSERT 部分”，必须定位到具体位置（Job → Section → 行号 → 字段/表达式）：

| 修改类型 | 定位目标 |
| --- | --- |
| ADD_COLUMN | 目标 SELECT 投影列表，指定列之后 |
| DELETE_COLUMN | 投影列表中的目标列（并检查表达式 / WHERE / JOIN / GROUP BY 中的引用） |
| RENAME_COLUMN | 投影列表中的别名 |
| MODIFY_COLUMN / MODIFY_EXPRESSION | 表达式所在区域（投影 / WHERE / JOIN ON / GROUP BY / HAVING） |
| MODIFY_FILTER | WHERE / HAVING 区域 |
| MODIFY_JOIN | JOIN 区域 |
| MODIFY_SOURCE_TABLE | FROM / JOIN 中的表引用 |
| MODIFY_TARGET_TABLE | INSERT 目标表 |

### 3. 输出定位结果

```json
{
  "job_name": "job_customer_daily",
  "section_type": "INSERT_SELECT",
  "line_start": 120,
  "line_end": 168,
  "target_column": "customer_name",
  "location_reason": "目标字段位于INSERT SELECT投影列表",
  "confidence": 0.94
}
```

### 4. 血缘校验

按 `../rules/matching-rules.md` 用血缘数据验证 source → target：

- 血缘存在 → `LINEAGE_CONFIRMED`
- 血缘不存在 → `LINEAGE_NOT_FOUND`：不直接判定错误，降低 confidence 并提示补充血缘。
- 血缘与需求冲突（如需求 customer_level，血缘却是 customer_level → customer_name）→ `LINEAGE_CONFLICT`，要求人工确认。

## 输出

- 每个 Job 的定位结果（section_type、line_start、line_end、target_column、location_reason、confidence）
- 血缘校验结果（LINEAGE_CONFIRMED / LINEAGE_NOT_FOUND / LINEAGE_CONFLICT）
- 最终状态：`ANALYSIS_COMPLETE` / `LINEAGE_CONFLICT` / `NEED_CONFIRMATION`
