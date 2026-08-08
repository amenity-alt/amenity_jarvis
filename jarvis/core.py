"""Jarvis 主循环：先匹配本地技能，再交给 LLM。"""

from . import skills, voice
from .llm import LLMError, chat

SYSTEM_PROMPT = (
    "你是 Jarvis，一个简洁、友好、可靠的中文个人助理。"
    "回答要简短直接，不要啰嗦；能用一句话说清的绝不用两句。"
)


def _build_messages(history):
    return [{"role": "system", "content": SYSTEM_PROMPT}] + history


def run(config, voice_mode=False, command=None, wake=False):
    v = voice.chinese_voice() if voice_mode else None
    history = []
    print("🤖 Jarvis 已启动。输入「帮助」查看本地技能，「退出」结束对话。")
    if voice_mode:
        print("🎙️ 语音模式：说话即可输入；任何时候输入「语音」可手动开启聆听。")
    if wake:
        print("🔊 待机中：说「Hey Jarvis」唤醒我。")

    def respond(text):
        print("Jarvis:", text)
        if voice_mode:
            voice.speak(text, voice=v)

    def get_input():
        if voice_mode:
            print("你: ", end="", flush=True)
            spoken = voice.listen(timeout=5)
            if spoken:
                print(spoken)
                return spoken
            return input("").strip()
        return input("你: ").strip()

    def handle(user_input):
        kind, result = skills.try_skill(user_input)
        if kind == "exit":
            respond("再见，有需要随时叫我。")
            return False
        if kind == "ok":
            respond(result)
            return True
        history.append({"role": "user", "content": user_input})
        try:
            reply = chat(
                config["api_key"],
                config["base_url"],
                config["model"],
                _build_messages(history),
            )
        except LLMError as exc:
            respond("AI 出错了：%s" % exc)
            history.pop()
            return True
        history.append({"role": "assistant", "content": reply})
        respond(reply)
        return True

    def wait_wake():
        """待机监听唤醒词，唤醒后回应「在」。"""
        while True:
            if voice.listen_for_wake():
                respond("在")
                return True
            print("🔊 待机中：说「Hey Jarvis」唤醒我。", flush=True)

    if command:
        handle(command)
        return

    while True:
        try:
            if wake:
                if not wait_wake():
                    break
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
