"""Jarvis 主循环：先匹配本地技能，再交给 LLM。"""

import threading
import time

from . import avatar, envinfo, sfx, skills, tools, voice
from .llm import LLMError, chat

SYSTEM_PROMPT = (
    "你是 Jarvis，一个简洁、友好、可靠的中文个人助理。"
    "回答要简短直接，不要啰嗦；能用一句话说清的绝不用两句。"
)


def _build_messages(history):
    return [{"role": "system", "content": SYSTEM_PROMPT}] + history


def run(config, voice_mode=False, command=None, wake=False):
    v = voice.chinese_voice() if voice_mode else None
    av = avatar.Avatar() if wake else None
    panel_started = [False]
    panel_stop = threading.Event()
    state = {"status": "在线", "latency": 0, "session": 0, "log": []}
    history = []
    print("🤖 Jarvis 已启动。输入「帮助」查看本地技能，「退出」结束对话。")
    if voice_mode:
        print("🎙️ 语音模式：说话即可输入；任何时候输入「语音」可手动开启聆听。")
    if wake:
        print("🔊 待机中：说「Hey Jarvis」唤醒我。")

    def respond(text, sfx_mode="speak"):
        state["status"] = "回复中"
        if av:
            av.command("speak")
        if sfx_mode:
            sfx.play(sfx_mode, wait=True)
        print("Jarvis:", text)
        if voice_mode:
            voice.speak(text, voice=v)
        if av:
            av.command("idle")
        state["status"] = "待机" if wake else "在线"

    def get_input():
        if voice_mode:
            state["status"] = "聆听中"
            if av:
                av.command("listen")
            sfx.play("listen", wait=True)
            print("你: ", end="", flush=True)
            spoken = voice.listen(timeout=8)
            if spoken:
                print(spoken)
                return spoken
            print("（没听到，请再说一次，或直接打字）", flush=True)
            return input("").strip()
        return input("你: ").strip()

    def start_panel():
        """后台线程：每 5 秒把环境信息推给面板。"""
        if not av or panel_started[0]:
            return
        panel_started[0] = True

        def loop():
            while not panel_stop.is_set():
                try:
                    data = envinfo.collect()
                    data.update(
                        {
                            "status": state["status"],
                            "model": config["model"],
                            "latency": "%d ms" % state["latency"] if state["latency"] else "-",
                            "session": "第 %d 轮" % state["session"],
                            "log": "\n".join(state["log"]),
                        }
                    )
                    av.set_info(data)
                except Exception:
                    pass
                panel_stop.wait(5)

        threading.Thread(target=loop, daemon=True).start()

    def handle(user_input):
        state["session"] += 1
        state["log"].append("» " + user_input.strip()[:30])
        kind, result = skills.try_skill(user_input)
        if kind == "exit":
            respond("再见，有需要随时叫我。")
            return False
        if kind == "ok":
            respond(result)
            state["log"].append("« " + result[:36])
            state["log"] = state["log"][-10:]
            return True
        messages = _build_messages(history) + [{"role": "user", "content": user_input}]
        try:
            reply = _chat_with_tools(config, messages)
        except LLMError as exc:
            respond("AI 出错了：%s" % exc)
            return True
        history.append({"role": "user", "content": user_input})
        history.append({"role": "assistant", "content": reply})
        respond(reply)
        state["log"].append("« " + reply[:36])
        state["log"] = state["log"][-10:]
        return True

    def _chat_with_tools(config, messages):
        """调用大模型；模型请求工具时执行并把结果回传，最多 4 轮。"""
        state["status"] = "思考中"
        for _ in range(4):
            start = time.time()
            message = chat(
                config["api_key"],
                config["base_url"],
                config["model"],
                messages,
                tools=tools.TOOLS,
            )
            state["latency"] = int((time.time() - start) * 1000)
            envinfo.LATENCY_HIST.append(state["latency"])
            if not message.get("tool_calls"):
                return (message.get("content") or "").strip()
            messages.append(
                {
                    "role": "assistant",
                    "content": message.get("content") or "",
                    "tool_calls": message["tool_calls"],
                }
            )
            for call in message["tool_calls"]:
                fn = call.get("function", {})
                result = tools.run_tool(fn.get("name", ""), fn.get("arguments", "{}"))
                messages.append(
                    {"role": "tool", "tool_call_id": call.get("id", ""), "content": result}
                )
        raise LLMError("工具调用次数过多，已停止。")

    def wait_wake():
        """待机监听唤醒词，唤醒后回应「在」。"""
        while True:
            if voice.listen_for_wake():
                state["status"] = "唤醒"
                if av:
                    av.start("idle")
                    start_panel()
                sfx.play("wake", wait=True)
                respond("在", sfx_mode=None)
                return True
            print("🔊 待机中：说「Hey Jarvis」唤醒我。", flush=True)

    if command:
        handle(command)
        if av:
            panel_stop.set()
            av.stop()
        return

    while True:
        try:
            if wake:
                if not wait_wake():
                    break
                print("🎙️ 请说出指令…", flush=True)
                user_input = get_input()
            else:
                user_input = get_input()
        except (EOFError, KeyboardInterrupt):
            print()
            respond("再见，有需要随时叫我。")
            break
        if not user_input:
            continue
        if user_input.strip().lower() in ("语音", "voice"):
            print("🎙️ 请说话…")
            spoken = voice.listen(timeout=6)
            if not spoken:
                respond("没有听清，请再说一次（首次使用请在系统弹窗中允许麦克风和语音识别权限）。")
                continue
            print("你:", spoken)
            user_input = spoken
        if not handle(user_input):
            break
    if av:
        panel_stop.set()
        av.stop()
