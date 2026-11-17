# Test Record — EdgeNode 0.1.3

## Test environment

| Item | Validated environment |
|---|---|
| Device | Cudy TR1200 v1 |
| Firmware | OpenWrt 25.12.6 |
| Target | ramips/mt76x8 |
| CPU architecture | MIPS 24KEc |
| OpenWrt architecture | `mipsel_24kc` |
| Shell | BusyBox ash |
| Agent | 0.1.3 |
| API | Read-only CGI via dedicated uhttpd/procd service |

These results describe the tested device and firmware combination only. They do not establish compatibility with all OpenWrt devices.

## Agent checks

| Check | Result |
|---|---|
| Agent starts and exits successfully | PASS |
| Output parses as JSON with jsonfilter | PASS |
| Device model, CPU, architecture, firmware reported | PASS |
| Persistent device ID read from local file | PASS |
| Uptime and 1-minute load reported | PASS |
| Memory and root filesystem usage reported | PASS |
| Network interface IPv4 data collected | PASS |
| ZeroTier status collected when CLI is available | PASS |
| UTC timestamp emitted | PASS |
| Clock synchronization validity | LIMITED — `time_valid` remains `false` |

## API checks

| Request | Expected | Result |
|---|---:|---|
| GET status without token | 401 | PASS |
| GET status with incorrect token | 401 | PASS |
| GET documented endpoint with valid token | 200 | PASS |
| GET device endpoint | 200 | PASS |
| GET system endpoint | 200 | PASS |
| GET network endpoint | 200 | PASS |
| GET ZeroTier endpoint | 200 | PASS |
| POST request | 405 | PASS |
| GET unknown route | 404 | PASS |

## Service isolation

- Dedicated EdgeNode uhttpd instance managed by procd: validated running.
- Dedicated listener configured for `192.168.1.1:18080`.
- Existing system uhttpd on ports 80/443 was left unchanged during validation.
- Service enablement was configured; a full reboot-based autostart test has not been recorded.

## Known gaps

- No automated test suite or continuous integration pipeline yet.
- No load, endurance, or resource-pressure testing.
- No TLS endpoint or remote exposure validation.
- No multi-device or multi-architecture validation.
- No fuzzing or formal security assessment.
- No verified NTP synchronization detection.
- No cloud, MQTT, SNMP/Modbus, remote configuration, or OTA test coverage because those features are not implemented.

## Reproduction and evidence

Run tests only on a lab or maintenance device with recovery access. Never publish API tokens, device UUIDs, MAC addresses, private network identifiers, or live IP addresses in test output. Sanitized sample data is provided in `../examples/status.json`.
