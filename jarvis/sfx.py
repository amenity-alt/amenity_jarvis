"""Jarvis 音效：程序合成的科幻提示音（wake / listen / speak / confirm），afplay 播放。"""

import math
import os
import random
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


def _noise(dur, vol=0.5, seed=7):
    """白噪声（确定性，可复现）。"""
    rnd = random.Random(seed)
    n = int(_RATE * dur)
    return [vol * (rnd.random() * 2 - 1) for _ in range(n)]


def _riser(dur, vol=0.4):
    """渐强铺垫：噪声 + 上升滑音，越来越强（紧张感）。"""
    n = int(_RATE * dur)
    noise = _noise(dur, vol * 0.5)
    sweep = _sweep(150, 1400, dur, vol * 0.5)
    return [(noise[i] + sweep[i]) * (i / n) ** 2.5 * 0.7 for i in range(n)]


def _sub_drop(dur=0.8, vol=0.6):
    """重低音下坠 90→35Hz（冲击感）。"""
    n = int(_RATE * dur)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / n
        freq = 90 - 55 * t
        phase += 2 * math.pi * freq / _RATE
        out.append(vol * math.exp(-4.5 * t) * math.sin(phase))
    return out


def _metallic_hit(vol=0.5):
    """金属撞击：高频快速衰减 + 多泛音。"""
    n = int(_RATE * 0.5)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / n
        phase += 2 * math.pi * 1100 / _RATE
        env = math.exp(-8 * t)
        out.append(vol * env * (math.sin(phase) + 0.6 * math.sin(2 * phase) + 0.3 * math.sin(3.5 * phase)))
    return out


def _brass(freq, dur, vol=0.5):
    """铜管/弦乐式长音：锯齿堆叠、慢起音、轻微颤音（史诗电影感）。"""
    n = int(_RATE * dur)
    samples = []
    phase = 0.0
    for i in range(n):
        t = i / n
        attack = min(1.0, t / 0.9)
        release = min(1.0, (1 - t) / 0.8)
        trem = 1.0 + 0.03 * math.sin(2 * math.pi * 5.2 * i / _RATE)
        env = attack * release * trem
        s = math.sin(phase) + 0.5 * math.sin(2 * phase)
        s += 0.33 * math.sin(3 * phase) + 0.2 * math.sin(4 * phase)
        samples.append(vol * env * s / 2.03)
        phase += 2 * math.pi * freq / _RATE
    return samples


def _timpani(freq=55, dur=0.6, vol=0.55):
    """定音鼓式低频敲击：音高轻微下坠。"""
    n = int(_RATE * dur)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / n
        phase += 2 * math.pi * freq * (1 - 0.25 * t) / _RATE
        out.append(vol * math.exp(-6 * t) * math.sin(phase))
    return out


def _crash(vol=0.3, seed=11):
    """镲片/撞击噪声：高频白噪声快速衰减。"""
    rnd = random.Random(seed)
    n = int(_RATE * 1.2)
    out = []
    for i in range(n):
        t = i / n
        out.append(vol * math.exp(-7 * t) * (rnd.random() * 2 - 1))
    return out


def _shimmer(vol=0.32):
    """高频闪亮琶音（科幻收尾）。"""
    notes = [1760, 2093, 2637, 3136, 3520]
    out = []
    for k, freq in enumerate(notes):
        out = _mix(out, _tone(freq, 0.9, vol, harmonics=0.7), 0.10 * k)
    return out


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
    # 启动 Intro：史诗电影开场——低频铺垫 → 定音鼓心跳 → 铜管齐鸣
    # → 大冲击 + 闪亮余韵 + 空间回响（约 8 秒）
    intro = _mix(_organ(41.2, 5.0, 0.26, harmonics=1.1), _riser(4.2, 0.34), 0.0)
    intro = _mix(intro, _timpani(55, 0.7, 0.50), 1.2)
    intro = _mix(intro, _timpani(55, 0.7, 0.50), 2.4)
    intro = _mix(intro, _brass(110.0, 3.2, 0.34), 2.6)    # A2 低音铜管
    intro = _mix(intro, _brass(164.8, 3.2, 0.30), 2.7)    # E3
    intro = _mix(intro, _brass(220.0, 3.4, 0.26), 2.8)    # A3
    intro = _mix(intro, _brass(440.0, 3.4, 0.16), 2.9)    # A4 高音弦乐
    intro = _mix(intro, _sub_drop(0.9, 0.60), 5.6)
    intro = _mix(intro, _metallic_hit(0.50), 5.6)
    intro = _mix(intro, _crash(0.26, 13), 5.6)
    intro = _mix(intro, _shimmer(0.30), 5.7)
    wake = _echo(intro, 0.32, 0.30, 5)

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
    marker = os.path.join(_SFX_DIR, ".v7")
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
