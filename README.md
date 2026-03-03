# Globaltask — Multi-Country Credit Application Platform

A fintech MVP for processing credit applications across multiple Latin American and European countries, built with Elixir/Phoenix.

## Tech Stack

- **Backend:** Elixir 1.16.1 / Phoenix 1.8 / Ecto
- **Database:** PostgreSQL 16
- **Background Jobs:** Oban (with Pruner, Lifeline, Stager plugins)
- **Cache:** Cachex (configured in later issues)
- **Logging:** logger_json (configured in later issues)
- **Container:** Docker / Docker Compose

## Prerequisites

- Elixir 1.16.1 / Erlang/OTP 26 (see `.tool-versions` for exact versions — use `asdf` or `mise` to install)
- Docker & Docker Compose
- Make

## Quick Start

> **Important:** All commands must be run through the `Makefile`, which loads environment variables from `.env`. Running `mix phx.server` directly without sourcing `.env` will work in dev (defaults are set), but using `make run` is the recommended workflow.

```bash
# 1. Copy and configure environment variables
cp .env.example .env
# Edit .env if you need to change defaults

# 2. Setup everything (starts Docker, installs deps, creates/migrates DB)
make setup

# 3. Start the server
make run

# 4. Visit http://localhost:4000
```

## Available Make Targets

| Command | Description |
|---|---|
| `make setup` | Start Docker services, wait for DB, install deps, create and migrate DB |
| `make run` | Start Phoenix dev server |
| `make test` | Run test suite |
| `make migrate` | Run pending Ecto migrations |
| `make reset` | Drop and recreate database |
| `make lint` | Run formatter + Credo static analysis |
| `make dialyzer` | Run Dialyzer type checking |
| `make down` | Stop Docker services |
| `make check-env` | Validate `.env` exists and is not tracked by Git |

## Environment Variables

See `.env.example` for the full list. Key variables:

| Variable | Description | Default |
|---|---|---|
| `POSTGRES_USER` | PostgreSQL username | `globaltask` |
| `POSTGRES_PASSWORD` | PostgreSQL password | `globaltask` |
| `POSTGRES_HOST` | PostgreSQL host | `localhost` |
| `POSTGRES_DB` | Database name | `globaltask_dev` |
| `DB_POOL_SIZE` | DB connection pool size | `10` |
| `SECRET_KEY_BASE` | Phoenix secret key | — (generate with `mix phx.gen.secret`) |
| `PHX_HOST` | Public hostname | `localhost` |
| `PORT` | HTTP port | `4000` |

## Project Structure

```
lib/
├── globaltask/          # Domain layer (contexts, schemas, business logic)
│   ├── application.ex   # OTP supervision tree
│   └── repo.ex          # Ecto repository
└── globaltask_web/      # Web layer (controllers, views, channels)
    ├── controllers/     # HTTP request handlers
    ├── components/      # Phoenix components
    ├── endpoint.ex      # HTTP endpoint
    ├── router.ex        # Route definitions
    └── telemetry.ex     # Metrics and instrumentation
```

## Docker

- **Dev profile** (`docker compose --profile dev`): PostgreSQL only
- **Full profile** (`docker compose --profile full`): PostgreSQL + Phoenix app (requires Dockerfile build)

## Running Tests

```bash
make test
```

Tests use `Ecto.Adapters.SQL.Sandbox` for isolated, concurrent database access. Oban runs in `:inline` mode during tests.
