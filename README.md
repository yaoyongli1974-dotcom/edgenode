# EdgeNode

[![test](https://github.com/yaoyongli1974-dotcom/edgenode/actions/workflows/test.yml/badge.svg)](https://github.com/yaoyongli1974-dotcom/edgenode/actions/workflows/test.yml)

EdgeNode 是面向嵌入式 Linux 设备的轻量级边缘网关代理与管理平台。

项目面向 OpenWrt 路由器、工业边缘网关等资源受限设备。长期目标是构建具备硬件抽象、协议适配和云端管理连接能力的可移植设备代理。

## 当前版本基线

**版本：0.1.5 — 已完成设备验证的技术原型**

> 0.1.5 为工程化收尾版本：新增 CI、Makefile、安装/卸载脚本、HEAD 支持与 MIT 许可证，采集逻辑与输出 schema 与 0.1.4 一致。0.1.4 的修复（JSON 转义、ZeroTier 解析、API 响应加固）已在 Cudy TR1200 v1 上部署复验并通过整机重启验证。仓库现有 38 项脚本级回归断言，在 GitHub Actions 上对 sh / dash / bash / busybox ash 四种解释器持续验证。详见 `CHANGELOG.md` 与 `docs/testing.md`。

EdgeNode 0.1.5 原型已在运行 OpenWrt 25.12.6 的 Cudy TR1200 v1 上完成验证（ramips/mt76x8，MIPS）。这是一个经过单设备验证的技术原型，并非已经具备生产部署条件的多平台正式版本。

已实现并完成测试的功能：

- 基于 Shell 的设备代理，可采集设备身份、型号、CPU、架构、固件版本、运行时间、系统负载、内存和根文件系统使用情况。
- 采集网络接口 IPv4 信息。
- 在设备具备 ZeroTier 命令行工具时，采集 ZeroTier 网络状态。
- 提供本地只读 HTTP API，用于查询设备状态。
- API 请求必须携带 Bearer Token；支持 `GET` 与 `HEAD`（HEAD 不返回响应体），其它方法返回 405。
- API 由 procd 管理的独立 uhttpd 实例提供服务，监听地址为 `192.168.1.1:18080`，不替换系统原有 Web 服务。

尚未实现的功能：云端注册、HTTPS 心跳上报、设备群组管理、MQTT、SNMP/Modbus 协议适配、远程配置、OTA 升级、跨架构验证和生产级安全加固。

## 仓库目录

- `agent/` — 设备端代理程序
- `api/` — 本地 HTTP API
- `docs/` — 架构、API、安全、部署、测试和路线图文档
- `examples/` — 已脱敏的示例数据
- `tests/` — 脚本级回归测试（`sh tests/run-tests.sh`）
- `scripts/` — 设备安装与卸载脚本
- `.github/workflows/` — GitHub Actions：四种 shell 的回归测试 + shellcheck
- `Makefile` — `test` / `test-all` / `lint` / `dist` / `install` / `clean`
- `CHANGELOG.md` — 版本变更记录
- `LICENSE` — MIT 许可证

## 快速开始

开发机（需要 GNU make 与 python3；dash、busybox、shellcheck 可选）：

```sh
make test        # 运行回归测试
make test-all    # 依次用 sh / dash / bash / busybox ash 运行
make lint        # shellcheck 静态检查（未安装则跳过）
make dist        # 打包 dist/edgenode-<版本>.tar.gz
```

设备端（OpenWrt）：把 tarball 传到设备 `/tmp` 解包后执行 `sh scripts/install.sh`，脚本会备份旧文件、按需生成 Token 与设备标识、安装并启动独立的 uhttpd 服务，最后做一次带 Token 的健康检查。详见[部署指南](docs/deployment.md)。

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

本项目采用 [MIT 许可证](LICENSE)（Copyright (c) 2026 Yaoyongli）。

