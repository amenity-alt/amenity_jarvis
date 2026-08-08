"""Jarvis 联网工具：天气查询 + 网页搜索。全部使用免费无 Key 接口，标准库实现。"""

import json
import re
import urllib.parse
import urllib.request
from html.parser import HTMLParser

TIMEOUT = 15
HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
        "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36"
    )
}


def _fetch(url):
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
        return resp.read().decode("utf-8", errors="replace")


def get_weather(city=None):
    """查询实时天气；city 为空时按 IP 自动定位。"""
    suffix = urllib.parse.quote(city) if city else ""
    url = "https://wttr.in/%s?format=j1&lang=zh" % suffix
    data = json.loads(_fetch(url))
    cur = data["current_condition"][0]
    area = data.get("nearest_area", [{}])[0]
    area_name = area.get("areaName", [{}])[0].get("value", city or "当前位置")
    desc = cur.get("weatherDesc", [{}])[0].get("value", "未知")
    temp = cur.get("temp_C", "?")
    feels = cur.get("FeelsLikeC", "?")
    humidity = cur.get("humidity", "?")
    wind_dir = cur.get("winddir16Point", "")
    wind = cur.get("windspeedKmph", "?")
    return "%s：%s，气温 %s°C（体感 %s°C），湿度 %s%%，风 %s %skm/h" % (
        area_name, desc, temp, feels, humidity, wind_dir, wind
    )


class _SearchParser(HTMLParser):
    """解析 DuckDuckGo Lite 结果页：标题、链接、摘要。"""

    def __init__(self):
        super().__init__()
        self.results = []
        self._anchor = None
        self._in_snippet = False
        self._snippet = []

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "a" and "nofollow" in attrs.get("rel", "").split():
            self._anchor = {"title": [], "href": attrs.get("href", "")}
        elif tag == "td" and "result-snippet" in attrs.get("class", "").split():
            self._in_snippet = True
            self._snippet = []

    def handle_endtag(self, tag):
        if tag == "a" and self._anchor is not None:
            title = "".join(self._anchor["title"]).strip()
            href = self._anchor["href"]
            if title and href:
                self.results.append({"title": title, "href": href, "snippet": ""})
            self._anchor = None
        elif tag == "td" and self._in_snippet:
            if self.results:
                self.results[-1]["snippet"] = "".join(self._snippet).strip()
            self._in_snippet = False

    def handle_data(self, data):
        if self._anchor is not None:
            self._anchor["title"].append(data)
        elif self._in_snippet:
            self._snippet.append(data)


def _real_url(href):
    if "uddg=" in href:
        match = re.search(r"[?&]uddg=([^&]+)", href)
        if match:
            return urllib.parse.unquote(match.group(1))
    if href.startswith("//"):
        return "https:" + href
    return href


def web_search(query, max_results=5):
    """联网搜索，返回前 max_results 条结果的标题、链接和摘要。"""
    url = "https://lite.duckduckgo.com/lite/?q=" + urllib.parse.quote(query)
    html = _fetch(url)
    parser = _SearchParser()
    parser.feed(html)
    lines = []
    for index, item in enumerate(parser.results[:max_results], 1):
        lines.append(
            "%d. %s\n   %s\n   %s" % (index, item["title"], _real_url(item["href"]), item["snippet"])
        )
    if not lines:
        return "没有搜索到结果。"
    return "\n".join(lines)


TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "get_weather",
            "description": "查询实时天气和气温。城市留空时按 IP 自动定位。",
            "parameters": {
                "type": "object",
                "properties": {
                    "city": {"type": "string", "description": "城市名，如 北京、上海；不确定可留空"}
                },
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "web_search",
            "description": "联网搜索最新信息，返回网页标题、链接和摘要。适合需要实时信息或你不确定答案的问题。",
            "parameters": {
                "type": "object",
                "properties": {"query": {"type": "string", "description": "搜索关键词"}},
                "required": ["query"],
            },
        },
    },
]

TOOL_RUNNERS = {
    "get_weather": get_weather,
    "web_search": web_search,
}


def run_tool(name, arguments):
    """执行工具，返回给模型的文本结果。"""
    if isinstance(arguments, str):
        try:
            arguments = json.loads(arguments) if arguments.strip() else {}
        except json.JSONDecodeError:
            arguments = {}
    fn = TOOL_RUNNERS.get(name)
    if not fn:
        return "未知工具：%s" % name
    try:
        return str(fn(**arguments))
    except Exception as exc:
        return "工具执行失败：%s" % exc
