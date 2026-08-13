# Rules: 风险判断规则（risk-rules）

本文件用于 `workflows/generate.md` 的第八阶段风险判断。

## 风险等级定义

### LOW（低风险）

触发场景：

- 普通新增字段（非主键、非分区）
- 简单别名
- 简单表达式（常量、简单函数）
- 常量新增

### MEDIUM（中风险）

触发场景：

- JOIN 修改
- WHERE 修改
- CTE 修改
- 聚合逻辑修改
- 来源表修改

### HIGH（高风险）

触发场景：

- 删除字段
- 主键相关逻辑
- 目标表修改
- 分区字段相关
- JOIN 关系重大变化
- 多表血缘变化
- 大范围 INSERT 逻辑变化

## 规则 ID 清单

| 规则 ID | 等级 | 触发条件 |
| --- | --- | --- |
| LOW_ADD_COLUMN | LOW | 新增普通业务字段（非主键/分区） |
| LOW_SIMPLE_ALIAS | LOW | 仅新增或修改简单别名 |
| LOW_SIMPLE_EXPRESSION | LOW | 简单表达式或常量 |
| MEDIUM_MODIFY_JOIN | MEDIUM | 修改 JOIN 条件或类型 |
| MEDIUM_MODIFY_FILTER | MEDIUM | 修改 WHERE / HAVING |
| MEDIUM_MODIFY_CTE | MEDIUM | 修改 CTE 定义 |
| MEDIUM_MODIFY_AGG | MEDIUM | 修改聚合逻辑 |
| MEDIUM_MODIFY_SOURCE | MEDIUM | 修改来源表 |
| HIGH_DELETE_COLUMN | HIGH | 删除字段 |
| HIGH_PK_LOGIC | HIGH | 主键/唯一键相关逻辑 |
| HIGH_MODIFY_TARGET | HIGH | 修改目标表 |
| HIGH_PARTITION | HIGH | 分区字段相关 |
| HIGH_JOIN_MAJOR | HIGH | JOIN 关系重大变化（表数量/关联键变化） |
| HIGH_LINEAGE_MULTI | HIGH | 多表血缘变化 |
| HIGH_INSERT_LOGIC | HIGH | 大范围 INSERT 逻辑变化 |

## 评级规则

1. 汇总所有被触发的规则 ID。
2. 取**最高等级**作为整体风险等级（LOW < MEDIUM < HIGH）。
3. 同一修改点同时触发多个规则时，全部列出。

## 输出格式

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

## 原则

- 风险判断必须有依据，必须说明为什么是 LOW / MEDIUM / HIGH。
- 只返回等级（如 `LOW`）而没有任何理由，视为不合格输出。
- 血缘未确认（LINEAGE_NOT_FOUND / LINEAGE_CONFLICT）时，风险等级至少提升一档。
