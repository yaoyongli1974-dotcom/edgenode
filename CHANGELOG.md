# 版本变更记录

本文件记录项目各版本的重要变更。

## [未发布]

Agent 版本号仍为 `0.1.4`（本次未改动采集逻辑与输出 schema），以下为仓库工程化与 API 行为变更。

### 新增

- GitHub Actions 流水线 `.github/workflows/test.yml`：push / pull request / 手动触发，在 ubuntu-latest 上对 sh、dash、busybox ash、bash 四种解释器分别运行回归测试，并单独运行 shellcheck。
- `Makefile`：`help`（默认）、`test`、`test-all`、`lint`、`dist`、`install`、`clean`；版本号从 Agent 的 `AGENT_VERSION` 提取，不重复硬编码。
- `scripts/install.sh`：幂等安装。覆盖前备份旧文件，按需生成 `api.token` 与 `device-id`（`/dev/urandom` + `md5sum`，0600），写入 procd init 脚本并 `enable`、重启独立 uhttpd，最后带 Token 做健康检查。支持 `--prefix`、`--listen`、`--init-dir`、`--no-start`、`--no-service`、`--force-token`。不修改 `/etc/config/uhttpd`，不触碰系统 uhttpd。
- `scripts/uninstall.sh`：停服务、`disable`、删除 init 脚本与开机链接；默认保留数据目录，`--purge` 才连同凭据一并删除。
- API 支持 `HEAD`：与 GET 走完全相同的鉴权、路由、采集与投影流程，状态码与响应头一致、`Content-Length` 相同，但不输出响应体，便于监控探针做存活检查。
- 其它方法返回 405 时新增 `Allow: GET, HEAD` 响应头。
- MIT 许可证（`LICENSE`）。

### 变更

- Agent 枚举网络接口改用 `/sys/class/net/*` glob，替代 `for … in $(ls …)`（消除 shellcheck SC2045）；输出与旧实现逐字节一致。
- 回归断言由 31 项增至 38 项，新增 HEAD 相关覆盖；`tests/run-tests.sh` 与两个安装脚本均通过 `shellcheck -s sh` 零告警。
- 文档：README 增加 CI 徽章、快速开始与目录说明；部署指南增加安装/卸载脚本章节；API 设计、安全说明、测试记录与路线图同步更新。

### 验证情况

- 脚本级：`make test-all` 四种解释器各 38 项全部通过；`make lint` 对 agent、api、tests、install、uninstall 五个脚本零告警。
- 设备级：在 Cudy TR1200 v1（OpenWrt 25.12.6）上用 `make dist` 产物走完整链路复验——安装、卸载（保留数据）、再安装均退出码 0；部署文件与仓库 sha256 一致；已有 Token 与设备标识保持不变；系统 uhttpd（pid 2290）全程未受影响。
- HEAD 行为在设备上用原始 HTTP 报文验证：HEAD 响应共 150 字节并以 `\r\n\r\n` 结束（无 body），响应头与 GET 逐字节相同；未授权 HEAD 同样无 body。

### 已知限制

- HEAD 仍会触发一次完整采集与投影，高频探针需注意设备负载。
- 安装脚本的健康检查依赖 `curl`（缺失时跳过）；`--listen` 地址白名单暂不接受 IPv6 方括号写法。
- 本地 API 仍为 HTTP 明文、仍由 root 身份的 uhttpd 提供；仍无请求限速与自动 Token 轮换。

## [0.1.4] - 2026-11-17

### 修复

- Agent 对所有字符串字段（设备型号、CPU、接口名、ZeroTier 网络名等）做 JSON 转义，字段中出现双引号或反斜杠不再产生非法 JSON。
- Agent 解析 `zerotier-cli listnetworks` 时改用 MAC 列作为锚点，网络名包含空格时不再静默丢弃整条记录（0.1.3 会跳过这类网络）。
- Agent 通过 `command -v` 与已知路径列表探测 ZeroTier CLI，不再硬编码单一绝对路径（不同固件与安装方式下该命令位置并不一致）。
- Agent 在 `/etc/openwrt_release` 缺失时不再报错，架构回退到 `uname -m`，固件版本为空字符串。
- Agent 对运行时间、负载、内存、存储增加数值兜底，采集失败时输出 `0`，避免出现 `"uptime_seconds":,` 这类非法 JSON。
- Agent 在 `/tmp/sysinfo/model` 缺失时回退到 `/etc/board.json`，减少上报 `Unknown` 的情况。
- API 响应补充 `Content-Length` 与 `X-Content-Type-Options: nosniff`。
- API 的 Token 比较改为比较摘要，避免明文逐字节比较带来的计时差异。
- API 对外统一 500 响应为 `{"error":"internal_error"}`，具体原因只写服务端日志。

### 新增

- `tests/run-tests.sh`：31 项脚本级回归测试，覆盖 Agent JSON 合法性/转义/ZeroTier 解析，以及 API 认证、方法限制、路由、错误处理与 `Content-Length`。
- Agent 与 API 的路径支持 `EN_*` 环境变量覆盖，仅用于自动化测试与非标准分区布局。

### 验证情况

- 脚本级：在 x86_64 Linux 上分别以 sh、dash、BusyBox ash、bash 执行 `sh tests/run-tests.sh`，四种解释器各 31 项全部通过。
- 设备级：已在 Cudy TR1200 v1（OpenWrt 25.12.6，mipsel_24kc）上部署并复验，记录见 `docs/testing.md`。
- Agent 输出字段与 0.1.3 及 `examples/status.json` 完全一致，本版本无 schema 变更。
- 部署到设备的文件与仓库文件 sha256 一致。
- 整机重启后独立 uhttpd 实例自动启动，overlay 中的程序与 Token 文件保持不变，API 认证、方法限制与路由行为均符合预期。
- 性能与 0.1.3 持平（交替 15 轮：旧版累计 9s，新版累计 8s）。

### 已知限制（本版本未修复）

- 本地 API 仍为 HTTP 明文，且仍由以 root 身份运行的 uhttpd 提供。
- 未引入请求限速、Token 轮换和逐设备凭据。
- 仍未建立 CI 流水线，测试需手动执行。
- ZeroTier 文本解析未采用 `zerotier-cli -j`；网络名中出现形如 MAC 地址的片段时仍可能定位错误。

## [0.1.3] - 2026-11-17

### 新增功能

- 从设备本地文件 `/overlay/edgenode/etc/device-id` 读取持久化设备标识。
- Agent 状态数据新增 UTC 时间戳字段。
- 新增 `time_valid` 字段。在尚不能可靠判断系统时钟同步状态前，该字段保守地固定为 `false`。
- 新增本地只读 HTTP API，提供设备状态、设备信息、系统信息、网络信息和 ZeroTier 状态查询接口。
- 新增由 procd 管理的独立 uhttpd 服务，监听地址为 `192.168.1.1:18080`。

### 验证情况

- 已在运行 OpenWrt 25.12.6 的 Cudy TR1200 v1 上验证 Agent 执行及 JSON 解析。
- 携带有效认证信息的 GET 请求能够返回预期 JSON 数据。
- 缺少 Bearer 凭据或凭据错误时返回 HTTP 401。
- 非 GET 请求返回 HTTP 405。
- 未知 API 路由返回 HTTP 404。
- API 服务与系统原有 uhttpd 服务独立运行。

### 安全改进与约束

- 仓库不包含设备专属标识、API Token 和真实网络运行数据。
- API 仅提供只读能力，不提供 Shell 或任意命令执行接口。

### 当前限制

- 本版本属于早期设备验证原型，并非可直接用于生产环境的多平台正式版本。
- 尚未实现云端注册、HTTPS 数据上报、设备群组管理、MQTT、SNMP/Modbus、远程配置、OTA 和生产级安全加固。
- Agent 尚不能验证系统时钟是否已完成同步。
- 尚未完成其他 CPU 架构和硬件平台的兼容性验证。
