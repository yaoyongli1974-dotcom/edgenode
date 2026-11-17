# EdgeNode Architecture

## Product direction

EdgeNode is intended to be a lightweight embedded Linux edge-gateway agent and management platform. The initial implementation is a shell prototype for OpenWrt; the target architecture is broader and must not be confused with features already implemented.

## Logical architecture

1. **Core Agent** — device identity, lifecycle, telemetry collection, local state, and task coordination.
2. **Hardware / Platform Abstraction** — normalizes operating-system, CPU, storage, network, and vendor-specific details.
3. **Protocol Adapters** — optional integrations such as MQTT, SNMP, and Modbus TCP.
4. **Cloud Connector** — outbound secure registration, heartbeat, telemetry upload, and later controlled management operations.
5. **Management Platform** — device registry, last-seen state, telemetry storage, fleet views, and policy management.

## Current prototype

The 0.1.3 prototype currently includes:

- A BusyBox ash shell agent.
- System and network telemetry collection.
- ZeroTier CLI status collection.
- A local read-only CGI API.
- A separate uhttpd service supervised by procd.

The current implementation is validated on one Cudy TR1200 v1 device. It is not yet a complete implementation of the logical architecture above.

## Resource constraints

The initial target has limited RAM and flash. The design therefore favors small native utilities, bounded runtime data, low-volume logging, and outbound cloud communication. Persistent telemetry should ultimately be stored centrally rather than accumulated on small device flash.

## Evolution

The intended evolution is to separate portable core logic from platform-specific collection, then introduce a small compiled core (planned C implementation) where it materially improves reliability, performance, and portability.
