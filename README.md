# Haru Analytics

A lightweight, self-hosted web analytics platform built with Elixir/Phoenix/LiveView.
Portfolio project demonstrating production-quality OTP patterns, real-time data with
PubSub, and a clean umbrella application structure.

## Features

- **Real-time dashboard** — Live visitor count, pageview chart (last 24h), top pages, referrers, countries
- **Multi-site support** — Each site gets an isolated API token
- **Async tracking** — The `/api/collect` endpoint responds in < 10ms via Task.Supervisor
- **ETS caching** — Aggregated stats cached per-site with 60s TTL
- **GDPR-friendly** — IP addresses are SHA-256 hashed before storage; raw IPs never persisted
- **Rate limiting** — Hammer 7.x (ETS backend) limits tracking to 100 req/min per IP
- **JS Snippet** — Minimal vanilla JS (< 2kb), `sendBeacon`-first with XHR fallback, SPA-aware

## Quick Start

```bash
# 1. Install deps
mix deps.get

# 2. Install JS assets
cd apps/haru_web/assets && npm install && cd ../../..

# 3. Set up the database (creates, migrates, seeds dev data)
mix ecto.setup

# 4. Start the server
mix phx.server
```

Open [http://localhost:4000](http://localhost:4000)

**Dev credentials:** `dev@haru.local` / `devsecret123456`

## Embedding the Tracking Snippet

```html
<script defer
  src="https://yourharu.com/js/haru.js"
  data-token="YOUR_SITE_API_TOKEN"
  data-api="https://yourharu.com">
</script>
```

## Manual Tracking (curl)

```bash
curl -X POST http://localhost:4000/api/collect \
  -H "Authorization: Bearer <site_api_token>" \
  -H "Content-Type: application/json" \
  -d '{"p":"/test","r":"https://google.com","sw":1920,"sh":1080}'
# Returns 200 in < 10ms
```

## Architecture

The project is an **Elixir Umbrella** with two apps:

| App | Responsibility |
|---|---|
| `haru_core` | Business logic, Ecto schemas, contexts, OTP supervision tree |
| `haru_web` | Phoenix HTTP layer, LiveView dashboard, routing |

### Supervision Tree

```
HaruCore.Application
├── HaruCore.Repo                          (DB connection pool)
├── Phoenix.PubSub [HaruCore.PubSub]       (cross-app messaging)
├── Registry [HaruCore.SiteRegistry]       (named process registry)
├── DynamicSupervisor [Sites.DynamicSupervisor]
│   ├── SiteServer(site_id=1)              (per-site GenServer)
│   └── SiteServer(site_id=2)
├── StatsCache                             (ETS, read_concurrency: true)
├── StatsRefresher                         (60s periodic flush)
└── Task.Supervisor [Tasks.Supervisor]     (async writes)

HaruWeb.Application
├── HaruWebWeb.Telemetry
├── RateLimiter                            (Hammer ETS backend)
└── HaruWebWeb.Endpoint
```

### Key Design Decisions

| Decision | Choice | Reason |
|---|---|---|
| ORM | Ecto + PostgreSQL | Minimal deps; TimescaleDB adds complexity |
| Async writes | `Task.Supervisor` fire-and-forget | Sub-10ms response on tracking endpoint |
| Cache | ETS `read_concurrency: true` | Concurrent reads without bottleneck |
| Rate limit | Hammer 7.x (ETS backend) | No Redis; single-node is fine |
| PII | SHA-256 `ip_hash` instead of raw IP | GDPR compliance, preserves unique visitor counting |
| PubSub owner | `HaruCore.Application` | Web layer stays stateless |

### Request Flow: Tracking Endpoint

```
POST /api/collect
  → TrackingRateLimit plug (Hammer ETS, 100 req/min/IP)
  → CollectController.create
      1. extract_token (Bearer header or ?t= param)
      2. Sites.get_site_by_token  → 401 if nil
      3. Sites.Supervisor.ensure_started(site_id)  → lazy SiteServer spawn
      4. SiteServer.record_event (GenServer cast, ~microseconds)
      5. Task.Supervisor.start_child → async:
           a. Analytics.create_event  (Ecto insert)
           b. StatsCache.invalidate(site_id)
           c. PubSub.broadcast "site:{id}", {:new_event, site_id}
      6. send_resp(conn, 200, "")  ← returns immediately
```

### Real-time Dashboard Flow

```
LiveView.mount
  → subscribe "site:#{site_id}"
  → Analytics.get_stats (ETS cache hit or DB compute + cache store)
  → push_event "update_chart" to Chart.js hook

LiveView.handle_info {:new_event, site_id}
  → Analytics.get_stats (cache invalidated → fresh query)
  → SiteServer.active_visitor_count (in-memory 5-min window)
  → push_event "update_chart"
```

## Tech Stack

| Layer | Technology |
|---|---|
| Language | Elixir 1.19+ / OTP 28 |
| Web Framework | Phoenix 1.8 + LiveView 1.1 |
| Database | PostgreSQL via Ecto 3.13 |
| Real-time | Phoenix PubSub |
| Caching | ETS (Erlang Term Storage) |
| Rate Limiting | Hammer 7.x (ETS backend) |
| Frontend | TailwindCSS + Chart.js |
| Linting | Credo |

## Running Tests

```bash
mix test
```

## Code Quality

```bash
mix credo --strict
mix check  # credo + warnings-as-errors
```
