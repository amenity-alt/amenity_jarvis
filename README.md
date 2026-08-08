# amenity_jarvis
# 🤖 Jarvis

一个运行在你 Mac 上的个人 AI 助理：本地技能（时间、打开应用、搜索、天气、笔记）+ 大模型对话 + 语音输入输出。

灵感来自钢铁侠的 Jarvis 与 GitHub 上众多开源项目（见文末），本项目零第三方依赖、开箱即跑。

## 快速开始

需要 Python 3.9+（macOS 自带）。

```bash
cp .env.example .env
# 编辑 .env，填入你的 DeepSeek API Key（https://platform.deepseek.com）

python3 main.py              # 交互对话
python3 main.py --voice      # 语音模式：说话输入 + 中文语音朗读
python3 main.py --wake --voice  # 待机唤醒：说「Hey Jarvis」激活后语音对话
python3 main.py -c "时间"     # 单次执行一条指令
```

首次使用语音输入时，Jarvis 会用 macOS 自带 Swift 编译一个小的语音识别程序（只需一次），并在系统弹窗中申请**麦克风**和**语音识别**权限，请点允许。

语音识别使用 macOS 原生 Speech 框架（中文），完全本地、免费。

`--wake` 模式下 Jarvis 会持续待机监听，听到「Hey Jarvis」「嘿 贾维斯」后回「在」并开始聆听指令；说完一条指令后自动回到待机。

## 本地技能

| 指令 | 示例 | 说明 |
| --- | --- | --- |
| 时间 / 日期 | `时间` | 报出当前时间/日期 |
| 打开 | `打开 备忘录` | 打开 Mac 应用（支持中文别名） |
| 搜索 | `搜索 苹果发布会` | 浏览器打开 Bing 搜索 |
| 天气 | `天气 北京` | 查询天气（默认上海） |
| 记录 | `记录 明天 9 点开会` | 追加到 `notes.md`（已 gitignore） |
| 语音 | `语音` | 用麦克风输入一句话（`--voice` 模式下自动聆听） |
| 帮助 | `帮助` | 显示技能列表 |
| 退出 | `退出` | 结束对话 |

其他问题会自动交给 DeepSeek 等大模型回答，带上下文记忆。

## 配置

通过 `.env` 或环境变量：

| 变量 | 默认值 | 说明 |
| --- | --- | --- |
| `DEEPSEEK_API_KEY` | 无 | DeepSeek API Key（必填才能用 AI 对话） |
| `JARVIS_MODEL` | `deepseek-chat` | 模型名，可换其他 OpenAI 兼容模型 |
| `JARVIS_API_BASE` | `https://api.deepseek.com` | OpenAI 兼容接口地址 |

## 项目结构

```text
main.py              # 入口
jarvis/
  config.py          # 配置加载（.env / 环境变量）
  llm.py             # OpenAI 兼容对话客户端（标准库实现）
  skills.py          # 本地技能
  voice.py           # 语音输出（say）+ 语音输入（Speech 框架）
  stt/               # 语音识别 Swift 源码与权限描述
  core.py            # 主循环：技能优先，其次 LLM
```

## 路线图

- [x] 语音输入（macOS Speech 框架）
- [x] 唤醒词「Hey Jarvis」
- [ ] 更多技能：提醒、系统控制、网页信息抓取
- [ ] 记忆持久化（对话历史存文件/向量库）

## 参考的开源项目

- [alexako/Jarvis](https://github.com/alexako/Jarvis)：Whisper 语音识别 + 唤醒词，支持 DeepSeek/Claude
- [Harsh-Jain-10/Jarvis-MVP](https://github.com/Harsh-Jain-10/Jarvis-MVP)：Python 语音助理 MVP，适合入门
- [PersonalJarvis/PersonalJarvis](https://github.com/PersonalJarvis/PersonalJarvis)：自托管语音助理
- [akshayaggarwal99/jarvis-ai-assistant](https://github.com/akshayaggarwal99/jarvis-ai-assistant)：面向 Mac 的语音 AI 助理
- [mahinexe/JARVIS](https://github.com/mahinexe/JARVIS)：带桌面 GUI 的 Python 语音助理

本项目采用 MIT 协议。
