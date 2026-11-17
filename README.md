# EdgeNode

EdgeNode 是面向嵌入式 Linux 设备的轻量级边缘网关代理与管理平台。

项目面向 OpenWrt 路由器、工业边缘网关等资源受限设备。长期目标是构建具备硬件抽象、协议适配和云端管理连接能力的可移植设备代理。

## 当前版本基线

**版本：0.1.3 — 已完成设备验证的技术原型**

EdgeNode 0.1.3 原型已在运行 OpenWrt 25.12.6 的 Cudy TR1200 v1 上完成验证（ramips/mt76x8，MIPS）。这是一个经过单设备验证的技术原型，并非已经具备生产部署条件的多平台正式版本。

已实现并完成测试的功能：

- 基于 Shell 的设备代理，可采集设备身份、型号、CPU、架构、固件版本、运行时间、系统负载、内存和根文件系统使用情况。
- 采集网络接口 IPv4 信息。
- 在设备具备 ZeroTier 命令行工具时，采集 ZeroTier 网络状态。
- 提供本地只读 HTTP API，用于查询设备状态。
- API 请求必须携带 Bearer Token；拒绝非 GET 请求。
- API 由 procd 管理的独立 uhttpd 实例提供服务，监听地址为 `192.168.1.1:18080`，不替换系统原有 Web 服务。

尚未实现的功能：云端注册、HTTPS 心跳上报、设备群组管理、MQTT、SNMP/Modbus 协议适配、远程配置、OTA 升级、跨架构验证和生产级安全加固。

## 仓库目录

- `agent/` — 设备端代理程序
- `api/` — 本地 HTTP API
- `docs/` — 架构、API、安全、部署、测试和路线图文档
- `examples/` — 已脱敏的示例数据
- `scripts/` — 开发与部署辅助脚本
- `CHANGELOG.md` — 版本变更记录

## 文档

- [总体架构](docs/architecture.md)
- [本地 API 设计](docs/api-design.md)
- [安全说明](docs/security.md)
- [部署指南](docs/deployment.md)
- [测试记录](docs/testing.md)
- [开发路线图](docs/roadmap.md)
- [版本变更记录](CHANGELOG.md)
- [脱敏状态数据示例](examples/status.json)

## 安全须知

严禁将设备专属凭据、API Token、私钥、真实设备标识或正在使用的网络标识提交到代码仓库。示例数据仅用于说明，已进行脱敏处理。详细要求请参阅[安全说明](docs/security.md)。

## 开发与验证环境

当前已完成验证的环境：

- Cudy TR1200 v1
- OpenWrt 25.12.6
- MIPS 24KEc / `mipsel_24kc`
- BusyBox ash

后续架构计划通过硬件与平台抽象，逐步支持 MIPS、ARM 和 RISC-V 等设备平台。该兼容性目前尚未完成验证。

## 许可证

项目目前尚未选择开源许可证。除非后续明确添加许可证，否则项目内容保留所有权利。
