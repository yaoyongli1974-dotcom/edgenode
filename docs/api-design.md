# 本地 API 设计说明

## API 基础地址

`http://192.168.1.1:18080/cgi-bin/api`

当前原型 API 仅供本地查询，所有接口均为只读。请求必须携带以下认证请求头：

`Authorization: Bearer <API_TOKEN>`

请勿在文档、代码仓库、截图或日志中公开 API Token。

## 接口列表

| 请求方法 | 路径 | 功能说明 |
|---|---|---|
| GET | `/v1/status` | 获取完整的 Agent 状态数据 |
| GET | `/v1/device` | 获取设备身份及平台信息 |
| GET | `/v1/system` | 获取时间戳、运行时间、系统负载、内存和存储信息 |
| GET | `/v1/network` | 获取网络接口及已采集的 ZeroTier 状态 |
| GET | `/v1/zerotier` | 获取 ZeroTier 状态数组 |

API 同时接受根路径请求，并将其映射为完整状态数据响应。

## HTTP 状态码与行为

- 缺少或无效的 Bearer Token：返回 `401 Unauthorized`。
- 请求方法不是 GET：返回 `405 Method Not Allowed`。
- 请求路径不存在：返回 `404 Not Found`。
- 请求成功：返回 `200 OK`。
- 响应包含 `Cache-Control: no-store`，避免客户端或中间缓存保存状态数据。
- 响应包含 `Content-Length` 与 `X-Content-Type-Options: nosniff`。
- 内部错误统一返回 `500 {"error":"internal_error"}`，具体原因只写入服务端日志。

## 当前限制

当前 API 通过设备局域网地址以 HTTP 方式提供服务，不适合直接暴露到公共互联网。HTTPS 云端通信和独立的设备凭据生命周期管理属于后续规划，当前版本尚未实现。
