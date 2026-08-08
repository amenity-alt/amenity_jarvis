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

唤醒的同时，屏幕中央会弹出钢铁侠风格的 **JARVIS 全息头像**（浮动窗口，可拖动）：待机时是旋转的弧反应堆光环，聆听时浮现声波柱，说话时扩散波纹。用 Swift 原生实现，与语音程序一样首次自动编译、随源码自动更新。

头像由 **420 个光点粒子** 组成——唤醒瞬间光点从**整个屏幕各处**飞来汇聚成环，再变身**科幻 AI 核心**：旋转六边形外框 + 反向光环 + HAL 式发光眼睛与瞳孔 + 扫描辐条，说话时扩散波纹、聆听时瞳孔脉动。配合程序实时合成的**科幻音效**（唤醒上扬音、聆听三连升调、说话下滑音，带泛音与空间回响）。

音效全部**播放完毕后才开启麦克风**，避免扬声器声音干扰语音识别。
Jarvis 使用系统内置的**中文女声（Tingting）**自然朗读（Rocko 等 novelty 男声在部分系统上不可用，已自动规避）。

左下角还有一个 **环境信息面板**（悬浮窗口，可拖动）：实时显示时间、日期、天气（自动定位、30 分钟刷新）、电池、系统负载、内存和网络状态，每 5 秒刷新。

## 本地技能

| 指令 | 示例 | 说明 |
| --- | --- | --- |
| 时间 / 日期 | `时间` | 报出当前时间/日期 |
| 打开 | `打开 备忘录` | 打开 Mac 应用（支持中文别名） |
| 搜索 | `搜索 苹果发布会` | 浏览器打开 Bing 搜索 |
| 天气 | `天气 北京` / `今天天气怎么样` | 查询天气（不指定城市时按 IP 自动定位） |
| 记录 | `记录 明天 9 点开会` | 追加到 `notes.md`（已 gitignore） |
| 语音 | `语音` | 用麦克风输入一句话（`--voice` 模式下自动聆听） |
| 帮助 | `帮助` | 显示技能列表 |
| 退出 | `退出` | 结束对话 |

其他问题会自动交给 DeepSeek 等大模型回答，带上下文记忆。

## 联网能力

Jarvis 通过函数调用让大模型自主联网：遇到需要实时信息的问题时，会自动调用天气 API（wttr.in）或网页搜索（DuckDuckGo）拿到结果后再回答，全程免费、无需额外 Key。

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
- [x] 全息头像（光点粒子 + 科幻音效）
- [x] 环境信息面板（时间/天气/电量/负载/内存/网络）
- [ ] 更多技能：提醒、系统控制、网页信息抓取
- [x] 联网能力：天气（自动定位）+ 网页搜索（工具调用）
- [ ] 记忆持久化（对话历史存文件/向量库）

## 参考的开源项目

- [alexako/Jarvis](https://github.com/alexako/Jarvis)：Whisper 语音识别 + 唤醒词，支持 DeepSeek/Claude
- [Harsh-Jain-10/Jarvis-MVP](https://github.com/Harsh-Jain-10/Jarvis-MVP)：Python 语音助理 MVP，适合入门
- [PersonalJarvis/PersonalJarvis](https://github.com/PersonalJarvis/PersonalJarvis)：自托管语音助理
- [akshayaggarwal99/jarvis-ai-assistant](https://github.com/akshayaggarwal99/jarvis-ai-assistant)：面向 Mac 的语音 AI 助理
- [mahinexe/JARVIS](https://github.com/mahinexe/JARVIS)：带桌面 GUI 的 Python 语音助理

本项目采用 MIT 协议。
