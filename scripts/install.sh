#!/bin/sh

# EdgeNode 安装脚本 0.1.4
# 目标平台：OpenWrt / BusyBox ash（POSIX sh，无 bashism）。
#
# 只部署 EdgeNode 自己的文件，并管理独立的 uhttpd 实例（procd）。
# 绝不修改 /etc/config/uhttpd，绝不触碰系统 uhttpd（/www，80/443）。
#
# 设备已验证布局（Cudy TR1200 v1 / OpenWrt 25.12.6）：
#   /overlay/edgenode            0700
#   /overlay/edgenode/bin/edgenode-agent      0700
#   /overlay/edgenode/etc/api.token           0600
#   /overlay/edgenode/etc/device-id           0600
#   /overlay/edgenode/www/cgi-bin/api         0755
#   /etc/init.d/edgenode-api                  0755

set -eu

PATH=/usr/sbin:/usr/bin:/sbin:/bin
export PATH

DEFAULT_PREFIX="/overlay/edgenode"
DEFAULT_LISTEN="192.168.1.1:18080"
DEFAULT_INIT_DIR="/etc/init.d"

PREFIX="$DEFAULT_PREFIX"
LISTEN="$DEFAULT_LISTEN"
INIT_DIR="$DEFAULT_INIT_DIR"
NO_START=0
NO_SERVICE=0
FORCE_TOKEN=0
ENABLE_STATE="未 enable"

info() {
    printf '%s\n' "$1"
}

warn() {
    printf 'install.sh: 警告：%s\n' "$1" >&2
}

die() {
    printf 'install.sh: 错误：%s\n' "$1" >&2
    exit 1
}

usage() {
    cat <<'USAGE'
用法：sh scripts/install.sh [选项]

把 EdgeNode agent 与只读 API 部署到设备，并安装独立的 uhttpd 服务
（procd 管理，默认监听 192.168.1.1:18080）。不会改动系统 uhttpd。

选项：
  --prefix DIR        安装根目录（默认 /overlay/edgenode）
  --listen ADDR:PORT  独立 uhttpd 监听地址（默认 192.168.1.1:18080）
  --init-dir DIR      init 脚本目录（默认 /etc/init.d，仅测试用）
  --no-start          只安装，不启动服务（仍会写 init 脚本并 enable）
  --no-service        不写 init 脚本、不 enable/start，仅铺文件；
                      同时放宽 root 要求，便于非 OpenWrt 环境自测
  --force-token       重新生成 api.token（默认保留已有 token；旧值会备份）
  -h, --help          显示本帮助

说明：
  - 已存在的目标文件会先备份为 <文件>.pre-install.<UTC时间戳>.bak。
  - api.token 与 device-id 已存在时默认保留，不会覆盖。
  - 需要 root（--no-service 除外）；依赖 md5sum，健康检查依赖 curl。
USAGE
}

# 路径只允许安全字符：这些值会被写进 init 脚本，必须排除空白、引号、
# $、反引号和反斜杠，避免生成可被注入或无法解析的服务脚本。
check_path() {
    _label="$1"
    _value="$2"

    [ -n "$_value" ] || die "$_label 不能为空"
    case "$_value" in
        *[!0-9A-Za-z_./+-]*)
            die "$_label 含不支持的字符（只允许字母、数字与 _ . / + -）：$_value"
            ;;
    esac
}

# 拒绝把系统目录当作安装前缀：chmod 700 / rm -rf 这类操作会毁掉设备。
check_prefix_safety() {
    _p="$1"
    case "$_p" in
        /|/bin|/boot|/dev|/etc|/home|/lib|/media|/mnt|/opt|/overlay|/proc|/rom|/root|/run|/sbin|/srv|/sys|/tmp|/usr|/var|/www)
            die "拒绝使用系统目录作为安装前缀：$_p"
            ;;
    esac
    case "$_p" in
        /etc/*|/proc/*|/sys/*|/dev/*|/rom/*)
            die "拒绝在系统目录下安装：$_p"
            ;;
    esac
}

check_listen() {
    _l="$1"

    case "$_l" in
        *:*) ;;
        *) die "--listen 需要 ADDR:PORT 形式：$_l" ;;
    esac

    _addr="${_l%:*}"
    _port="${_l##*:}"

    [ -n "$_addr" ] || die "--listen 缺少监听地址：$_l"
    case "$_addr" in
        *[!0-9A-Za-z_.:%-]*)
            die "--listen 地址含不支持的字符：$_addr"
            ;;
    esac
    case "$_port" in
        ""|*[!0-9]*) die "--listen 端口必须是数字：$_l" ;;
    esac
    if [ "${#_port}" -gt 5 ]; then
        die "--listen 端口超出范围 1-65535：$_l"
    fi
    if [ "$_port" -lt 1 ] || [ "$_port" -gt 65535 ]; then
        die "--listen 端口超出范围 1-65535：$_l"
    fi
}

# 32 位十六进制随机串。BusyBox 没有 base64，用 urandom + md5sum。
gen_hex32() {
    head -c 32 /dev/urandom | md5sum | cut -d' ' -f1
}

check_hex32() {
    _v="$1"
    _label="$2"

    if [ "${#_v}" -ne 32 ]; then
        die "$_label 生成失败（长度 ${#_v}，应为 32）"
    fi
    case "$_v" in
        *[!0-9a-f]*) die "$_label 生成失败（含非十六进制字符）" ;;
    esac
}

backup_file() {
    _f="$1"

    if [ -e "$_f" ]; then
        _b="$_f.pre-install.$STAMP.bak"
        cp -p "$_f" "$_b" || die "备份失败：$_f"
        info "已备份：$_b"
    fi
}

install_file() {
    _src="$1"
    _dst="$2"
    _mode="$3"

    backup_file "$_dst"
    if command -v install >/dev/null 2>&1; then
        install -m "$_mode" "$_src" "$_dst" || die "安装失败：$_dst"
    else
        # BusyBox 精简镜像可能没有 install applet。
        cp "$_src" "$_dst" || die "复制失败：$_dst"
        chmod "$_mode" "$_dst" || die "设置权限失败：$_dst"
    fi
    info "已安装：$_dst（模式 $_mode）"
}

# 凭据文件：已存在且非空则保留；--force-token 或文件为空时才生成。
ensure_secret() {
    _file="$1"
    _label="$2"
    _force="$3"

    if [ -s "$_file" ] && [ "$_force" -eq 0 ]; then
        chmod 600 "$_file" || die "设置权限失败：$_file"
        info "保留已有 $_label：$_file"
        return 0
    fi

    if [ -e "$_file" ]; then
        backup_file "$_file"
        chmod 600 "$_file.pre-install.$STAMP.bak" || die "设置备份权限失败：$_file"
    fi

    _val="$(gen_hex32)" || die "$_label 生成失败"
    check_hex32 "$_val" "$_label"

    (umask 077; printf '%s\n' "$_val" > "$_file") || die "写入失败：$_file"
    chmod 600 "$_file" || die "设置权限失败：$_file"
    info "已生成 $_label：$_file（模式 600）"
}

# 与设备上现存脚本保持一致，只替换监听地址与 www 根目录。
write_init_script() {
    _content="$(cat <<EOF
#!/bin/sh /etc/rc.common

START=99
STOP=10
USE_PROCD=1

start_service() {
    procd_open_instance
    procd_set_param command /usr/sbin/uhttpd -f \\
        -p $LISTEN \\
        -h $PREFIX/www \\
        -x /cgi-bin
    procd_set_param respawn
    procd_set_param stderr 1
    procd_close_instance
}
EOF
)" || die "生成 init 脚本内容失败"

    mkdir -p "$INIT_DIR" || die "创建 init 目录失败：$INIT_DIR"

    if [ -f "$INIT_SCRIPT" ]; then
        if [ "$(cat "$INIT_SCRIPT")" = "$_content" ]; then
            chmod 0755 "$INIT_SCRIPT" || die "设置权限失败：$INIT_SCRIPT"
            info "init 脚本内容未变化：$INIT_SCRIPT"
            return 0
        fi
        backup_file "$INIT_SCRIPT"
    fi

    printf '%s\n' "$_content" > "$INIT_SCRIPT" || die "写入失败：$INIT_SCRIPT"
    chmod 0755 "$INIT_SCRIPT" || die "设置权限失败：$INIT_SCRIPT"
    info "已写入 init 脚本：$INIT_SCRIPT（模式 755）"
}

while [ $# -gt 0 ]; do
    case "$1" in
        --prefix)
            [ $# -ge 2 ] || die "--prefix 需要一个目录参数"
            PREFIX="$2"
            shift 2
            ;;
        --prefix=*)
            PREFIX="${1#--prefix=}"
            shift
            ;;
        --listen)
            [ $# -ge 2 ] || die "--listen 需要 ADDR:PORT 参数"
            LISTEN="$2"
            shift 2
            ;;
        --listen=*)
            LISTEN="${1#--listen=}"
            shift
            ;;
        --init-dir)
            [ $# -ge 2 ] || die "--init-dir 需要一个目录参数"
            INIT_DIR="$2"
            shift 2
            ;;
        --init-dir=*)
            INIT_DIR="${1#--init-dir=}"
            shift
            ;;
        --no-start)
            NO_START=1
            shift
            ;;
        --no-service)
            NO_SERVICE=1
            shift
            ;;
        --force-token)
            FORCE_TOKEN=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            die "未知参数：$1（用 --help 查看用法）"
            ;;
    esac
done

check_path "--prefix" "$PREFIX"
check_path "--init-dir" "$INIT_DIR"
check_prefix_safety "$PREFIX"
check_listen "$LISTEN"

if [ "$NO_SERVICE" -eq 0 ] && [ "$(id -u)" != "0" ]; then
    die "安装并启动服务需要 root；仅铺文件自测请加 --no-service"
fi

if [ "$NO_SERVICE" -eq 0 ] && ! command -v uhttpd >/dev/null 2>&1; then
    warn "未找到 uhttpd，服务可能无法启动（OpenWrt 上应自带）"
fi

SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)" || die "无法定位脚本目录"
SRC_DIR="$(CDPATH='' cd -- "$SCRIPT_DIR/.." && pwd)" || die "无法定位源码目录"

AGENT_SRC="$SRC_DIR/agent/edgenode-agent"
API_SRC="$SRC_DIR/api/cgi-bin/api"

[ -f "$AGENT_SRC" ] || die "缺少源文件：$AGENT_SRC"
[ -f "$API_SRC" ] || die "缺少源文件：$API_SRC"

if [ ! -r /dev/urandom ] || ! command -v md5sum >/dev/null 2>&1; then
    die "生成凭据需要 /dev/urandom 与 md5sum（BusyBox 自带）"
fi

STAMP="$(date -u +%Y%m%dT%H%M%SZ)" || die "无法获取 UTC 时间戳"
INIT_SCRIPT="$INIT_DIR/edgenode-api"

info "EdgeNode 安装开始（源码目录：$SRC_DIR）"

mkdir -p "$PREFIX/bin" "$PREFIX/etc" "$PREFIX/www/cgi-bin" "$PREFIX/data" "$PREFIX/log" \
    || die "创建目录失败：$PREFIX"
PREFIX="$(CDPATH='' cd -- "$PREFIX" && pwd)" || die "无法解析安装前缀：$PREFIX"

chmod 700 "$PREFIX" || die "设置权限失败：$PREFIX"
chmod 700 "$PREFIX/bin" "$PREFIX/etc" "$PREFIX/data" "$PREFIX/log" || die "设置目录权限失败"
chmod 755 "$PREFIX/www" "$PREFIX/www/cgi-bin" || die "设置目录权限失败"

install_file "$AGENT_SRC" "$PREFIX/bin/edgenode-agent" 0700
install_file "$API_SRC" "$PREFIX/www/cgi-bin/api" 0755

ensure_secret "$PREFIX/etc/api.token" "API token" "$FORCE_TOKEN"
ensure_secret "$PREFIX/etc/device-id" "device-id" 0

if [ "$NO_SERVICE" -eq 0 ]; then
    write_init_script

    if [ -d /etc/rc.d ] && [ -f /etc/rc.common ]; then
        if "$INIT_SCRIPT" enable; then
            ENABLE_STATE="已 enable"
        else
            ENABLE_STATE="enable 失败"
            warn "enable 失败，请手动执行：$INIT_SCRIPT enable"
        fi
    else
        ENABLE_STATE="跳过 enable（无 /etc/rc.d 或 /etc/rc.common）"
        warn "未检测到 /etc/rc.d 或 /etc/rc.common，跳过 enable（非 OpenWrt 环境？）"
    fi

    if [ "$NO_START" -eq 0 ]; then
        # 未运行时 stop 会返回非 0，忽略即可。
        "$INIT_SCRIPT" stop >/dev/null 2>&1 || true
        "$INIT_SCRIPT" start || die "启动 edgenode-api 失败，请查看 logread"
        sleep 2
    fi
else
    info "--no-service：跳过 init 脚本、enable 与启动"
fi

if [ "$NO_SERVICE" -eq 0 ] && [ "$NO_START" -eq 0 ]; then
    if command -v curl >/dev/null 2>&1; then
        TOKEN="$(cat "$PREFIX/etc/api.token")" || die "读取 token 失败"
        # uhttpd 以 -x /cgi-bin 暴露 CGI，可访问路径是 /cgi-bin/api/v1/status。
        # 直接请求 /v1/status 只会命中静态根目录并返回 404。
        HEALTH_URL="http://$LISTEN/cgi-bin/api/v1/status"
        CODE="$(curl -s -o /dev/null -w '%{http_code}' -m 5 \
            -H "Authorization: Bearer $TOKEN" "$HEALTH_URL")" || CODE="000"
        if [ "$CODE" != "200" ]; then
            printf 'install.sh: 健康检查失败：HTTP %s（期望 200）\n' "$CODE" >&2
            printf '  URL：%s\n' "$HEALTH_URL" >&2
            printf '  请检查服务与日志：logread | grep -i edgenode\n' >&2
            printf '  以及：%s status；netstat -ltn | grep %s\n' "$INIT_SCRIPT" "${LISTEN##*:}" >&2
            exit 1
        fi
        info "健康检查通过：HTTP 200（$HEALTH_URL）"
    else
        warn "未找到 curl，跳过健康检查"
    fi
fi

info ""
info "EdgeNode 安装完成"
info "  安装前缀   ：$PREFIX"
if [ "$NO_SERVICE" -eq 0 ]; then
    info "  init 脚本  ：$INIT_SCRIPT"
else
    info "  init 脚本  ：未安装（--no-service）"
fi
info "  API 地址   ：http://$LISTEN/cgi-bin/api"
info "  Token 文件 ：$PREFIX/etc/api.token"
info "  设备标识   ：$PREFIX/etc/device-id"
if [ "$NO_SERVICE" -eq 1 ]; then
    info "  服务状态   ：未安装服务（--no-service，仅铺文件）"
elif [ "$NO_START" -eq 1 ]; then
    info "  服务状态   ：$ENABLE_STATE，未启动（--no-start）"
else
    info "  服务状态   ：$ENABLE_STATE，已启动"
fi
info ""
info "验证命令（token 不会被打印到终端或历史）："
printf "  curl -s -H \"Authorization: Bearer \$(cat %s)\" http://%s/cgi-bin/api/v1/status\n" \
    "$PREFIX/etc/api.token" "$LISTEN"

exit 0
