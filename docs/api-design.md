# Local API

## Base URL

`http://192.168.1.1:18080/cgi-bin/api`

The current prototype API is local and read-only. Requests must include:

`Authorization: Bearer <API_TOKEN>`

Do not publish or commit the token.

## Endpoints

| Method | Path | Purpose |
|---|---|---|
| GET | `/v1/status` | Complete agent status document |
| GET | `/v1/device` | Device identity and platform information |
| GET | `/v1/system` | Timestamp, uptime, load, memory, and storage |
| GET | `/v1/network` | Network interfaces and collected ZeroTier status |
| GET | `/v1/zerotier` | ZeroTier status array |

The API also accepts the root route and maps it to the status response.

## HTTP behavior

- Missing or invalid Bearer token: `401 Unauthorized`
- Method other than GET: `405 Method Not Allowed`
- Unknown route: `404 Not Found`
- Successful response: `200 OK`
- Responses include `Cache-Control: no-store`

## Limitations

This is a prototype API served over HTTP on the device LAN address. It is not designed to be exposed directly to the public Internet. HTTPS cloud communication and a separate device credential lifecycle are planned, not implemented.
