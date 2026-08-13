# Rules: Hive SQL 分析规则（sql-rules）

本文件用于 `workflows/locate.md`（SQL 解析与定位）与 `workflows/execute.md`（局部修改执行）。

## 一、SQL 元素识别

解析 Hive SQL 时至少识别以下元素，并记录各自行号范围：

- SET（hiveconf 参数，通常位于文件头部）
- COMMENT（注释，注意与 SQL 区分）
- CREATE TEMPORARY TABLE（临时表）
- CREATE TABLE AS（CTAS）
- WITH / CTE（公共表达式）
- INSERT OVERWRITE / INSERT INTO（写入语句）
- SELECT（投影列表与子查询）
- JOIN（含 LEFT / RIGHT / INNER / FULL / LEFT SEMI / LEFT ANTI）
- WHERE / HAVING（过滤条件）
- GROUP BY / ORDER BY / DISTRIBUTE BY / CLUSTER BY
- UNION / UNION ALL
- 子查询（括号内嵌套 SELECT）

## 二、Section 划分

将 SQL 划分为带编号的 Section，用于 ChangeInstruction 的 target_section：

- `SET_001`：文件头 SET 参数区
- `CTE_001`、`CTE_002`…：每个 CTE 定义
- `INSERT_001`、`INSERT_002`…：每个 INSERT 语句（含 INSERT_SELECT、INSERT_VALUES）
- `CTAS_001`：CREATE TABLE AS
- `TEMP_TABLE_001`：CREATE TEMPORARY TABLE

Section 内再定位子区域：投影列表（SELECT list）、JOIN 区、WHERE 区、GROUP BY 区、HAVING 区。

## 三、定位规则（按修改类型）

| 类型 | 定位方法 |
| --- | --- |
| ADD_COLUMN | 目标 INSERT 的 SELECT 投影列表；position 指定列之后插入 `alias.source_column AS target_column` |
| DELETE_COLUMN | 投影列表中删除目标列；同时检查表达式 / WHERE / JOIN ON / GROUP BY / HAVING 中的引用 |
| RENAME_COLUMN | 投影列表中修改别名 |
| MODIFY_COLUMN / MODIFY_EXPRESSION | 定位表达式所在区域并替换表达式本身，不改动其他部分 |
| MODIFY_FILTER | 替换 WHERE / HAVING 条件 |
| MODIFY_JOIN | 替换 JOIN 子句 |
| MODIFY_SOURCE_TABLE | 替换 FROM / JOIN 中的表引用，并同步校验字段前缀 |
| MODIFY_TARGET_TABLE | 替换 INSERT 目标表 |

## 四、别名解析

- 先确定目标表对应的 SQL 别名（无别名时使用表名本身）。
- 新增/修改字段引用统一写为 `alias.column`，禁止写未声明别名。
- 多个表存在同名字段时，必须显式写别名，否则 `AMBIGUOUS_MATCH`。

## 五、行号约定

- 行号为 1 起始（SQL 第一行为 1）。
- `line_start` / `line_end` 表示目标 Section 的起止行（含）。
- 定位结果必须落到具体的列或表达式，不能只到 Section 级别。

## 六、局部修改原则

- 只生成目标区域的局部修改，合并回原 SQL。
- SET、注释、无关字段、无关 JOIN、无关 WHERE、无关 CTE、无关 INSERT 一律不变。
- 无法精确定位目标区域，或修改必然波及无关区域时 → `PATCH_NOT_SAFE`。
- 禁止为了“顺手优化”改动任何无关内容。
