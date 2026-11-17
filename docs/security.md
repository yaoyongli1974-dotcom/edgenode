# Security Notes

## Current controls

- Local API requires a Bearer token.
- Only GET is accepted; other HTTP methods are rejected.
- Unknown routes return 404.
- The API does not expose a shell or arbitrary command execution endpoint.
- The API runs on a dedicated local listener at 192.168.1.1:18080.
- The existing system uhttpd service and its configuration were left unchanged during prototype validation.
- The API token is stored separately from the agent source.

## Repository hygiene

Never commit:

- API tokens or authorization headers.
- Device-specific UUIDs or other production device identifiers.
- ZeroTier network IDs, node credentials, private keys, or real network topology.
- Private certificates, signing keys, passwords, or environment files.
- Unredacted device dumps that reveal infrastructure details.

Use synthetic identifiers and sanitized sample payloads in documentation.

## Known limitations

- The current local API uses HTTP, not HTTPS.
- Token rotation and per-device credential provisioning are not implemented.
- Cloud authentication, signed updates, secure configuration delivery, and OTA rollback are not implemented.
- The current prototype has only been validated on one hardware model.

Do not expose the local API to untrusted networks. Production deployment requires a threat model, secure provisioning, transport protection, credential rotation, and update integrity controls.
