"""Jarvis 配置加载：环境变量 + 仓库根目录 .env 文件。"""

import os

DEFAULT_BASE_URL = "https://api.deepseek.com"
DEFAULT_MODEL = "deepseek-chat"


def _repo_root():
    return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def _load_dotenv(path):
    if not os.path.exists(path):
        return
    with open(path, "r", encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, _, value = line.partition("=")
            key = key.strip()
            value = value.strip().strip("\"'")
            if key and key not in os.environ:
                os.environ[key] = value


def get_config():
    _load_dotenv(os.path.join(_repo_root(), ".env"))
    return {
        "api_key": os.environ.get("DEEPSEEK_API_KEY", "").strip(),
        "base_url": os.environ.get("JARVIS_API_BASE", DEFAULT_BASE_URL).strip().rstrip("/"),
        "model": os.environ.get("JARVIS_MODEL", DEFAULT_MODEL).strip(),
    }
