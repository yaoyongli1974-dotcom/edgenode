#!/bin/sh
#
# EdgeNode 回归测试（脚本级，不依赖 OpenWrt 硬件）
#
# 用法： sh tests/run-tests.sh
#
# 覆盖范围：
#   - Agent 输出的 JSON 合法性、字符串转义、数值兜底
#   - ZeroTier 网络名含空格时不丢数据（0.1.3 的回归缺陷）
#   - ZeroTier CLI 不存在时不报错、输出空数组
#   - CGI 认证（401）、方法限制（405 + Allow 头）、路由（404）、内部错误（500 且不泄露细节）
#   - CGI 响应 Content-Length 与实际字节数一致
#   - HEAD 与 GET 同流程：状态码/响应头一致、Content-Length 等于 GET 的 body 字节数、无 body

set -u

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
AGENT="$ROOT/agent/edgenode-agent"
API="$ROOT/api/cgi-bin/api"

# 被测脚本的解释器。默认 sh；可用 EN_SH=dash 或 EN_SH="busybox ash"
# 验证跨 shell 兼容性（echo/printf、read 字段切分等行为差异）。
SH_CMD="${EN_SH:-sh}"

PASS=0
FAIL=0

ok() {
    PASS=$((PASS + 1))
    printf 'PASS  %s\n' "$1"
}

no() {
    FAIL=$((FAIL + 1))
    printf 'FAIL  %s\n' "$1"
    if [ $# -gt 1 ]; then
        printf '      %s\n' "$2"
    fi
}

if ! command -v python3 >/dev/null 2>&1; then
    printf '需要 python3 用于 JSON 校验，已跳过。\n'
    exit 2
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# 优先使用真实 jsonfilter（OpenWrt 环境）；非 OpenWrt 环境退回等价实现。
if command -v jsonfilter >/dev/null 2>&1; then
    JSONFILTER=$(command -v jsonfilter)
else
    chmod +x "$ROOT/tests/fixtures/jsonfilter_stub.py"
    JSONFILTER="$ROOT/tests/fixtures/jsonfilter_stub.py"
fi

# ---------------------------------------------------------------- 测试夹具

printf 'DISTRIB_RELEASE="OpenWrt 25.12.6"\nDISTRIB_ARCH="mipsel_24kc"\n' > "$TMP/release"
printf '12345678-1234-4000-8000-123456789abc\n' > "$TMP/device-id"
printf 'Evil "Gateway" \\ Model\n' > "$TMP/model"

cat > "$TMP/zt.txt" <<'EOF'
200 listnetworks <nwid> <name> <mac> <status> <type> <dev> <ips>
200 listnetworks 8056c2e21c000001 My Home Network aa:bb:cc:dd:ee:ff OK PRIVATE ztabcde 10.0.0.5/24
200 listnetworks 8056c2e21c000002 flatname aa:bb:cc:dd:ee:00 OK PUBLIC ztabcdf 10.1.0.5/24,fd00::5/64
200 listnetworks 8056c2e21c000003 aa:bb:cc:dd:ee:02 NOT_FOUND PRIVATE ztabcdh
EOF

cat > "$TMP/zt-cli.sh" <<EOF
#!/bin/sh
case "\$1" in
    listnetworks) cat "$TMP/zt.txt" ;;
esac
EOF
chmod +x "$TMP/zt-cli.sh"

cat > "$TMP/agent-wrapper" <<EOF
#!/bin/sh
exec sh "$AGENT"
EOF
chmod +x "$TMP/agent-wrapper"

printf 'unit-test-token-0123456789\n' > "$TMP/api.token"

# ---------------------------------------------------------------- 工具函数

json_get() {
    # $1 = 点分路径；空字符串表示整个文档，例如 network.zerotier.0.name
    python3 -c '
import json, sys
d = json.load(sys.stdin)
path = sys.argv[1]
if path:
    for k in path.split("."):
        d = d[int(k)] if k.isdigit() else d[k]
sys.stdout.write(str(d))
' "$1"
}

json_len() {
    # $1 = 点分路径；空字符串表示整个文档（用于接口直接返回数组的情况）
    python3 -c '
import json, sys
d = json.load(sys.stdin)
path = sys.argv[1]
if path:
    for k in path.split("."):
        d = d[int(k)] if k.isdigit() else d[k]
sys.stdout.write(str(len(d)))
' "$1"
}

json_ok() {
    python3 -c 'import json,sys; json.load(sys.stdin)' >/dev/null 2>&1
}

run_agent() {
    # $1=release 文件 $2=device-id 文件 $3=model 文件 $4=ZT CLI 路径或 none
    EN_OPENWRT_RELEASE="$1" \
    EN_DEVICE_ID_FILE="$2" \
    EN_SYSINFO_MODEL="$3" \
    EN_ZT_CLI="$4" \
    ${SH_CMD} "$AGENT"
}

run_api() {
    # $1=方法 $2=Authorization 头 $3=PATH_INFO $4=token 文件 $5=agent 路径
    REQUEST_METHOD="$1" \
    HTTP_AUTHORIZATION="$2" \
    PATH_INFO="$3" \
    EN_TOKEN_FILE="$4" \
    EN_AGENT="$5" \
    EN_JSONFILTER="$JSONFILTER" \
    EN_OPENWRT_RELEASE="$TMP/release" \
    EN_DEVICE_ID_FILE="$TMP/device-id" \
    EN_SYSINFO_MODEL="$TMP/model" \
    EN_ZT_CLI="$TMP/zt-cli.sh" \
    ${SH_CMD} "$API"
}

header_value() {
    # $1 = 响应头名（大小写不敏感）；取最近一次 api_call 拆出的头字段值
    awk -F': ' -v name="$1" 'tolower($1) == tolower(name) {print $2; exit}' "$TMP/hdr"
}

api_call() {
    # 结果写入 CODE / HDR_LEN / BODY_BYTES / BODY
    run_api "$@" > "$TMP/raw" 2> "$TMP/log"

    python3 "$ROOT/tests/cgi_split.py" < "$TMP/raw" > "$TMP/hdr" 2> "$TMP/body"

    CODE=$(awk 'NR==1 {print $2}' "$TMP/hdr")
    HDR_LEN=$(header_value Content-Length)
    BODY_BYTES=$(wc -c < "$TMP/body" | tr -d ' ')
    BODY=$(cat "$TMP/body")
}

expect_code() {
    if [ "$CODE" = "$1" ]; then
        ok "$2"
    else
        no "$2" "期望 HTTP $1，实际 HTTP $CODE"
    fi
}

# ---------------------------------------------------------------- Agent 测试

OUT=$(run_agent "$TMP/release" "$TMP/device-id" "$TMP/model" none)

if printf '%s' "$OUT" | json_ok; then
    ok "agent 输出是合法 JSON"
else
    no "agent 输出是合法 JSON" "json.load 失败"
fi

if [ "$(printf '%s' "$OUT" | json_get agent.version)" = "0.1.4" ]; then
    ok "agent 上报版本 0.1.4"
else
    no "agent 上报版本 0.1.4" "实际: $(printf '%s' "$OUT" | json_get agent.version)"
fi

if [ "$(printf '%s' "$OUT" | json_get device.model)" = 'Evil "Gateway" \ Model' ]; then
    ok "含引号与反斜杠的型号字符串往返无损"
else
    no "含引号与反斜杠的型号字符串往返无损" \
       "实际: $(printf '%s' "$OUT" | json_get device.model)"
fi

if [ "$(printf '%s' "$OUT" | json_get device.device_id)" = "12345678-1234-4000-8000-123456789abc" ]; then
    ok "读取持久化设备标识"
else
    no "读取持久化设备标识"
fi

if [ "$(printf '%s' "$OUT" | json_get device.architecture)" = "mipsel_24kc" ]; then
    ok "从 openwrt_release 读取架构"
else
    no "从 openwrt_release 读取架构"
fi

# device-id 缺失
OUT=$(run_agent "$TMP/release" "$TMP/no-such-id" "$TMP/model" none)
if printf '%s' "$OUT" | json_ok && [ "$(printf '%s' "$OUT" | json_get device.device_id)" = "" ]; then
    ok "设备标识缺失时输出空字符串且 JSON 合法"
else
    no "设备标识缺失时输出空字符串且 JSON 合法"
fi

# openwrt_release 缺失（模拟非 OpenWrt 环境）
OUT=$(run_agent "$TMP/no-such-release" "$TMP/device-id" "$TMP/model" none)
if printf '%s' "$OUT" | json_ok; then
    ARCH=$(printf '%s' "$OUT" | json_get device.architecture)
    if [ -n "$ARCH" ]; then
        ok "缺少 openwrt_release 时回退到 uname -m ($ARCH)"
    else
        no "缺少 openwrt_release 时回退到 uname -m" "架构为空"
    fi
else
    no "缺少 openwrt_release 时 JSON 仍合法"
fi

# ZeroTier：不可用
OUT=$(run_agent "$TMP/release" "$TMP/device-id" "$TMP/model" none)
if [ "$(printf '%s' "$OUT" | json_len network.zerotier)" = "0" ]; then
    ok "无 ZeroTier CLI 时输出空数组"
else
    no "无 ZeroTier CLI 时输出空数组"
fi

# ZeroTier：真实输出（含带空格的网络名）—— 0.1.3 回归点
OUT=$(run_agent "$TMP/release" "$TMP/device-id" "$TMP/model" "$TMP/zt-cli.sh")
if printf '%s' "$OUT" | json_ok; then
    ok "ZeroTier 数据不破坏 JSON 合法性"
else
    no "ZeroTier 数据不破坏 JSON 合法性"
fi

if [ "$(printf '%s' "$OUT" | json_len network.zerotier)" = "3" ]; then
    ok "ZeroTier 三条网络全部解析（含带空格名称）"
else
    no "ZeroTier 三条网络全部解析（含带空格名称）" \
       "实际条数: $(printf '%s' "$OUT" | json_len network.zerotier)"
fi

if [ "$(printf '%s' "$OUT" | json_get network.zerotier.0.name)" = "My Home Network" ]; then
    ok "带空格的网络名完整保留"
else
    no "带空格的网络名完整保留" \
       "实际: $(printf '%s' "$OUT" | json_get network.zerotier.0.name)"
fi

if [ "$(printf '%s' "$OUT" | json_get network.zerotier.1.ips)" = "10.1.0.5/24,fd00::5/64" ]; then
    ok "多地址字段完整保留"
else
    no "多地址字段完整保留" \
       "实际: $(printf '%s' "$OUT" | json_get network.zerotier.1.ips)"
fi

if [ "$(printf '%s' "$OUT" | json_get network.zerotier.2.status)" = "NOT_FOUND" ]; then
    ok "NOT_FOUND 网络被正确记录"
else
    no "NOT_FOUND 网络被正确记录"
fi

# ---------------------------------------------------------------- API 测试

api_call GET "" "" "$TMP/api.token" "$TMP/agent-wrapper"
expect_code 401 "缺少 Authorization 头返回 401"

api_call GET "Bearer wrong-token" "" "$TMP/api.token" "$TMP/agent-wrapper"
expect_code 401 "错误 Token 返回 401"

api_call GET "Basic dXNlcjpwYXNz" "" "$TMP/api.token" "$TMP/agent-wrapper"
expect_code 401 "非 Bearer 认证scheme 返回 401"

api_call POST "Bearer unit-test-token-0123456789" "" "$TMP/api.token" "$TMP/agent-wrapper"
expect_code 405 "POST 方法返回 405（即使 Token 正确）"

ALLOW=$(header_value Allow)
if printf '%s\n' "$ALLOW" | grep -q GET && printf '%s\n' "$ALLOW" | grep -q HEAD; then
    ok "405 响应带 Allow 头并同时列出 GET 与 HEAD ($ALLOW)"
else
    no "405 响应带 Allow 头并同时列出 GET 与 HEAD" "实际 Allow: '$ALLOW'"
fi

api_call GET "Bearer unit-test-token-0123456789" "/v1/nope" "$TMP/api.token" "$TMP/agent-wrapper"
expect_code 404 "未知路由返回 404"

api_call GET "Bearer unit-test-token-0123456789" "/v1/status" "$TMP/api.token" "$TMP/agent-wrapper"
expect_code 200 "/v1/status 返回 200"

if printf '%s' "$BODY" | json_ok; then
    ok "200 响应体是合法 JSON"
else
    no "200 响应体是合法 JSON"
fi

if [ "$HDR_LEN" = "$BODY_BYTES" ]; then
    ok "Content-Length 与实际字节数一致 ($HDR_LEN)"
else
    no "Content-Length 与实际字节数一致" \
       "头: $HDR_LEN 实际: $BODY_BYTES"
fi

api_call GET "Bearer unit-test-token-0123456789" "" "$TMP/api.token" "$TMP/agent-wrapper"
expect_code 200 "根路径映射为完整状态"

api_call GET "Bearer unit-test-token-0123456789" "/v1/device" "$TMP/api.token" "$TMP/agent-wrapper"
expect_code 200 "/v1/device 返回 200"
if [ "$(printf '%s' "$BODY" | json_get model)" = 'Evil "Gateway" \ Model' ]; then
    ok "/v1/device 经 jsonfilter 投影后转义仍然正确"
else
    no "/v1/device 经 jsonfilter 投影后转义仍然正确" \
       "实际: $(printf '%s' "$BODY" | json_get model)"
fi

api_call GET "Bearer unit-test-token-0123456789" "/v1/zerotier" "$TMP/api.token" "$TMP/agent-wrapper"
expect_code 200 "/v1/zerotier 返回 200"
if [ "$(printf '%s' "$BODY" | json_len "")" = "3" ]; then
    ok "/v1/zerotier 返回三条记录"
else
    no "/v1/zerotier 返回三条记录"
fi

# 500：Token 文件缺失。不得向客户端泄露具体原因
api_call GET "Bearer unit-test-token-0123456789" "/v1/status" "$TMP/no-such-token" "$TMP/agent-wrapper"
expect_code 500 "Token 文件缺失返回 500"
MISSING_TOKEN_BODY="$BODY"

if [ "$BODY" = '{"error":"internal_error"}' ]; then
    ok "500 响应使用统一错误文案"
else
    no "500 响应使用统一错误文案" "实际: $BODY"
fi

# 500：Agent 不可执行，响应体必须与上一个 500 完全一致
api_call GET "Bearer unit-test-token-0123456789" "/v1/status" "$TMP/api.token" "$TMP/no-such-agent"
expect_code 500 "Agent 不可执行返回 500"

if [ "$BODY" = "$MISSING_TOKEN_BODY" ]; then
    ok "两种内部错误对外响应无法区分"
else
    no "两种内部错误对外响应无法区分" \
       "token缺失: $MISSING_TOKEN_BODY / agent缺失: $BODY"
fi

if [ -s "$TMP/log" ]; then
    ok "内部错误细节写入服务端日志"
else
    no "内部错误细节写入服务端日志"
fi

# ---------------------------------------------------------------- HEAD 测试

# HEAD 与 GET 的 Content-Length 必须逐字节相等，而真实 Agent 的内存/负载读数
# 在两次调用之间可能变化，故先冻结一份 Agent 输出快照作为确定性夹具。
run_agent "$TMP/release" "$TMP/device-id" "$TMP/model" "$TMP/zt-cli.sh" > "$TMP/agent-snapshot.json"

cat > "$TMP/agent-frozen" <<EOF
#!/bin/sh
cat "$TMP/agent-snapshot.json"
EOF
chmod +x "$TMP/agent-frozen"

# 基准：同一夹具下的 GET /v1/status
api_call GET "Bearer unit-test-token-0123456789" "/v1/status" "$TMP/api.token" "$TMP/agent-frozen"
GET_BODY_BYTES="$BODY_BYTES"
cp "$TMP/hdr" "$TMP/hdr-get"

api_call HEAD "Bearer unit-test-token-0123456789" "/v1/status" "$TMP/api.token" "$TMP/agent-frozen"
expect_code 200 "HEAD /v1/status 返回 200"

if [ "$BODY_BYTES" = "0" ]; then
    ok "HEAD 响应不输出 body"
else
    no "HEAD 响应不输出 body" "实际字节数: $BODY_BYTES"
fi

if [ "$HDR_LEN" = "$GET_BODY_BYTES" ]; then
    ok "HEAD 的 Content-Length 等于 GET 的 body 字节数 ($HDR_LEN)"
else
    no "HEAD 的 Content-Length 等于 GET 的 body 字节数" \
       "HEAD 头: $HDR_LEN / GET body: $GET_BODY_BYTES"
fi

if cmp -s "$TMP/hdr" "$TMP/hdr-get"; then
    ok "HEAD 与 GET 的响应头完全一致"
else
    no "HEAD 与 GET 的响应头完全一致" \
       "GET: $(tr '\n' '|' < "$TMP/hdr-get") / HEAD: $(tr '\n' '|' < "$TMP/hdr")"
fi

api_call HEAD "" "/v1/status" "$TMP/api.token" "$TMP/agent-frozen"
expect_code 401 "HEAD 缺少 Authorization 头返回 401"

if [ "$BODY_BYTES" = "0" ]; then
    ok "HEAD 401 响应同样不输出 body"
else
    no "HEAD 401 响应同样不输出 body" "实际字节数: $BODY_BYTES"
fi

# ---------------------------------------------------------------- 汇总

printf '\n%s 通过, %s 失败\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
