# EdgeNode

EdgeNode is a lightweight edge-gateway agent and management platform for embedded Linux devices.

The project is designed for resource-constrained systems such as OpenWrt routers and industrial edge gateways. Its long-term direction is a portable agent with hardware abstraction, protocol adapters, and a cloud management connector.

## Current status

**Prototype: 0.1.3**

The current prototype has been validated on a Cudy TR1200 v1 running OpenWrt 25.12.6 (ramips/mt76x8, MIPS). It is a device-specific proof of concept, not yet a production-ready multi-platform release.

Implemented and tested:

- Shell-based agent reports device identity, model, CPU, architecture, firmware, uptime, load, memory, and root filesystem usage.
- Network interface IPv4 information is collected.
- ZeroTier network status is collected when the ZeroTier CLI is available.
- A local HTTP API exposes read-only status endpoints.
- API requests require a Bearer token; non-GET methods are rejected.
- The API runs as a separate uhttpd instance under procd on 192.168.1.1:18080, without replacing the system web server.

Not yet implemented: cloud registration, HTTPS heartbeat, fleet management, MQTT, SNMP/Modbus adapters, remote configuration, OTA, cross-architecture validation, and production hardening.

## Repository layout

- `agent/` — device-side agent
- `api/` — local HTTP API
- `docs/` — architecture, API, security, and roadmap
- `examples/` — sanitized example payloads
- `scripts/` — development and deployment helpers

Some directories may be added as implementation is exported and reviewed.

## Security

Never commit device-specific credentials, API tokens, private keys, real device identifiers, or network identifiers. See [Security](docs/security.md).

## Development platform

Initial validation target:

- Cudy TR1200 v1
- OpenWrt 25.12.6
- MIPS 24KEc / `mipsel_24kc`
- BusyBox ash

The architecture is intended to evolve toward MIPS, ARM, and RISC-V targets through hardware and platform abstraction.

## License

No open-source license has been selected yet. All rights are reserved unless a separate license is added.
