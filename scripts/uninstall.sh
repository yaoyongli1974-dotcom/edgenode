#!/bin/sh

# EdgeNode 卸载脚本 0.1.5
# 目标平台：OpenWrt / BusyBox ash（POSIX sh，无 bashism）。
#
# 只停止/删除 EdgeNode 自己的独立 uhttpd 服务（edgenode-api）。
# 绝不触碰系统 uhttpd（/www，80/443），也不修改 /etc/config/uhttpd。
#
# 默认保留安装前缀（含 api.token / device-id / data / log）；
# 只有显式 --purge 才递归删除整个前缀目录。

set -eu

PATH=/usr/sbin:/usr/bin:/sbin:/bin
export PATH

DEFAULT_PREFIX="/overlay/edgenode"
DEFAULT_INIT_DIR="/etc/init.d"

PREFIX="$DEFAULT_PREFIX"
INIT_DIR="$DEFAULT_INIT_DIR"
PURGE=0
NO_SERVICE=0

info() {
    printf '%s\n' "$1"
}

warn() {
    printf 'uninstall.sh: 警告：%s\n' "$1" >&2
}

die() {
    printf 'uninstall.sh: 错误：%s\n' "$1" >&2
    exit 1
}

usage() {
    cat <<'USAGE'
用法：sh scripts/uninstall.sh [选项]

停止并删除 EdgeNode 的独立 uhttpd 服务（edgenode-api）与 init 脚本。
不会停止或修改系统 uhttpd（/www，80/443）。

选项：
  --prefix DIR     安装根目录（默认 /overlay/edgenode）
  --init-dir DIR   init 脚本目录（默认 /etc/init.d，仅测试用）
  --purge          递归删除整个安装前缀目录
  --no-service     不动服务与 init 脚本，只处理前缀目录（自测用，放宽 root 要求）
  -h, --help       显示本帮助

警告：
  --purge 不做交互确认，会立即 rm -rf 整个前缀目录，其中包含
  api.token、device-id、data/ 与 log/，删除后无法恢复。
  不加 --purge 时前缀目录原样保留，便于回滚或保留设备身份。
USAGE
}

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

# --purge 会 rm -rf，必须挡住系统目录。
check_prefix_safety() {
    _p="$1"
    case "$_p" in
        /|/bin|/boot|/dev|/etc|/home|/lib|/media|/mnt|/opt|/overlay|/proc|/rom|/root|/run|/sbin|/srv|/sys|/tmp|/usr|/var|/www)
            die "拒绝把系统目录当作安装前缀：$_p"
            ;;
    esac
    case "$_p" in
        /etc/*|/proc/*|/sys/*|/dev/*|/rom/*)
            die "拒绝在系统目录下操作前缀：$_p"
            ;;
    esac
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
        --init-dir)
            [ $# -ge 2 ] || die "--init-dir 需要一个目录参数"
            INIT_DIR="$2"
            shift 2
            ;;
        --init-dir=*)
            INIT_DIR="${1#--init-dir=}"
            shift
            ;;
        --purge)
            PURGE=1
            shift
            ;;
        --no-service)
            NO_SERVICE=1
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

if [ "$NO_SERVICE" -eq 0 ] && [ "$(id -u)" != "0" ]; then
    die "停止/删除服务需要 root；仅处理临时目录自测请加 --no-service"
fi

INIT_SCRIPT="$INIT_DIR/edgenode-api"

info "EdgeNode 卸载开始"

if [ "$NO_SERVICE" -eq 0 ]; then
    if [ -x "$INIT_SCRIPT" ] && [ -f /etc/rc.common ]; then
        # 未运行时 stop/disable 可能返回非 0，忽略即可。
        "$INIT_SCRIPT" stop >/dev/null 2>&1 || true
        "$INIT_SCRIPT" disable >/dev/null 2>&1 || true
        info "已停止并 disable：edgenode-api"
    elif [ -e "$INIT_SCRIPT" ]; then
        warn "缺少 /etc/rc.common 或脚本不可执行，跳过 stop/disable：$INIT_SCRIPT"
    fi

    if [ -e "$INIT_SCRIPT" ] || [ -L "$INIT_SCRIPT" ]; then
        rm -f "$INIT_SCRIPT" || die "删除失败：$INIT_SCRIPT"
        info "已删除 init 脚本：$INIT_SCRIPT"
    else
        info "未发现 init 脚本：$INIT_SCRIPT"
    fi

    # 只清理指向 edgenode-api 的开机链接；无匹配时 glob 保持字面量，跳过。
    for link in /etc/rc.d/*edgenode-api; do
        if [ -L "$link" ] || [ -e "$link" ]; then
            rm -f "$link" || die "删除失败：$link"
            info "已删除开机链接：$link"
        fi
    done
else
    info "--no-service：跳过服务停止、disable 与 init 脚本删除"
fi

if [ -d "$PREFIX" ]; then
    PREFIX="$(CDPATH='' cd -- "$PREFIX" && pwd)" || die "无法解析安装前缀：$PREFIX"
fi

if [ "$PURGE" -eq 1 ]; then
    case "$PREFIX" in
        /*) ;;
        *) die "--purge 需要绝对路径前缀：$PREFIX" ;;
    esac
    check_prefix_safety "$PREFIX"

    if [ -d "$PREFIX" ]; then
        info "即将递归删除以下路径（--purge，不做确认，不可恢复）："
        info "  $PREFIX"
        for sub in bin etc www data log; do
            if [ -e "$PREFIX/$sub" ]; then
                info "  $PREFIX/$sub"
            fi
        done
        rm -rf "$PREFIX" || die "删除失败：$PREFIX"
        info "已删除：$PREFIX"
    else
        info "前缀目录不存在，无需删除：$PREFIX"
    fi
else
    info "已保留安装前缀（含 token/device-id 与数据）：$PREFIX"
    if [ -d "$PREFIX" ]; then
        info "  Token 文件 ：$PREFIX/etc/api.token"
        info "  设备标识   ：$PREFIX/etc/device-id"
    fi
    info "  如需彻底删除，请显式追加 --purge（不可恢复）"
fi

info ""
info "EdgeNode 卸载完成（系统 uhttpd 未被改动）"

exit 0
