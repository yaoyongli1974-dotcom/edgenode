# Roadmap

This roadmap describes intended work. Items below are not claims of completed functionality unless explicitly marked implemented.

## 0.1.x — Local prototype

Implemented and validated on one Cudy TR1200 v1 device:

- Shell agent with device, system, network, and ZeroTier status collection.
- Persistent device identifier stored outside the source tree.
- Local read-only HTTP API with Bearer authentication.
- Separate uhttpd service supervised by procd.

## 0.2.0 — Cloud connectivity

Planned:

- Device registration and enrollment flow.
- Per-device cloud credentials, separate from the local API token.
- Outbound HTTPS heartbeat and telemetry upload.
- Server-side last-seen state and basic device registry.
- Bounded retry and offline behavior.

## 0.3.x — Device management

Planned:

- Fleet inventory and status views.
- Telemetry history and alert rules.
- Controlled configuration model and audit trail.

## 0.4.x — Protocol adapters

Planned:

- MQTT integration where required.
- SNMP and Modbus TCP adapters.
- Adapter capability discovery and normalized data model.

## 0.5.x — Platform portability

Planned:

- Hardware abstraction and platform adapters.
- Validation on additional MIPS, ARM, and RISC-V devices.
- Build and release automation.

## 1.0 — Product hardening

Planned:

- Secure provisioning and credential rotation.
- Signed update packages and rollback strategy.
- Resource, security, and long-duration stability testing.
- Versioned compatibility and deployment documentation.
