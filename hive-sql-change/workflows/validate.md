# Workflow: Diff 验证（validate）

**覆盖阶段**：第十一阶段 Diff 验证

## 输入

- Original SQL（原始 SQL）
- Proposed SQL（execute 输出的修改后 SQL）

## 步骤

### 1. 生成 Diff

逐行/逐段比较 Original vs Proposed，输出 Diff：

```diff
- old
+ new
```

### 2. 校验范围

只允许目标区域发生变化，出现以下情况 → `VALIDATION_FAILED`：

- 目标区域之外发生 SET 变化
- 目标区域之外发生注释变化
- 无关字段 / 无关 JOIN / 无关 WHERE / 无关 CTE / 无关 INSERT 发生变化
- 出现预期外的 WHERE、JOIN、SET 变化

### 3. 校验项

| 校验项 | 通过条件 |
| --- | --- |
| 语法 | SQL 结构完整，括号 / 引号闭合，关键字顺序正确 |
| 字段 | 目标字段存在，命名与 ChangeInstruction 一致 |
| 表引用 | 表名与别名引用有效，目标表正确 |
| 血缘 | source → target 与需求一致 |
| Diff 范围 | 变化仅限目标区域 |

## 输出

- Diff 内容
- 各项校验结果（通过 / 不通过 + 原因）
- 最终状态：`PATCH_PREVIEW`（全部通过）或 `VALIDATION_FAILED`（任一不通过）
