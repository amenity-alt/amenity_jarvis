"""语音能力：say 朗读输出 + macOS Speech 框架语音输入。"""

import os
import shutil
import subprocess
import time

APP_ALIASES = {
    "计算器": "Calculator",
    "备忘录": "Notes",
    "浏览器": "Safari",
    "终端": "Terminal",
    "音乐": "Music",
    "照片": "Photos",
    "微信": "WeChat",
    "邮件": "Mail",
    "设置": "System Settings",
    "系统设置": "System Settings",
}

# 变调量（半音）：降低让声音更低沉，模拟男声
MALE_PITCH = -320

WAKE_PHRASES = (
    "hey jarvis",
    "heyjarvis",
    "嘿 贾维斯",
    "嘿贾维斯",
    "你好 贾维斯",
    "你好贾维斯",
    "贾维斯",
)
WAKE_TIMEOUT = 30

_STT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "stt")
_STT_SOURCE = os.path.join(_STT_DIR, "SpeechInput.swift")
_STT_PLIST = os.path.join(_STT_DIR, "Info.plist")


def available():
    return shutil.which("say") is not None


def _voices():
    try:
        out = subprocess.run(["say", "-v", "?"], capture_output=True, text=True).stdout
    except Exception:
        return []
    return [line.split()[0] for line in out.splitlines() if line.strip()]


def chinese_voice():
    # 只用真正能合成中文的内置语音（Rocko 等 novelty 男声不可用）
    for candidate in ["Tingting", "Meijia", "Sinji"]:
        if candidate in _voices():
            return candidate
    return None


def _voice_play_binary():
    return os.path.join(os.path.expanduser("~"), ".jarvis", "jarvis_voice_play")


def _compile_voice_play():
    source = os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "voice_play", "JarvisVoicePlay.swift"
    )
    binary = _voice_play_binary()
    if os.path.exists(binary) and os.path.getmtime(binary) >= os.path.getmtime(source):
        return binary
    if shutil.which("swiftc") is None or not os.path.exists(source):
        return None
    try:
        os.makedirs(os.path.dirname(binary), exist_ok=True)
        cache_dir = os.path.join(os.path.dirname(binary), "clang-cache")
        os.makedirs(cache_dir, exist_ok=True)
        env = dict(os.environ, CLANG_MODULE_CACHE_PATH=cache_dir)
        tmp = binary + ".tmp"
        result = subprocess.run(
            ["swiftc", "-O", source, "-o", tmp],
            capture_output=True,
            text=True,
            env=env,
        )
        if result.returncode != 0:
            return None
        os.replace(tmp, binary)
        return binary
    except Exception:
        return None


def speak(text, voice=None, male=True):
    """朗读文本：先用 say 渲染成音频，再变调播放（更低沉）。"""
    if not available():
        return False
    voice = voice or chinese_voice()
    tmp = os.path.join(os.path.expanduser("~"), ".jarvis", "say_tmp.aiff")
    try:
        os.makedirs(os.path.dirname(tmp), exist_ok=True)
        cmd = ["say"]
        if voice:
            cmd += ["-v", voice]
        cmd += ["-o", tmp]
        result = subprocess.run(cmd, input=text, capture_output=True, text=True, timeout=30)
        if result.returncode != 0 or not os.path.exists(tmp):
            return False
        helper = _compile_voice_play() if male else None
        if helper:
            subprocess.run([helper, tmp, str(MALE_PITCH)], timeout=60, check=False)
        else:
            subprocess.run(["afplay", tmp], timeout=60, check=False)
        return True
    except Exception:
        return False


def _stt_binary():
    return os.path.join(os.path.expanduser("~"), ".jarvis", "jarvis_stt")


def _compile_stt():
    binary = _stt_binary()
    if os.path.exists(binary) and os.path.getmtime(binary) >= os.path.getmtime(_STT_SOURCE):
        return binary
    if shutil.which("swiftc") is None or not os.path.exists(_STT_SOURCE):
        return None
    try:
        os.makedirs(os.path.dirname(binary), exist_ok=True)
        cache_dir = os.path.join(os.path.dirname(binary), "clang-cache")
        os.makedirs(cache_dir, exist_ok=True)
        env = dict(os.environ, CLANG_MODULE_CACHE_PATH=cache_dir)
        tmp = binary + ".tmp"
        cmd = [
            "swiftc", "-O", _STT_SOURCE, "-o", tmp,
            "-Xlinker", "-sectcreate", "-Xlinker", "__TEXT",
            "-Xlinker", "__info_plist", "-Xlinker", _STT_PLIST,
        ]
        result = subprocess.run(cmd, capture_output=True, text=True, env=env)
        if result.returncode != 0:
            return None
        os.replace(tmp, binary)
        return binary
    except Exception:
        return None


def listen(timeout=6):
    """语音输入：识别成功返回文本，失败返回 None。"""
    binary = _compile_stt()
    if not binary:
        return None
    for attempt in range(2):
        try:
            result = subprocess.run(
                [binary, "-t", str(timeout)],
                capture_output=True,
                text=True,
                timeout=timeout + 20,
            )
        except subprocess.TimeoutExpired:
            return None
        if result.returncode == 0:
            return result.stdout.strip() or None
        if attempt == 0:
            time.sleep(1.0)
    return None


def _normalize(text):
    if not text:
        return ""
    text = text.lower()
    for ch in "，。！？,.!?、 '’":
        text = text.replace(ch, "")
    return text


def listen_for_wake(timeout=WAKE_TIMEOUT):
    """待机监听唤醒词：听到「Hey Jarvis」返回 True，超时/失败返回 False。"""
    binary = _compile_stt()
    if not binary:
        return False
    try:
        proc = subprocess.Popen(
            [binary, "--wake", "-t", str(timeout)],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
        )
    except Exception:
        return False
    try:
        for line in proc.stdout:
            text = _normalize(line)
            if any(phrase in text for phrase in WAKE_PHRASES):
                proc.terminate()
                try:
                    proc.wait(timeout=3)
                except Exception:
                    proc.kill()
                time.sleep(1.0)
                return True
        return False
    except Exception:
        try:
            proc.kill()
        except Exception:
            pass
        return False
