# Research: 巴法云 (Bemfa Cloud) HTTP API Status

- **Query**: 巴法云 HTTP API 当前状态、文档、变更与最佳实践
- **Scope**: external (web docs + code review)
- **Date**: 2026-05-02

## Findings

### Official Documentation

| Resource | URL | Notes |
|---|---|---|
| 文档中心 | `https://cloud.bemfa.com/docs/` | VitePress-based doc center, comprehensive sidebar |
| 快速入门 | `https://cloud.bemfa.com/docs/src/` | Intro + publish/subscribe model explanation |
| 设备接口文档 | `https://cloud.bemfa.com/docs/src/api_device.html` | All device API endpoints documented |
| 用户接口文档 | `https://cloud.bemfa.com/docs/src/api_user.html` | User registration/login, AppID/key management |
| CSDN 博客 | `https://blog.csdn.net/bemfa` | Active blog, latest post 2026-04-25 (BLE provisioning) |
| 实例指南 | `https://bbs.bemfa.com` | Community examples forum |
| 巴法官网 (SPA) | `https://cloud.bemfa.com` | Main site, requires JS (Vue.js SPA) |

**Note**: The main site `cloud.bemfa.com` is a single-page app requiring JavaScript. The docs at `cloud.bemfa.com/docs/` are fully server-rendered and will work with plain HTTP fetches.

### API Endpoints in Use (Code Audit)

The Flutter app at `smart_watering/lib/services/bemfa_api_service.dart` uses these 3 endpoints:

| Endpoint | Method | Status | Docs Match |
|---|---|---|---|
| `/va/online` | GET | ✅ Active | Matches docs: `uid`, `topic`, `type` params → `{"code":0, "data": bool}` |
| `/va/postJsonMsg` | POST | ✅ Active | Matches docs: JSON body with `uid`, `topic`, `type`, `msg` |
| `/va/getmsg` | GET | ✅ Active | Matches docs: `uid`, `topic`, `type`, `num` params |

**Key observation**: All 3 endpoints are documented exactly as the code uses them. No deprecations or breaking changes detected.

### New/Alternative Endpoints (Not Currently Used)

| Endpoint | Method | Description | Relevance |
|---|---|---|---|
| `/va/sendMessage` | GET | Alternative to `postJsonMsg` (query-string based) | Simpler for basic on/off commands |
| `/vb/api/v2/allTopic` | GET | Get all topics for a user (includes `online` status per topic) | Could replace individual `/va/online` calls |
| `/vb/api/v2/topicInfo` | GET | Get single topic info (includes `online`, `onlineNum`, `pubOnline`) | Richer than `/va/online` |
| `/vb/api/v2/groupTopic` | GET | Get devices by group | Multi-device management |
| `/pro.bemfa.com/v1/createTopic` | POST | Create topic programmatically | Could eliminate manual topic creation |

### `/va/online` Endpoint Detail

From docs (`cloud.bemfa.com/docs/src/api_device.html` line ~2075):

- **Parameters**: `uid` (required), `topic` (required), `type` (required)
- **Response**: `{"code": 0, "message": "OK", "data": true/false}`
- **data=true**: device is online (has subscriber connected)
- **data=false**: device is offline
- **Error codes**: `0`=success, `10002`=bad params, `40000`=unknown, `40004`=wrong key/topic

**Code usage check** (`bemfa_api_service.dart:79-103`):
- The code correctly checks `payload['code'] == 0` then reads `data` as bool
- The code has a fallback: `data is bool ? data : data == true` — the docs confirm `data` is always a boolean, so this is slightly defensive but correct.

### `/va/postJsonMsg` vs `/va/sendMessage`

| Feature | postJsonMsg (POST) | sendMessage (GET) |
|---|---|---|
| HTTP Method | POST (JSON body) | GET (query params) |
| `wemsg` param | ✅ Supported | ✅ Supported |
| Use case | Complex messages | Simple on/off/t:value commands |
| Current code | **Uses this** | Not used |

The POST variant is appropriate for the app's use case since commands like `set:30,60` contain commas that need proper encoding.

### `/va/getmsg` Polling Details

From docs:
- `num` parameter: number of historical messages to fetch (default=1, max=5000)
- Response: `{"code":0, "data": [{"msg": "...", "time": "2022-08-03 17:26:34", "unix": 1659518794}]}`
- Messages are ordered by time (most recent last)
- Current code sets `num=5` (_pollBatchSize) — this is conservative and well below the max of 5000

### Authentication

- **Primary auth**: `uid` (用户私钥) as a query/body parameter — no OAuth, no API keys required for device operations
- **Alternative MQTT auth**: `appID` + `secretKey` as username/password (used when clientID doesn't match)
- **API key pairs**: Available for enterprise/verified users (`secretId` + `secretKey`), optional for most endpoints
- **No changes**: Authentication mechanism is unchanged from when the code was written

### Rate Limits

**No explicit rate limit documentation found** for the device API endpoints (`/va/*`).

However, the user API documents several relevant limits:
- `40007` error code = "请求次数过多" (too many requests) — seen on login/register endpoints
- Login protection: 6 wrong password attempts in 1 minute → 1-minute lockout
- Email registration: rate-limited (returns 40007)

**Practical observations for the Flutter app**:
- The current 3-second polling interval at `_pollBatchSize=5` appears safe given the absence of documented rate limits
- GET-based endpoints (`/va/online`, `/va/getmsg`) are likely more generously rate-limited than POST endpoints
- The `num` parameter max of 5000 on `/va/getmsg` suggests the platform expects batch reads and tolerates them

### Protocol Versions

| Type Value | Protocol | Status |
|---|---|---|
| 1 | MQTT | ✅ Stable (used by code) |
| 3 | TCP | ✅ Stable |
| 5 | MQTT V2 | 🧪 Beta (内测中) |
| 7 | TCP V2 | 🧪 Beta (内测中) |

The current code uses `type=1` (MQTT) in `app_config.dart`. This is correct and stable.

### MQTT Connection Info (for firmware context)

From docs (`cloud.bemfa.com/docs/src/mqtt.html`):

| Port | Protocol | TLS | Notes |
|---|---|---|---|
| 9501 | MQTT (plain TCP) | No | Used by firmware (`smart_watering_esp8266.ino:12`) |
| 9503 | MQTT (TLS) | Yes (1.2) | Recommended for production |
| 9504 | WebSocket (TLS) | Yes | WebSocket path: `/wss` |

The firmware uses plain MQTT on port 9501 — matches the docs. The Flutter app uses HTTP API (not MQTT), so port info is only relevant for understanding the device side.

### Platform Activity & Health

- **Last blog post**: 2026-04-25 (BLE provisioning for ESP32) — actively maintained
- **CSDN**: 58 original articles, 840K+ total visits, ~3K followers
- **Recent features**: BLE provisioning, Home Assistant integration (Oct 2025), ESP32-C6 support
- **Community**: Active forum at bbs.bemfa.com
- **Deprecations noted**: 
  - 天猫精灵 (Tmall Genie) integration: marked "下线" (offline/retired)
  - No other deprecations in the device API layer

### Code-Implementation Gaps

| Issue | Detail | Severity |
|---|---|---|
| `DEV_SPEC.md` vs reality | DEV_SPEC references `mqtt_service.dart` (MQTT), but the actual app uses `bemfa_api_service.dart` (HTTP API). This is a documentation drift. | Low |
| `type` field | Code uses `type: 1` (MQTT) even though it's doing HTTP polling. The API docs treat `type` as the device protocol type, not the access method. This is correct per docs. | None |
| `online` endpoint data type | Code handles `data` as both `bool` and truthy value. Docs confirm it's always `bool`. Defensive but slightly redundant. | None |

## Code Snippets (Current Usage)

### AppConfig (smart_watering/lib/config/app_config.dart:1-86)
```dart
class AppConfig {
  final String uid;         // 'f148fce62c08490e9ffe25b43948c5c8'
  final String controlTopic; // 'plant001'
  final String reportTopic;  // 'plant001up'
  final int type;           // 1 (MQTT)
}
```

### BemfaApiService endpoints (smart_watering/lib/services/bemfa_api_service.dart:46-48)
```dart
static const String _baseUrl = 'https://apis.bemfa.com';
static const Duration _defaultTimeout = Duration(seconds: 10);
static const int _pollBatchSize = 5;
```

## Caveats / Not Found

1. **No official SDK**: Bemfa provides only HTTP API + MQTT/TCP protocols. No Dart/Flutter SDK exists.
2. **No rate limit docs**: The device API endpoints (`/va/*`) have no published rate limits. Monitor for `40007` errors in production.
3. **No WebSocket API for device communication**: The HTTP API requires polling. MQTT (ports 9501/9503/9504) would be the push-based alternative but requires native MQTT client.
4. **No API versioning**: No `/v2/` or version header mechanism for the `/va/*` endpoints. Breaking changes could come without notice.
5. **bemfa.com main site timed out**: `https://bemfa.com/` and `https://cloud.bemfa.com` homepage requests timed out (SPA requiring JS). The docs at `cloud.bemfa.com/docs/` were accessible.
