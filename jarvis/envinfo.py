"""Jarvis 环境信息采集：时间、天气、电量、负载、内存、网络（用于左下角面板）。"""

import datetime
import os
import re
import socket
import subprocess
import time

_WEATHER_CACHE = {"at": 0.0, "text": "天气获取中…"}
_WEATHER_TTL = 1800
_NET_CACHE = {"at": 0.0, "text": "网络检测中…"}
_NET_TTL = 15

# 趋势历史（面板图表用，各保留 40 个采样点）
_LOAD_HIST = []
_MEM_HIST = []
_BATT_HIST = []
_NET_HIST = []
LATENCY_HIST = []


def _run(cmd):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=8).stdout.strip()
    except Exception:
        return ""


def weather():
    now = time.time()
    if now - _WEATHER_CACHE["at"] < _WEATHER_TTL:
        return _WEATHER_CACHE["text"]
    try:
        from .tools import get_weather
        text = get_weather()
    except Exception:
        text = "天气获取失败"
    _WEATHER_CACHE.update(at=now, text=text)
    return text


def battery():
    out = _run(["pmset", "-g", "batt"])
    match = re.search(r"(\d+)%", out)
    if not match:
        return "电量 未知"
    if "charged" in out:
        status = "已充满"
    elif "AC attached" in out or "charging" in out:
        status = "充电中"
    else:
        status = "使用电池"
    return "电量 %s%% %s" % (match.group(1), status)


def loadavg():
    out = _run(["sysctl", "-n", "vm.loadavg"])
    parts = out.replace("{", "").replace("}", "").split()
    if len(parts) >= 3:
        return "负载 %s %s %s" % tuple(parts[:3])
    return "负载 未知"


def memory():
    total = _run(["sysctl", "-n", "hw.memsize"]).strip()
    if not total.isdigit():
        return "内存 未知"
    total_gb = int(total) / 1024 ** 3
    out = _run(["vm_stat"])
    page = 4096
    page_match = re.search(r"page size of (\d+) bytes", out)
    if page_match:
        page = int(page_match.group(1))

    def pages(key):
        m = re.search(r"%s:\s+(\d+)" % key, out)
        return int(m.group(1)) if m else 0

    used_gb = (pages("Pages active") + pages("Pages wired down")) * page / 1024 ** 3
    return "内存 %.1fG / %.0fG" % (used_gb, total_gb)


def disk():
    out = _run(["df", "-k", "/"])
    lines = out.splitlines()
    if len(lines) >= 2:
        parts = lines[1].split()
        if len(parts) >= 4:
            used = int(parts[2]) / 1024 ** 2
            total = int(parts[1]) / 1024 ** 2
            return "磁盘 %.0fG / %.0fG" % (used, total)
    return "磁盘 未知"


def ip():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return "IP " + ip
    except Exception:
        return "IP 未知"


def uptime():
    out = _run(["sysctl", "-n", "kern.boottime"])
    match = re.search(r"sec = (\d+)", out)
    if match:
        secs = int(time.time()) - int(match.group(1))
        days, rem = divmod(secs, 86400)
        hours, rem = divmod(rem, 3600)
        minutes = rem // 60
        return "运行 %d天%d小时%d分" % (days, hours, minutes)
    return "运行 未知"


def kernel():
    ver = _run(["sw_vers", "-productVersion"])
    return "系统 macOS " + ver if ver else "系统 未知"


def processes():
    count = _run(["ps", "-A", "-o", "pid="]).count("\n")
    return "进程 %d" % count


def network():
    now = time.time()
    if now - _NET_CACHE["at"] < _NET_TTL:
        return _NET_CACHE["text"]
    out = _run(["ping", "-c", "1", "-W", "800", "223.5.5.5"])
    if "1 packets transmitted" in out and "1 packets received" in out:
        match = re.search(r"time=([\d.]+) ms", out)
        ms = match.group(1) if match else "?"
        text = "网络 在线 %sms" % ms
    elif out:
        text = "网络 离线"
    else:
        text = "网络 检测中"
    _NET_CACHE.update(at=now, text=text)
    return text


def collect():
    now = datetime.datetime.now()
    load_txt = loadavg()
    mem_txt = memory()
    disk_txt = disk()
    batt_txt = battery()
    net_txt = network()

    def first_num(pattern, text, default=0.0):
        m = re.search(pattern, text)
        return float(m.group(1)) if m else default

    load1 = first_num(r"负载 ([\d.]+)", load_txt)
    mem_m = re.search(r"内存 ([\d.]+)G / ([\d.]+)G", mem_txt)
    mem_pct = float(mem_m.group(1)) / float(mem_m.group(2)) * 100 if mem_m else 0.0
    disk_m = re.search(r"磁盘 ([\d.]+)G / ([\d.]+)G", disk_txt)
    disk_pct = float(disk_m.group(1)) / float(disk_m.group(2)) * 100 if disk_m else 0.0
    batt_pct = first_num(r"电量 ([\d.]+)%", batt_txt)
    net_ms = first_num(r"在线 ([\d.]+)ms", net_txt)
    cpu_count = max(1, os.cpu_count() or 4)
    load_pct = min(100.0, load1 / cpu_count * 100.0)

    _LOAD_HIST.append(load1)
    _MEM_HIST.append(mem_pct)
    _BATT_HIST.append(batt_pct)
    _NET_HIST.append(net_ms)

    def hist(values):
        return ",".join("%.1f" % v for v in values[-40:])

    return {
        "time": now.strftime("%H:%M:%S"),
        "date": now.strftime("%Y-%m-%d %A"),
        "weather": weather(),
        "battery": batt_txt,
        "load": load_txt,
        "mem": mem_txt,
        "disk": disk_txt,
        "net": net_txt,
        "ip": ip(),
        "uptime": uptime(),
        "kernel": kernel(),
        "processes": processes(),
        "batt_pct": "%.0f" % batt_pct,
        "mem_pct": "%.0f" % mem_pct,
        "disk_pct": "%.0f" % disk_pct,
        "load_pct": "%.0f" % load_pct,
        "load_hist": hist(_LOAD_HIST),
        "mem_hist": hist(_MEM_HIST),
        "batt_hist": hist(_BATT_HIST),
        "net_hist": hist(_NET_HIST),
        "latency_hist": hist(LATENCY_HIST),
    }
