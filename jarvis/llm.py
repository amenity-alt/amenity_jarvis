"""OpenAI 兼容的对话接口客户端（默认对接 DeepSeek，标准库实现）。"""

import json
import urllib.error
import urllib.request

DEFAULT_TIMEOUT = 60


class LLMError(Exception):
    pass


def chat(api_key, base_url, model, messages, timeout=DEFAULT_TIMEOUT):
    if not api_key:
        raise LLMError(
            "未配置 DEEPSEEK_API_KEY。请复制 .env.example 为 .env 并填入 API Key "
            "（申请地址 https://platform.deepseek.com）。"
        )
    url = base_url + "/chat/completions"
    payload = json.dumps(
        {"model": model, "messages": messages, "temperature": 0.7}
    ).encode("utf-8")
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
        return data["choices"][0]["message"]["content"].strip()
    except (KeyError, IndexError):
        raise LLMError("API 响应格式异常: %s" % str(data)[:300])
