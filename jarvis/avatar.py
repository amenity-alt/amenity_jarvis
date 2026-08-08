"""Jarvis 全息头像：钢铁侠风格浮动窗口（macOS Swift 实现）。"""

import os
import shutil
import subprocess

_AVATAR_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "avatar_swift")
_AVATAR_SOURCE = os.path.join(_AVATAR_DIR, "JarvisAvatar.swift")


def _binary():
    return os.path.join(os.path.expanduser("~"), ".jarvis", "jarvis_avatar")


def _compile():
    binary = _binary()
    if os.path.exists(binary) and os.path.getmtime(binary) >= os.path.getmtime(_AVATAR_SOURCE):
        return binary
    if shutil.which("swiftc") is None or not os.path.exists(_AVATAR_SOURCE):
        return None
    try:
        os.makedirs(os.path.dirname(binary), exist_ok=True)
        cache_dir = os.path.join(os.path.dirname(binary), "clang-cache")
        os.makedirs(cache_dir, exist_ok=True)
        env = dict(os.environ, CLANG_MODULE_CACHE_PATH=cache_dir)
        tmp = binary + ".tmp"
        cmd = ["swiftc", "-O", _AVATAR_SOURCE, "-o", tmp]
        result = subprocess.run(cmd, capture_output=True, text=True, env=env)
        if result.returncode != 0:
            return None
        os.replace(tmp, binary)
        return binary
    except Exception:
        return None


class Avatar:
    """控制全息头像进程：start 唤出窗口，command 切换动画状态。"""

    def __init__(self):
        self._proc = None

    @property
    def active(self):
        return self._proc is not None and self._proc.poll() is None

    def start(self, mode="idle"):
        if self.active:
            self.command(mode)
            return
        binary = _compile()
        if not binary:
            return
        try:
            self._proc = subprocess.Popen(
                [binary, "--mode", mode],
                stdin=subprocess.PIPE,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
        except Exception:
            self._proc = None

    def command(self, mode):
        if self.active and self._proc.stdin:
            try:
                self._proc.stdin.write((mode + "\n").encode())
                self._proc.stdin.flush()
            except Exception:
                pass

    def stop(self):
        if self.active:
            try:
                self._proc.stdin.write(b"quit\n")
                self._proc.stdin.flush()
                self._proc.wait(timeout=3)
            except Exception:
                try:
                    self._proc.kill()
                except Exception:
                    pass
        self._proc = None
