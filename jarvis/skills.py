"""Jarvis 本地技能：不经过 AI 即可执行的命令。"""

import datetime
import os
import subprocess
import urllib.parse
import urllib.request

from .voice import APP_ALIASES

NOTES_FILE = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "notes.md"
)


def _run(cmd):
    return subprocess.run(cmd, capture_output=True, text=True)


def skill_time(_query):
    return "现在是 %s。" % datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")


def skill_date(_query):
    weekdays = ["一", "二", "三", "四", "五", "六", "日"]
    now = datetime.datetime.now()
    return "今天是 %s，星期%s。" % (now.strftime("%Y-%m-%d"), weekdays[now.weekday()])


def skill_open(query):
    app = query.strip()
    if not app:
        return "请告诉我要打开哪个应用，比如：打开 计算器"
    app = APP_ALIASES.get(app, app)
    result = _run(["open", "-a", app])
    if result.returncode != 0:
        return "打不开「%s」：%s" % (app, result.stderr.strip() or "未找到该应用")
    return "已打开 %s。" % app


def skill_search(query):
    q = query.strip()
    if not q:
        return "请告诉我搜索内容，比如：搜索 苹果发布会"
    url = "https://www.bing.com/search?q=" + urllib.parse.quote(q)
    _run(["open", url])
    return "已用浏览器打开搜索结果：%s" % q


def skill_weather(query):
    city = query.strip() or "上海"
    try:
        url = "https://wttr.in/" + urllib.parse.quote(city) + "?format=3&lang=zh"
        with urllib.request.urlopen(url, timeout=15) as resp:
            text = resp.read().decode("utf-8").strip()
        return text
    except Exception as exc:
        return "查询天气失败：%s" % exc


def skill_note(query):
    text = query.strip()
    if not text:
        return "请告诉我要记录什么，比如：记录 明天 9 点开会"
    with open(NOTES_FILE, "a", encoding="utf-8") as fh:
        fh.write(datetime.datetime.now().strftime("[%Y-%m-%d %H:%M] ") + text + "\n")
    return "已记到笔记里（%s）。" % os.path.basename(NOTES_FILE)


def skill_help(_query):
    return "\n".join(
        [
            "我能做这些事：",
            "  时间 / 日期          报出当前时间和日期",
            "  打开 <应用>          打开 Mac 应用（如：打开 备忘录）",
            "  搜索 <内容>          用浏览器搜索",
            "  天气 <城市>          查询天气（默认上海）",
            "  记录 <内容>          把内容追加到 notes.md",
            "  帮助                 显示本帮助",
            "  退出                  结束对话",
            "其他问题我会调用 AI 来回答。",
        ]
    )


SKILLS = [
    ("时间", skill_time),
    ("日期", skill_date),
    ("打开", skill_open),
    ("搜索", skill_search),
    ("天气", skill_weather),
    ("记录", skill_note),
    ("帮助", skill_help),
    ("help", skill_help),
]


def try_skill(user_input):
    text = user_input.strip()
    lowered = text.lower()
    if lowered in ("exit", "quit", "退出", "再见") or lowered.startswith(("/exit", "/quit")):
        return ("exit", None)
    for name, fn in SKILLS:
        if text == name or text.startswith(name) and text[len(name)] in " ：:，,、":
            return ("ok", fn(text[len(name):].lstrip(" ：:，,、")))
    return (None, None)
