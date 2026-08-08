#!/usr/bin/env python3
"""Jarvis 个人 AI 助理入口。"""

import argparse

from jarvis.config import get_config
from jarvis.core import run


def main():
    parser = argparse.ArgumentParser(description="Jarvis 个人 AI 助理")
    parser.add_argument("--voice", action="store_true", help="回复时用 macOS 语音朗读")
    parser.add_argument("--wake", action="store_true", help="待机监听唤醒词「Hey Jarvis」")
    parser.add_argument("-c", "--command", help="单次执行一条指令后退出（便于测试）")
    args = parser.parse_args()

    config = get_config()
    if not config["api_key"]:
        print("提示：未配置 DEEPSEEK_API_KEY，AI 对话不可用（本地技能仍可使用）。")
    run(config, voice_mode=args.voice, command=args.command, wake=args.wake)


if __name__ == "__main__":
    main()
