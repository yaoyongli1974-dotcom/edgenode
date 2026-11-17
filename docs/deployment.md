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
- 使用任何非 GET 请求方法：HTTP 405。
- 请求未知路径：HTTP 404。

当前验证设备的 API 基础地址：

`http://192.168.1.1:18080/cgi-bin/api`

当前 API 在局域网内通过 HTTP 提供服务。请勿将其暴露给不可信网络。HTTPS 终止和远程访问控制属于后续工作。

## 回滚方式

如需回滚，应使用已保存且确认可用的 EdgeNode Agent、CGI 和初始化脚本备份。确有需要时，只停止或禁用独立的 `edgenode-api` 服务。不得停止或重启系统原有 uhttpd 服务，也不得修改其他无关路由器服务。
