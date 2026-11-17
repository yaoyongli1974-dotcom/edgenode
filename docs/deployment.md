# EdgeNode 部署指南

本指南描述已在 Cudy TR1200 v1（OpenWrt 25.12.6）上验证的原型部署目录和运行方式。它不是适用于所有 OpenWrt 设备的通用安装程序。

## 部署安全要求

- 保持现有 WAN、LAN、Wi-Fi、防火墙、DNS 和 ZeroTier 配置不变。
- 不替换、不修改系统原有的 `/etc/config/uhttpd` 配置。
- 不停止或重启系统原有 Web 服务。
- EdgeNode 部署过程中不得写入 MTD，也不得执行固件升级。
- 替换文件前，先备份设备上现有的 EdgeNode 文件。
- 应在维护窗口内操作，并确保具备本地恢复设备的条件。

## 运行目录

当前已验证原型使用以下路径：

| 用途 | 路径 |
|---|---|
| Agent 程序 | `/overlay/edgenode/bin/edgenode-agent` |
| API CGI 程序 | `/overlay/edgenode/www/cgi-bin/api` |
| 设备标识文件 | `/overlay/edgenode/etc/device-id` |
| API Token 文件 | `/overlay/edgenode/etc/api.token` |
| procd 服务脚本 | `/etc/init.d/edgenode-api` |

设备标识和 API Token 均属于设备实例专属数据，不得复制到源码仓库，也不得在问题报告中公开。

## 文件权限

当前已验证的权限设置如下：

- Agent 可执行文件：所有者 root，权限模式 `0700`。
- API CGI 文件：所有者 root，权限模式 `0755`。
- 设备标识文件：所有者 root，权限模式 `0600`。
- API Token 文件：所有者 root，权限模式 `0600`。

同时应保护上级配置目录，防止非特权用户读取设备凭据。

## 运行时依赖

当前 API 与 Agent 依赖设备上已有的以下组件：

| 组件 | 用途 | 说明 |
|---|---|---|
| uhttpd | 提供 CGI 与 HTTP 服务 | 使用独立实例，不修改系统原有配置 |
| jsonfilter | API 按路径投影 JSON 字段 | OpenWrt base 自带（ubox） |
| md5sum | API 比较 Bearer Token 摘要 | BusyBox 自带 |
| ip、df、awk、tr、date | Agent 采集设备状态 | BusyBox 自带 |
| zerotier-cli | 可选的 ZeroTier 状态采集 | 未安装时 `zerotier` 字段为空数组 |

缺少 `jsonfilter` 时，`/v1/device` 等投影接口会返回 `500 {"error":"internal_error"}`，具体原因写入服务端日志。

## 使用安装脚本部署

仓库提供 `scripts/install.sh`（POSIX sh，可在 BusyBox ash 下运行），替代早期纯手工 `scp` + `chmod` 流程。脚本只部署 EdgeNode 自己的文件，并管理独立的 uhttpd 实例。

在开发机上打包并传输：

```sh
make dist
scp dist/edgenode-<VERSION>.tar.gz root@192.168.1.1:/tmp/
```

在设备上解包并安装：

```sh
cd /tmp && tar xzf edgenode-<VERSION>.tar.gz
sh scripts/install.sh
```

常用选项：

| 选项 | 作用 |
|---|---|
| `--prefix DIR` | 安装根目录，默认 `/overlay/edgenode` |
| `--listen ADDR:PORT` | 独立 uhttpd 监听地址，默认 `192.168.1.1:18080` |
| `--init-dir DIR` | init 脚本目录，默认 `/etc/init.d`（仅测试用） |
| `--no-start` | 只安装并 enable，不启动服务 |
| `--no-service` | 只铺文件，不写 init 脚本、不 enable/start（便于非 OpenWrt 环境自测） |
| `--force-token` | 强制重新生成 API Token（默认保留已有 Token） |

脚本行为要点：

- 覆盖前先把现有 agent / CGI 备份为 `*.pre-install.<UTC 时间戳>.bak`。
- `api.token`、`device-id` 仅在缺失时生成（`/dev/urandom` + `md5sum`），权限 `0600`；已存在则保留。
- 按上表权限安装文件，写入 `/etc/init.d/edgenode-api` 并 `enable`，随后重启该独立服务。
- 安装结束做一次健康检查：带 Token 请求 `/cgi-bin/api/v1/status`，期望 `200`，否则报错退出（设备未装 `curl` 时跳过该检查）。
- 不修改 `/etc/config/uhttpd`，不停止或重启系统 uhttpd。

卸载：

```sh
sh scripts/uninstall.sh            # 停服务、disable、删除 init 脚本，保留数据目录
sh scripts/uninstall.sh --purge    # 连同 /overlay/edgenode（含 Token 与设备标识）一并删除
```

## 服务运行方式

原型通过 procd 管理一个独立的 uhttpd 进程：

- 监听地址：`192.168.1.1:18080`。
- Web 根目录：`/overlay/edgenode/www`。
- CGI 路径前缀：`/cgi-bin`。
- 初始化脚本：`/etc/init.d/edgenode-api`。

独立监听服务可避免接管系统原有 Web 服务。未经单独安全评估，不得更改监听地址或开放远程访问。

## API 身份认证

请求使用 HTTP Bearer Token 认证：

```http
Authorization: Bearer <API_TOKEN>
```

应通过可信的本地流程为每台设备配置唯一且具有足够随机性的 Token。不要将 Token 写入命令历史、截图、日志、源码文件或支持沟通内容。Token 应存储在指定文件中，并设置为仅 root 可读。

## 部署验证

部署后，应从可信的局域网主机检查服务状态并测试 API。预期行为如下：

- 未携带 Token 或 Token 错误：HTTP 401。
- 携带有效 Token，对文档列出的接口发起 GET 请求：HTTP 200。
- 携带有效 Token 发起 HEAD 请求：状态码与响应头和 GET 一致，`Content-Length` 相同，但无响应体。
- 使用 GET/HEAD 以外的请求方法：HTTP 405，并带 `Allow: GET, HEAD`。
- 请求未知路径：HTTP 404。

当前验证设备的 API 基础地址：

`http://192.168.1.1:18080/cgi-bin/api`

当前 API 在局域网内通过 HTTP 提供服务。请勿将其暴露给不可信网络。HTTPS 终止和远程访问控制属于后续工作。

## 回滚方式

如需回滚，应使用已保存且确认可用的 EdgeNode Agent、CGI 和初始化脚本备份。确有需要时，只停止或禁用独立的 `edgenode-api` 服务。不得停止或重启系统原有 uhttpd 服务，也不得修改其他无关路由器服务。
