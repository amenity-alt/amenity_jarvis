"""OpenAI 兼容的对话接口客户端（默认对接 DeepSeek，标准库实现）。"""

import json
import urllib.error
import urllib.request

DEFAULT_TIMEOUT = 60


class LLMError(Exception):
    pass


def chat(api_key, base_url, model, messages, tools=None, timeout=DEFAULT_TIMEOUT):
    if not api_key:
        raise LLMError(
            "未配置 DEEPSEEK_API_KEY。请复制 .env.example 为 .env 并填入 API Key "
            "（申请地址 https://platform.deepseek.com）。"
        )
    url = base_url + "/chat/completions"
    payload = {"model": model, "messages": messages, "temperature": 0.7}
    if tools:
        payload["tools"] = tools
        payload["tool_choice"] = "auto"
    payload = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=payload, method="POST")
    req.add_header("Content-Type", "application/json")
    req.add_header("Authorization", "Bearer " + api_key)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        raise LLMError("API 返回错误 %s: %s" % (exc.code, body[:300]))
    except urllib.error.URLError as exc:
        raise LLMError("网络错误: %s" % exc.reason)
    try:
        return data["choices"][0]["message"]
    except (KeyError, IndexError):
        raise LLMError("API 响应格式异常: %s" % str(data)[:300])


def chat_stream(api_key, base_url, model, messages, tools=None, timeout=DEFAULT_TIMEOUT):
    """流式对话：逐段 yield 文本增量 (delta, None)；结束时 yield (None, 完整 message)。
    完整 message 含 tool_calls 时按 OpenAI 兼容格式累积。"""
    if not api_key:
        raise LLMError(
            "未配置 DEEPSEEK_API_KEY。请复制 .env.example 为 .env 并填入 API Key "
            "（申请地址 https://platform.deepseek.com）。"
        )
    url = base_url + "/chat/completions"
    payload = {"model": model, "messages": messages, "temperature": 0.7, "stream": True}
    if tools:
        payload["tools"] = tools
        payload["tool_choice"] = "auto"
    req = urllib.request.Request(url, data=json.dumps(payload).encode("utf-8"), method="POST")
    req.add_header("Content-Type", "application/json")
    req.add_header("Authorization", "Bearer " + api_key)
    try:
        resp = urllib.request.urlopen(req, timeout=timeout)
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        raise LLMError("API 返回错误 %s: %s" % (exc.code, body[:300]))
    except urllib.error.URLError as exc:
        raise LLMError("网络错误: %s" % exc.reason)

    content_parts = []
    tool_slots = {}
    try:
        for raw in resp:
            line = raw.decode("utf-8", errors="replace").strip()
            if not line.startswith("data:"):
                continue
            data = line[5:].strip()
            if data == "[DONE]":
                break
            try:
                obj = json.loads(data)
                delta = obj["choices"][0].get("delta", {}) or {}
            except (KeyError, IndexError, json.JSONDecodeError):
                continue
            content = delta.get("content")
            if content:
                content_parts.append(content)
                yield content, None
            for call in delta.get("tool_calls") or []:
                idx = call.get("index", 0)
                slot = tool_slots.setdefault(
                    idx, {"id": "", "type": "function", "function": {"name": "", "arguments": ""}}
                )
                if call.get("id"):
                    slot["id"] = call["id"]
                fn = call.get("function") or {}
                if fn.get("name"):
                    slot["function"]["name"] += fn["name"]
                if fn.get("arguments"):
                    slot["function"]["arguments"] += fn["arguments"]
    except Exception as exc:
        raise LLMError("流式读取失败: %s" % exc)

    message = {"content": "".join(content_parts) or None}
    if tool_slots:
        message["tool_calls"] = list(tool_slots.values())
    yield None, message
