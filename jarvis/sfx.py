"""Jarvis 音效：程序合成的科幻提示音（wake / listen / speak / confirm），afplay 播放。"""

import math
import os
import shutil
import struct
import subprocess
import wave

_SFX_DIR = os.path.join(os.path.expanduser("~"), ".jarvis", "sfx")
_RATE = 44100


def _tone(freq, dur, vol=0.5, harmonics=1.0):
    """带泛音的音调，起音快、自然衰减，金属感更强。"""
    n = int(_RATE * dur)
    samples = []
    phase = 0.0
    for i in range(n):
        t = i / n
        env = math.sin(math.pi * t) ** 1.2
        s = math.sin(phase)
        s += harmonics * 0.5 * math.sin(2 * phase)
        s += harmonics * 0.25 * math.sin(3 * phase)
        samples.append(vol * env * s)
        phase += 2 * math.pi * freq / _RATE
    return samples


def _organ(freq, dur, vol=0.5, harmonics=1.0):
    """管风琴式长音：慢起音、多泛音、结尾缓慢淡出（星际穿越式）。"""
    n = int(_RATE * dur)
    samples = []
    phase = 0.0
    for i in range(n):
        t = i / n
        attack = min(1.0, t / 0.35) ** 2
        release = min(1.0, (1 - t) / 0.30)
        env = attack * release
        s = math.sin(phase)
        s += harmonics * 0.6 * math.sin(2 * phase)
        s += harmonics * 0.4 * math.sin(3 * phase)
        s += harmonics * 0.25 * math.sin(4 * phase)
        samples.append(vol * env * s)
        phase += 2 * math.pi * freq / _RATE
    return samples


def _tick(vol=0.5):
    """时钟滴答声（星际穿越的时间主题）。"""
    n = int(_RATE * 0.055)
    return [
        vol * (math.sin(math.pi * i / n) ** 4) * math.sin(2 * math.pi * 780 * i / _RATE)
        for i in range(n)
    ]


def _sweep(f0, f1, dur, vol=0.5, harmonics=1.0):
    """频率滑音（带泛音），淡入淡出。"""
    n = int(_RATE * dur)
    samples = []
    phase = 0.0
    for i in range(n):
        t = i / n
        freq = f0 + (f1 - f0) * (t ** 1.5)
        phase += 2 * math.pi * freq / _RATE
        env = math.sin(math.pi * t) ** 1.4
        s = math.sin(phase)
        s += harmonics * 0.4 * math.sin(2 * phase)
        s += harmonics * 0.2 * math.sin(3 * phase)
        samples.append(vol * env * s)
    return samples


def _echo(samples, delay=0.18, feedback=0.35, repeats=6):
    """反馈延迟：模拟广阔空间回响。"""
    pad = int(_RATE * delay)
    out = samples[:] + [0.0] * (pad * repeats + int(_RATE * 0.15))
    level = feedback
    for _ in range(1, repeats + 1):
        for i in range(len(samples)):
            out[i + pad] += samples[i] * level
        level *= feedback
    peak = max(1e-6, max(abs(s) for s in out))
    scale = min(1.0, 0.95 / peak)
    return [s * scale for s in out]


def _mix(base, extra, offset):
    """把 extra 延迟 offset 秒叠加到 base 上。"""
    pad = int(_RATE * offset)
    out = base[:]
    if len(out) < len(extra) + pad:
        out += [0.0] * (len(extra) + pad - len(out))
    for i, s in enumerate(extra):
        out[i + pad] += s
    return out


def _build():
    # 唤醒：星际穿越风格——低频管风琴长音渐起 + 时钟滴答 + 空气感（约 4.6 秒）
    dur = 4.0
    low = _organ(55.0, dur, 0.42, harmonics=1.0)     # A1 根音
    fifth = _organ(82.4, dur, 0.30, harmonics=0.8)   # E2 五度
    octave = _organ(110.0, dur, 0.20, harmonics=0.6) # A2 八度
    wake = _mix(_mix(low, fifth, 0.0), octave, 0.0)
    shimmer = _organ(220.0, dur, 0.07, harmonics=0.4)
    wake = _mix(wake, shimmer, 0.3)
    for k in range(5):
        wake = _mix(wake, _tick(0.22), 0.5 + 0.9 * k)
    wake = _echo(wake, 0.35, 0.26, 3)

    # 聆听：三连升调（660→880→1320），约 0.8 秒
    listen = _mix(_tone(660, 0.12, 0.35), _tone(880, 0.12, 0.35), 0.10)
    listen = _mix(listen, _tone(1320, 0.16, 0.35), 0.20)
    listen = _echo(listen, 0.10, 0.22, 4)

    # 说话：大幅下滑音（约 1.4 秒），空间感
    speak = _sweep(1400, 250, 0.9, 0.40)
    speak = _echo(speak, 0.18, 0.30, 5)

    # 确认：C 大调和弦长音（523/659/784），约 1.5 秒
    confirm = _mix(_tone(523, 0.5, 0.30), _tone(659, 0.5, 0.28), 0.0)
    confirm = _mix(confirm, _tone(784, 0.6, 0.26), 0.02)
    confirm = _echo(confirm, 0.22, 0.28, 4)

    return {
        "wake": wake,
        "listen": listen,
        "speak": speak,
        "confirm": confirm,
    }


def _write_wav(path, samples):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as fh:
        fh.setnchannels(1)
        fh.setsampwidth(2)
        fh.setframerate(_RATE)
        fh.writeframes(
            b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767)) for s in samples)
        )


def ensure():
    """生成缺失的音效文件（源版本变化时自动重建）。"""
    marker = os.path.join(_SFX_DIR, ".v5")
    if os.path.exists(marker):
        return
    for name, samples in _build().items():
        _write_wav(os.path.join(_SFX_DIR, name + ".wav"), samples)
    open(marker, "w").close()


def play(name, volume=0.6, wait=False):
    ensure()
    path = os.path.join(_SFX_DIR, name + ".wav")
    if not os.path.exists(path) or shutil.which("afplay") is None:
        return
    try:
        cmd = ["afplay", "-v", str(volume), path]
        if wait:
            subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        else:
            subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        pass
