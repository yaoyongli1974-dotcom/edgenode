#!/usr/bin/env python3
"""jsonfilter 的最小等价实现，仅用于在非 OpenWrt 环境运行回归测试。

支持 edgenode-api 实际使用的调用形式：
    <stdin JSON> | jsonfilter -e '@.a.b'

真实运行环境使用 OpenWrt base 自带的 jsonfilter（ubox）。
本文件不是产品代码，只保证"路径选择 + 重新序列化"这一行为可被测试覆盖。
"""

import json
import sys


def main() -> int:
    args = sys.argv[1:]
    expr = None
    i = 0
    while i < len(args):
        if args[i] == "-e" and i + 1 < len(args):
            expr = args[i + 1]
            i += 2
            continue
        i += 1

    if expr is None:
        sys.stderr.write("jsonfilter stub: missing -e expression\n")
        return 2

    if not expr.startswith("@"):
        sys.stderr.write("jsonfilter stub: only '@.path' expressions are supported\n")
        return 2

    data = json.load(sys.stdin)

    path = expr[1:].lstrip(".")
    if path:
        for key in path.split("."):
            if isinstance(data, list):
                data = data[int(key)]
            elif isinstance(data, dict):
                data = data[key]
            else:
                raise KeyError(key)

    sys.stdout.write(json.dumps(data, separators=(",", ":")) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
