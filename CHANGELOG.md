# Changelog

All notable project changes are documented here.

## [0.1.3] - 2026-11-17

### Added
- Persistent device identity read from `/overlay/edgenode/etc/device-id`.
- UTC timestamp field in the agent status payload.
- `time_valid` field, conservatively set to `false` until clock synchronization can be verified reliably.
- Read-only local HTTP API endpoints for status, device, system, network, and ZeroTier data.
- Separate uhttpd service managed by procd, listening on `192.168.1.1:18080`.

### Validated
- Agent execution and JSON parsing on Cudy TR1200 v1 running OpenWrt 25.12.6.
- Authenticated GET requests return the expected JSON payloads.
- Missing or incorrect Bearer credentials return HTTP 401.
- Non-GET requests return HTTP 405.
- Unknown API routes return HTTP 404.
- API service operates separately from the existing system uhttpd service.

### Security
- Device-specific identifiers, API tokens, and live network values are excluded from the repository.
- The API is read-only and exposes no shell or arbitrary command execution endpoint.

### Limitations
- This is an early, device-validated prototype, not a production-ready multi-platform release.
- Cloud registration, HTTPS reporting, fleet management, MQTT, SNMP/Modbus, remote configuration, OTA, and production hardening are not implemented.
- The system clock synchronization state is not yet verified by the agent.
- Cross-architecture validation has not been completed.
