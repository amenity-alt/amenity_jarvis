"""Jarvis 音效：程序生成的科幻提示音（wake / listen / speak / confirm），afplay 播放。"""

import math
import os
import shutil
import struct
import subprocess
import wave

_SFX_DIR = os.path.join(os.path.expanduser("~"), ".jarvis", "sfx")
_RATE = 44100


def _sweep(f0, f1, dur, vol=0.5):
    """频率滑音：f0 → f1，带淡入淡出包络。"""
    n = int(_RATE * dur)
    samples = []
    phase = 0.0
    for i in range(n):
        t = i / n
        freq = f0 + (f1 - f0) * (t ** 1.5)
        phase += 2 * math.pi * freq / _RATE
        env = math.sin(math.pi * t) ** 1.4
        samples.append(vol * env * math.sin(phase))
    return samples


def _blip(freq, dur, vol=0.45):
    """短促音。"""
    n = int(_RATE * dur)
    return [
        vol * (math.sin(math.pi * i / n) ** 2) * math.sin(2 * math.pi * freq * i / _RATE)
        for i in range(n)
    ]


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
    wake = _mix(_sweep(300, 1400, 0.9, 0.5), _sweep(300, 1400, 0.9, 0.25), 0.12)
    listen = _mix(_blip(880, 0.12, 0.4), _blip(1320, 0.16, 0.4), 0.09)
    speak = _sweep(1000, 280, 0.7, 0.4)
    confirm = _mix(_blip(523, 0.12, 0.4), _blip(784, 0.22, 0.4), 0.06)
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
    marker = os.path.join(_SFX_DIR, ".v2")
    if os.path.exists(marker):
        return
    for name, samples in _build().items():
        _write_wav(os.path.join(_SFX_DIR, name + ".wav"), samples)
    open(marker, "w").close()


def play(name, volume=0.6):
    ensure()
    path = os.path.join(_SFX_DIR, name + ".wav")
    if not os.path.exists(path) or shutil.which("afplay") is None:
        return
    try:
        subprocess.Popen(
            ["afplay", "-v", str(volume), path],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except Exception:
        pass
