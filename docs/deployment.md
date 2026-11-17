# Deployment Guide

This guide describes the prototype deployment layout validated on a Cudy TR1200 v1 running OpenWrt 25.12.6. It is not a universal installer for every OpenWrt target.

## Safety requirements

- Keep the existing WAN, LAN, Wi-Fi, firewall, DNS, and ZeroTier configuration unchanged.
- Do not replace or modify the system `/etc/config/uhttpd` configuration.
- Do not stop or restart the system web server.
- Do not write to MTD or perform a firmware upgrade as part of EdgeNode deployment.
- Back up existing EdgeNode files before replacing them.
- Perform deployment during a maintenance window with local recovery access available.

## Runtime layout

The validated prototype uses the following paths:

| Purpose | Path |
|---|---|
| Agent | `/overlay/edgenode/bin/edgenode-agent` |
| API CGI | `/overlay/edgenode/www/cgi-bin/api` |
| Device ID | `/overlay/edgenode/etc/device-id` |
| API token | `/overlay/edgenode/etc/api.token` |
| procd service | `/etc/init.d/edgenode-api` |

The device ID and API token are instance-specific data. They must not be copied into source control or shared in issue reports.

## File permissions

The validated permission model is:

- Agent executable: owner root, mode `0700`.
- API CGI: owner root, mode `0755`.
- Device ID: owner root, mode `0600`.
- API token: owner root, mode `0600`.

Protect the parent configuration directory so that unprivileged users cannot read instance credentials.

## Service model

The prototype runs a dedicated uhttpd process under procd:

- Bind address: `192.168.1.1:18080`.
- Document root: `/overlay/edgenode/www`.
- CGI prefix: `/cgi-bin`.
- Init script: `/etc/init.d/edgenode-api`.

This separate listener avoids taking over the existing system web server. Do not change the listener or enable remote exposure without a separate security review.

## API authentication

Requests use an HTTP Bearer token:

```http
Authorization: Bearer <API_TOKEN>
```

Provision a unique, high-entropy token for each device through a trusted local process. Do not put the token in command history, screenshots, logs, source files, or support messages. Store it in the configured token file with root-only read permissions.

## Verification

After deployment, verify the service status and test the API from a trusted LAN host. Expected behavior:

- No token or an incorrect token: HTTP 401.
- Valid token with GET on a documented route: HTTP 200.
- Any non-GET method: HTTP 405.
- Unknown route: HTTP 404.

The current API base URL on the validated target is:

`http://192.168.1.1:18080/cgi-bin/api`

The API is currently HTTP on the LAN. Do not expose it to untrusted networks. HTTPS termination and remote access controls are future work.

## Rollback

Use the saved, known-good copies of the EdgeNode agent, CGI, and init script. Stop or disable only the dedicated `edgenode-api` service if rollback requires it. Do not stop or restart the system uhttpd service, and do not alter unrelated router services.
