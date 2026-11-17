#!/usr/bin/env python3
"""把 CGI 原始输出拆成两部分，便于 shell 断言。

stdout: 状态行与响应头（每行一条）
stderr: 响应体原始字节（不做任何解码或换行转换）
"""

import sys


def main() -> int:
    data = sys.stdin.buffer.read()

    head, sep, body = data.partition(b"\r\n\r\n")
    if not sep:
        head, sep, body = data.partition(b"\n\n")

    lines = head.replace(b"\r\n", b"\n").split(b"\n")
    out = []
    for line in lines:
        if line:
            out.append(line.decode("utf-8", "replace"))

    sys.stdout.write("\n".join(out) + ("\n" if out else ""))
    sys.stderr.buffer.write(body)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
