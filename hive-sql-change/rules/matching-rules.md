# Rules: 表/字段匹配与血缘校验（matching-rules）

本文件用于 `workflows/analyze.md`（目标表/字段匹配）与 `workflows/locate.md`（血缘校验）。

## 一、匹配规则

### 匹配键

- 唯一匹配键：`schema.table.column`（如 `dwd.dwd_customer.customer_level`）。
- SQL 中的表引用：先解析表别名，再映射到 `schema.table`；无法解析别名时降低 confidence。
- 大小写：Hive 表/列名大小写不敏感，但输出中保持与元数据一致的写法。

### 禁止规则

- **禁止仅凭中文名称相似认定同一字段**（如“客户等级” ≠ 必然等于 `customer_level`）。
- 字段名称相似但存在歧义时，必须列出所有候选字段（schema.table.column + column_comment），返回 `NEED_CONFIRMATION`，由用户确认。

### 匹配结果码

| 结果码 | 场景 | 处理 |
| --- | --- | --- |
| MATCH_OK | schema.table.column 精确命中 | 继续 |
| TARGET_TABLE_NOT_FOUND | 目标表在表信息中不存在 | `NEED_MORE_INFORMATION` |
| TARGET_COLUMN_ALREADY_EXISTS | ADD_COLUMN 但目标字段已存在 | `NEED_CONFIRMATION`（确认是否改走 MODIFY） |
| TARGET_COLUMN_NOT_FOUND | DELETE/RENAME/MODIFY 但目标字段不存在 | `NEED_CONFIRMATION` |
| SOURCE_TABLE_NOT_FOUND | 源表不存在 | `NEED_MORE_INFORMATION` |
| SOURCE_COLUMN_NOT_FOUND | 源字段不存在 | `NEED_MORE_INFORMATION` |
| AMBIGUOUS_MATCH | 名称相似但无法唯一确定 | `NEED_CONFIRMATION`，列出候选 |

## 二、血缘校验规则

血缘记录结构：

```
source_schema / source_table / source_column
→
target_schema / target_table / target_column
（job_name）
```

### 校验流程

1. 用需求的 source（源表.源字段）匹配血缘记录的 source 侧。
2. 用需求的目标表.目标字段匹配血缘记录的 target 侧。
3. 两侧均命中且方向一致 → `LINEAGE_CONFIRMED`。
4. 血缘中不存在该映射 → `LINEAGE_NOT_FOUND`：**不直接判定错误**，降低 confidence 并提示补充血缘数据。
5. 血缘存在但映射到其他目标字段（如需求 customer_level，血缘是 customer_level → customer_name）→ `LINEAGE_CONFLICT`，要求人工确认，不得自行选择。

### 结果码

| 结果码 | 含义 | 处理 |
| --- | --- | --- |
| LINEAGE_CONFIRMED | source → target 血缘成立 | 继续，confidence 保持 |
| LINEAGE_NOT_FOUND | 未找到对应血缘 | 降低 confidence，提示补充血缘 |
| LINEAGE_CONFLICT | 血缘指向与需求不一致 | `LINEAGE_CONFLICT`，人工确认 |
