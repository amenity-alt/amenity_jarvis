# Hive SQL 修改分析报告

## 1. 业务需求

> 原始需求（用户原话）。

## 2. 修改点

- CP-001：ADD_COLUMN dwd.dwd_customer.customer_level（来源 ods.ods_customer.customer_level，位于 customer_name 之后）
- CP-002：……

## 3. 目标表

- `schema.table`：表注释、表类型

## 4. 影响作业

- job_name：原因 / confidence
- 多作业时全部列出。

## 5. SQL 修改位置

| Job | Section | 行号 | 字段/区域 | 定位原因 | confidence |
| --- | --- | --- | --- | --- | --- |
| job_customer_daily | INSERT_001 (INSERT_SELECT) | 120-168 | customer_name 之后 | 目标字段位于 INSERT SELECT 投影列表 | 0.94 |

## 6. 血缘分析

```
ods.ods_customer.customer_level
→
dwd.dwd_customer.customer_level
```

- 结果：LINEAGE_CONFIRMED / LINEAGE_NOT_FOUND / LINEAGE_CONFLICT
- 说明：……

## 7. 修改指令

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

## 8. 风险等级

- 等级：LOW / MEDIUM / HIGH
- 依据：
  - 仅新增普通业务字段
  - 没有修改已有字段逻辑
  - 血缘关系明确
- 触发规则：LOW_ADD_COLUMN

## 9. 修改前 SQL（相关区域）

```sql
-- job_customer_daily / INSERT_001（行 120-168，仅显示相关区域）
SELECT
    customer_id,
    customer_name
FROM ods_customer;
```

## 10. 修改后 SQL（相关区域）

```sql
SELECT
    customer_id,
    customer_name,
    src.customer_level AS customer_level
FROM ods_customer src;
```

## 11. Diff

```diff
 SELECT
     customer_id,
-    customer_name
+    customer_name,
+    src.customer_level AS customer_level
 FROM ods_customer src;
```

## 12. 验证结果

| 校验项 | 结果 |
| --- | --- |
| 语法 | 通过 / 不通过 |
| 字段 | 通过 / 不通过 |
| 表引用 | 通过 / 不通过 |
| 血缘 | 通过 / 不通过 |
| Diff 范围 | 通过 / 不通过（仅目标区域变化） |

## 13. 最终状态

- `ANALYSIS_COMPLETE` / `PATCH_PREVIEW` / `NEED_MORE_INFORMATION` / `NEED_CONFIRMATION` / `CHANGE_CONFLICT` / `LINEAGE_CONFLICT` / `PATCH_NOT_SAFE` / `VALIDATION_FAILED`
