# EdgeNode 测试记录

## 测试环境

| 项目 | 已验证环境 |
|---|---|
| 设备型号 | Cudy TR1200 v1 |
| 固件版本 | OpenWrt 25.12.6 |
| 目标平台 | ramips/mt76x8 |
| CPU 架构 | MIPS 24KEc |
| OpenWrt 架构标识 | `mipsel_24kc` |
| Shell 环境 | BusyBox ash |
| Agent | 0.1.4（0.1.3 的结果仍见本节下方历史记录） |
| API | 通过独立 uhttpd/procd 服务提供的只读 CGI 接口 |

以上结果仅说明该设备与固件组合已完成测试，不能据此认定所有 OpenWrt 设备均兼容。

## Agent 功能检查

| 检查项目 | 测试结果 |
|---|---|
| Agent 能够启动并正常执行结束 | 通过 |
| 输出内容能够由 jsonfilter 解析为 JSON | 通过 |
| 能够上报设备型号、CPU、架构和固件信息 | 通过 |
| 能够从本地文件读取持久化设备标识 | 通过 |
| 能够上报运行时间和 1 分钟系统负载 | 通过 |
| 能够上报内存和根文件系统使用情况 | 通过 |
| 能够采集网络接口 IPv4 信息 | 通过 |
| ZeroTier 命令行工具可用时能够采集其状态 | 通过 |
| 能够输出 UTC 时间戳 | 通过 |
| 系统时钟同步有效性 | 有限制：`time_valid` 当前保持为 `false` |

## API 功能检查

| 请求场景 | 预期状态码 | 测试结果 |
|---|---:|---|
| 不携带 Token 请求状态接口 | 401 | 通过 |
| 携带错误 Token 请求状态接口 | 401 | 通过 |
| 携带有效 Token 请求文档列出的接口 | 200 | 通过 |
| 请求设备信息接口 | 200 | 通过 |
| 请求系统信息接口 | 200 | 通过 |
| 请求网络信息接口 | 200 | 通过 |
| 请求 ZeroTier 信息接口 | 200 | 通过 |
| 发送 POST 请求 | 405 | 通过（响应带 `Allow: GET, HEAD`） |
| 发送 HEAD 请求 | 200 | 通过（响应头与 GET 一致，无响应体） |
| 请求未知路由 | 404 | 通过 |

## 服务隔离检查

- 由 procd 管理的 EdgeNode 独立 uhttpd 实例：已验证正常运行。
- 独立服务监听地址：`192.168.1.1:18080`。
- 验证期间，系统原有监听 80/443 端口的 uhttpd 服务保持不变。
- 已配置服务启用；0.1.4 复验时完成整机重启，独立实例随系统自动启动（详见下方 0.1.4 复验记录）。

## 0.1.4 设备复验记录（2026-11-17）

在 Cudy TR1200 v1 上完成部署与复验，设备配置与 0.1.3 相同。旧版文件保留为
`/overlay/edgenode/bin/edgenode-agent.014.pre.bak` 与
`/overlay/edgenode/www/cgi-bin/api.014.pre.bak`，可用于回滚。

| 检查项 | 结果 | 说明 |
|---|---|---|
| 部署文件与仓库文件一致 | 通过 | sha256 逐字节一致 |
| Agent 输出的 JSON 可由设备 `jsonfilter` 解析 | 通过 | 完整文档可解析，字段可逐项查询 |
| 输出字段与 0.1.3 逐项对比 | 无差异 | 已排除版本号、时间戳、运行时长、负载与内存瞬时值 |
| ZeroTier 网络名含空格 | 通过 | 夹具注入；同一夹具下旧版解析 1/2 条，新版 2/2 条且名称完整 |
| 型号含双引号与反斜杠 | 通过 | `jsonfilter` 取回值与输入逐字节一致 |
| ZeroTier CLI 探测 | 通过 | 本设备实际为 `/usr/bin/zerotier-cli`（指向 `zerotier-one`） |
| 无 Token / 错误 Token | 401 | |
| POST / HEAD 请求 | 405 | 0.1.4 当时只接受 GET；HEAD 支持在后续工程化收尾中加入，见下方记录 |
| 未知路由 | 404 | |
| 五个接口与根路径 | 200 | |
| `Content-Length` 与实际字节数一致 | 通过 | 实测 1113 = 1113 |
| procd 停止 / 启动 | 通过 | 18080 随服务启停；系统 uhttpd（pid 2098）全程未受影响 |
| 开机自启（整机重启） | 通过 | 重启后 `boot_id` 变化、uptime 归零；独立 uhttpd 自动监听 18080；系统 uhttpd 同时正常监听 80/443；overlay 文件与 sha256 不变 |
| 性能 | 无回退 | 新旧版本交替 15 轮：旧版累计 9s，新版累计 8s |

复验中发现并修复的问题：初版实现为每个字符串字段调用一次转义函数，在 MIPS 设备上把单次采集从约 575ms 拖慢到约 1550ms。改为内建命令快路径后，耗时回到与 0.1.3 持平。

## 工程化收尾复验记录（2026-11-17）

在同一台 Cudy TR1200 v1 上，用仓库打包产物走完整安装链路复验（`make dist` → 传输 tarball → 设备解包 → `sh scripts/install.sh`）。tarball 传输前后 sha256 一致。

| 检查项 | 结果 | 说明 |
|---|---|---|
| `install.sh` 首次安装 | 通过 | 退出码 0；旧文件备份为 `*.pre-install.<UTC>.bak`；健康检查 HTTP 200 |
| 部署文件与仓库文件一致 | 通过 | agent `dfccfe2f…`、api `dad8ed66…`，本地与设备 sha256 相同 |
| 已有凭据保留 | 通过 | `api.token`、`device-id` 内容与权限（0600）均未变化 |
| init 脚本幂等 | 通过 | 内容与设备现存脚本一致时不重写、不产生备份 |
| 文件权限 | 通过 | agent 0700、CGI 0755、凭据 0600 |
| `uninstall.sh`（保留数据） | 通过 | 服务停止、`disable`、init 脚本与 `rc.d` 链接删除；18080 不再响应；`/overlay/edgenode` 与凭据保留 |
| 再次 `install.sh` | 通过 | 重新写入 init 脚本并 `enable`，`S99`/`K10` 链接恢复，健康检查 200 |
| 系统 uhttpd 隔离 | 通过 | 安装、卸载、重装全过程系统 uhttpd pid 2290 不变，80 端口返回 200 |
| HEAD 与 GET 响应头一致 | 通过 | 原始 HTTP 报文逐字节 `cmp` 相同 |
| HEAD 无响应体 | 通过 | HEAD 原始报文共 150 字节，以 `…niff\r\n\r\n` 结束；GET 为 1262 字节（body 1112） |
| HEAD 未授权 | 通过 | 401，报文同样以 `\r\n\r\n` 结束，无 body |
| POST | 405 | 响应头含 `Allow: GET, HEAD` |
| 无 Token / 错误 Token / 未知路由 | 401 / 401 / 404 | |
| 接口枚举改为 glob 后输出一致 | 无差异 | 新旧 agent 的 `network`、`device` 段 `cmp` 完全相同 |

设备 `/tmp` 中的 tarball 与解包目录已在复验后清理；`/overlay` 使用率 43%。

## 自动化回归测试（0.1.4 起）

`tests/run-tests.sh` 提供脚本级回归测试，不依赖 OpenWrt 硬件，可在任意具备 `sh` 与 `python3` 的机器上执行：

```sh
sh tests/run-tests.sh
```

可通过 `EN_SH` 指定被测脚本的解释器，用于验证跨 shell 兼容性（`echo`、`read` 字段切分等行为在不同 shell 中并不一致）：

```sh
EN_SH=dash sh tests/run-tests.sh
EN_SH="busybox ash" sh tests/run-tests.sh
```

覆盖范围（当前 38 项断言）：

- Agent 输出的 JSON 合法性、字符串转义（型号含双引号与反斜杠）、数值兜底。
- `openwrt_release` 或 `device-id` 缺失时的降级行为。
- ZeroTier 网络名含空格时的完整解析（0.1.3 的回归缺陷）、`NOT_FOUND` 记录、无 CLI 时的空数组。
- API 认证（401）、方法限制（405 且带 `Allow: GET, HEAD`）、未知路由（404）、内部错误（500 且对外不可区分）。
- API 响应 `Content-Length` 与实际字节数一致。
- HEAD 与 GET 的状态码、响应头、`Content-Length` 一致，且 HEAD 不输出响应体（含 401 场景）。

批量执行与静态检查：

```sh
make test-all    # 依次用 sh / dash / bash / busybox ash 运行，缺失的解释器跳过
make lint        # shellcheck -s sh（未安装则跳过）
```

GitHub Actions（`.github/workflows/test.yml`）在 push、pull request 与手动触发时，于 ubuntu-latest 上对上述四种解释器分别运行同一套断言，并单独运行 shellcheck。

测试通过 `EN_*` 环境变量注入夹具路径，不会读写设备上的真实配置。若环境中没有 `jsonfilter`，测试会使用 `tests/fixtures/jsonfilter_stub.py` 作为等价实现；在 OpenWrt 设备上执行时则使用真实 `jsonfilter`。

## 已知测试缺口

- 回归测试已接入 GitHub Actions（四种解释器 + shellcheck），但 CI 只覆盖 x86_64 脚本行为；真实 OpenWrt 硬件上的验证仍为手工执行。
- 尚未开展负载、耐久性和资源压力测试。
- 尚未进行 TLS 接口或远程暴露场景验证。
- 尚未完成多设备、多 CPU 架构兼容性验证。
- 尚未开展模糊测试或正式安全评估。
- 尚未实现经过验证的 NTP 时钟同步状态检测。
- 云端、MQTT、SNMP/Modbus、远程配置和 OTA 功能尚未实现，因此没有对应测试覆盖。

## 测试复现与证据管理

测试应仅在具备实验条件或维护窗口、且可进行本地恢复的设备上开展。测试输出不得公开 API Token、设备 UUID、MAC 地址、私有网络标识或真实 IP 地址。脱敏示例数据位于 `../examples/status.json`。
