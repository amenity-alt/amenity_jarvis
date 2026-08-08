# AGENTS.md — Jarvis 项目协作规则

## 自动提交（用户要求）
- 每次修改代码后，**必须**自动执行 `git add -A`、`git commit`（写清楚的中文/英文提交信息）、`git push` 到 `origin/main`。
- 不要等用户催促；修改完成并验证通过后立即提交推送。
- 不要把 `.env`、`notes.md`、`__pycache__` 等已 gitignore 的文件提交进去。

## 项目说明
- 零第三方依赖：只用 Python 3.9+ 标准库 + macOS 原生能力（Speech 框架、say、Swift）。
- 语音识别/头像等 Swift 程序：源码改动后会自动重编译（基于 mtime 检测），无需手动操作。
- 交流语言：中文。
