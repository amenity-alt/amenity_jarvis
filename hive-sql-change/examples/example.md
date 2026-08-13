# Example: 客户宽表增加客户等级字段

本示例演示完整链路：需求 → 修改点 → 目标表/字段 → 受影响作业 → SQL 修改位置 → 血缘校验 → 修改指令 → 风险判断 → 修改方案 → SQL 预览 → Diff/验证。

## 输入数据

### 业务需求

> 客户宽表增加客户等级字段，来源 ods_customer.customer_level，放在 customer_name 后面。

### 表信息

| schema_name | table_name | table_comment | table_type |
| --- | --- | --- | --- |
| dwd | dwd_customer | 客户宽表 | MANAGED |
| ods | ods_customer | 客户基础表 | EXTERNAL |

### 字段信息（相关部分）

| schema_name | table_name | column_name | column_comment | data_type | is_pk |
| --- | --- | --- | --- | --- | --- |
| dwd | dwd_customer | customer_id | 客户ID | bigint | true |
| dwd | dwd_customer | customer_name | 客户名称 | string | false |
| ods | ods_customer | customer_id | 客户ID | bigint | false |
| ods | ods_customer | customer_name | 客户名称 | string | false |
| ods | ods_customer | customer_level | 客户等级 | string | false |

### 作业信息

- job_name：job_customer_daily

### Hive SQL（job_customer_daily）

```sql
-- 客户宽表每日任务
SET hive.exec.dynamic.partition=true;

INSERT OVERWRITE TABLE dwd.dwd_customer
SELECT
    customer_id,
    customer_name
FROM ods.ods_customer;
```

### 血缘数据

| source_schema | source_table | source_column | target_schema | target_table | target_column | job_name |
| --- | --- | --- | --- | --- | --- | --- |
| ods | ods_customer | customer_id | dwd | dwd_customer | customer_id | job_customer_daily |
| ods | ods_customer | customer_name | dwd | dwd_customer | customer_name | job_customer_daily |
| ods | ods_customer | customer_level | dwd | dwd_customer | customer_level | job_customer_daily |

## 执行过程

### Stage 1：需求解析（analyze.md）

```json
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
```

### Stage 2：表/字段匹配（matching-rules.md）

- dwd.dwd_customer 存在 ✓
- dwd.dwd_customer.customer_level 不存在（可新增）✓
- ods.ods_customer 存在 ✓
- ods.ods_customer.customer_level 存在 ✓
- 结论：MATCH_OK

### Stage 3：作业定位

```json
{
  "target_table": "dwd_customer",
  "target_column": "customer_level",
  "candidate_jobs": [
    { "job_name": "job_customer_daily", "reason": "血缘直接命中", "confidence": 0.96 }
  ]
}
```

### Stage 4：SQL 分析定位（locate.md + sql-rules.md）

- 元素识别：SET（行 2）、INSERT OVERWRITE（行 4）、SELECT 投影列表（行 5-8）、FROM（行 8）。
- 定位结果：

```json
{
  "job_name": "job_customer_daily",
  "section_type": "INSERT_SELECT",
  "line_start": 5,
  "line_end": 8,
  "target_column": "customer_name",
  "location_reason": "目标字段位于INSERT SELECT投影列表",
  "confidence": 0.94
}
```

### Stage 5：血缘校验

```
ods.ods_customer.customer_level → dwd.dwd_customer.customer_level
```

- 结果：LINEAGE_CONFIRMED（需求来源与血缘一致）

### Stage 6：生成 ChangeInstruction（generate.md）

```json
{
  "instruction_id": "CI-001",
  "job_name": "job_customer_daily",
  "target_section": "INSERT_001",
  "operations": [
    {
      "operation": "ADD_COLUMN",
      "target_column": "customer_level",
      "expression": "src.customer_level AS customer_level",
      "position": { "type": "AFTER", "column": "customer_name" },
      "reason": "新增客户等级字段"
    }
  ]
}
```

### Stage 7：多修改点合并

- 本需求只有 CP-001，无冲突，ChangePlan = [CI-001]。

### Stage 8：风险判断（risk-rules.md）

```json
{
  "risk_level": "LOW",
  "risk_reasons": [
    "仅新增普通业务字段",
    "没有修改已有字段逻辑",
    "血缘关系明确"
  ],
  "triggered_rules": ["LOW_ADD_COLUMN"]
}
```

### Stage 9：局部修改执行（execute.md）

原始 SQL + CI-001 → 仅在投影列表 customer_name 之后插入一行：

```sql
-- 客户宽表每日任务
SET hive.exec.dynamic.partition=true;

INSERT OVERWRITE TABLE dwd.dwd_customer
SELECT
    customer_id,
    customer_name,
    src.customer_level AS customer_level
FROM ods.ods_customer src;
```

说明：表引用补了别名 `src`（sql-rules.md 别名解析规则），SET 与注释保持不变。

### Stage 10：Diff 验证（validate.md）

```diff
 SET hive.exec.dynamic.partition=true;

 INSERT OVERWRITE TABLE dwd.dwd_customer
 SELECT
     customer_id,
-    customer_name
-FROM ods.ods_customer;
+    customer_name,
+    src.customer_level AS customer_level
+FROM ods.ods_customer src;
```

| 校验项 | 结果 |
| --- | --- |
| 语法 | 通过 |
| 字段 | 通过（customer_level 已定义于源表） |
| 表引用 | 通过（ods.ods_customer 别名 src 有效） |
| 血缘 | 通过（LINEAGE_CONFIRMED） |
| Diff 范围 | 通过（仅投影列表目标区域变化） |

### 最终报告（analysis-report.md 模板）

# Hive SQL 修改分析报告

## 1. 业务需求

> 客户宽表增加客户等级字段，来源 ods_customer.customer_level，放在 customer_name 后面。

## 2. 修改点

- CP-001：ADD_COLUMN dwd.dwd_customer.customer_level（来源 ods.ods_customer.customer_level，位于 customer_name 之后）

## 3. 目标表

- `dwd.dwd_customer`：客户宽表，MANAGED

## 4. 影响作业

- job_customer_daily：血缘直接命中，confidence 0.96

## 5. SQL 修改位置

| Job | Section | 行号 | 字段/区域 | 定位原因 | confidence |
| --- | --- | --- | --- | --- | --- |
| job_customer_daily | INSERT_001 (INSERT_SELECT) | 5-8 | customer_name 之后 | 目标字段位于 INSERT SELECT 投影列表 | 0.94 |

## 6. 血缘分析

```
ods.ods_customer.customer_level → dwd.dwd_customer.customer_level
```

- 结果：LINEAGE_CONFIRMED

## 7. 修改指令

CI-001（见 Stage 6）

## 8. 风险等级

- 等级：LOW
- 依据：仅新增普通业务字段；没有修改已有字段逻辑；血缘关系明确
- 触发规则：LOW_ADD_COLUMN

## 9. 修改前 SQL（相关区域）

```sql
INSERT OVERWRITE TABLE dwd.dwd_customer
SELECT
    customer_id,
    customer_name
FROM ods.ods_customer;
```

## 10. 修改后 SQL（相关区域）

```sql
INSERT OVERWRITE TABLE dwd.dwd_customer
SELECT
    customer_id,
    customer_name,
    src.customer_level AS customer_level
FROM ods.ods_customer src;
```

## 11. Diff

```diff
 SELECT
     customer_id,
-    customer_name
-FROM ods.ods_customer;
+    customer_name,
+    src.customer_level AS customer_level
+FROM ods.ods_customer src;
```

## 12. 验证结果

| 校验项 | 结果 |
| --- | --- |
| 语法 | 通过 |
| 字段 | 通过 |
| 表引用 | 通过 |
| 血缘 | 通过 |
| Diff 范围 | 通过 |

## 13. 最终状态

- `PATCH_PREVIEW`

---

## 反例：信息不足（必须返回 NEED_MORE_INFORMATION）

用户只输入：

> 增加客户等级字段。

缺少：目标表、来源表、来源字段、位置。

输出：

```json
{
  "final_status": "NEED_MORE_INFORMATION",
  "missing": [
    "target_table（目标表，如 dwd.dwd_customer）",
    "source_table（来源表，如 ods.ods_customer）",
    "source_column（来源字段，如 customer_level）"
  ]
}
```

禁止猜测目标表或来源字段。
