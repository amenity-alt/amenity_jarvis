# Rules: 修改类型定义（change-types）

本文件定义支持的 9 种修改类型，用于 `workflows/analyze.md` 把业务需求解析为 ChangePoint。

## 修改类型总览

| 类型 | 含义 | SQL 主要影响区域 |
| --- | --- | --- |
| ADD_COLUMN | 新增字段 | SELECT 投影列表 |
| DELETE_COLUMN | 删除字段 | SELECT 投影列表（及引用处） |
| RENAME_COLUMN | 重命名字段 | SELECT 投影列表别名 |
| MODIFY_COLUMN | 修改字段定义/类型 | 投影列表、目标表定义 |
| MODIFY_EXPRESSION | 修改表达式 | 投影 / WHERE / JOIN ON / GROUP BY / HAVING |
| MODIFY_FILTER | 修改过滤条件 | WHERE / HAVING |
| MODIFY_JOIN | 修改 JOIN | JOIN / FROM |
| MODIFY_SOURCE_TABLE | 修改来源表 | FROM / JOIN 表引用 |
| MODIFY_TARGET_TABLE | 修改目标表 | INSERT 目标表 |

## 各类型定义与必填信息

### ADD_COLUMN

- 定义：向目标表新增一个字段，通常来源某个源表字段或常量。
- 必填：target_table、target_column、source_table、source_column（position 可选）。
- 可选：position（AFTER/BEFORE + 参考列），缺省时默认追加到投影列表末尾。
- 示例：“客户宽表增加客户等级字段，来源 ods_customer.customer_level，放在 customer_name 后面。”

### DELETE_COLUMN

- 定义：从目标表删除一个字段。
- 必填：target_table、target_column。
- 注意：必须同时检查该字段在表达式 / WHERE / JOIN / GROUP BY 中的引用。

### RENAME_COLUMN

- 定义：重命名目标字段。
- 必填：target_table、原列名、新列名。

### MODIFY_COLUMN

- 定义：修改目标字段的定义（类型、默认值、来源表达式）。
- 必填：target_table、target_column、新定义/新表达式。

### MODIFY_EXPRESSION

- 定义：修改某处 SQL 表达式（不改变字段集合）。
- 必填：job/section、原表达式、新表达式。

### MODIFY_FILTER

- 定义：修改 WHERE / HAVING 过滤条件。
- 必填：job/section、原条件、新条件。

### MODIFY_JOIN

- 定义：修改 JOIN 关联关系（条件、类型、关联表）。
- 必填：job/section、原 JOIN、新 JOIN。

### MODIFY_SOURCE_TABLE

- 定义：更换来源表。
- 必填：job、原来源表、新来源表。
- 注意：更换来源表必须重新校验血缘与字段映射。

### MODIFY_TARGET_TABLE

- 定义：更换写入的目标表。
- 必填：job、原目标表、新目标表。
- 注意：必须确认新目标表结构与被写入字段一致。

## 解析原则

1. 一个需求可包含多个修改点，每个修改点生成一个 ChangePoint。
2. 类型无法确定、或必填信息缺失时，禁止猜测 → `NEED_MORE_INFORMATION`。
3. 同一修改点同时命中多个类型时，按“字段层 → 表达式层 → 语句层”优先级选择最具体的一种：
   - 字段层：ADD / DELETE / RENAME / MODIFY_COLUMN
   - 表达式层：MODIFY_EXPRESSION
   - 语句层：MODIFY_FILTER / MODIFY_JOIN / MODIFY_SOURCE_TABLE / MODIFY_TARGET_TABLE
