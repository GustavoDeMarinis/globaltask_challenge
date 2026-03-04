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

## API Endpoints

All API endpoints are versioned under `/api/v1`.

| Method | Path | Description |
|---|---|---|
| `POST` | `/api/v1/credit_applications` | Create a credit application |
| `GET` | `/api/v1/credit_applications` | List applications (paginated, filterable) |
| `GET` | `/api/v1/credit_applications/:id` | Get a single application |
| `PATCH` | `/api/v1/credit_applications/:id/status` | Update application status |

**Query params for `GET /api/v1/credit_applications`:**
`country`, `status`, `date_from`, `date_to`, `page`, `page_size` (max 100)

## Running Tests

```bash
make test
```

Tests use `Ecto.Adapters.SQL.Sandbox` for isolated, concurrent database access. Oban runs in `:inline` mode during tests.

## Architecture & Design Notes

### `application_date` vs `inserted_at`

`application_date` is an explicit `:date` field representing when the applicant submitted their request. `inserted_at` tracks when the record was persisted in the database. These are kept separate because they can differ in scenarios like batch imports, manual entry, or timezone edge cases.

### Pagination Consistency

The `list_applications` endpoint runs two separate queries: one for `count` and one for `data`. Under very high concurrency, these may yield slightly inconsistent results (e.g., a record inserted between the two queries). This is acceptable for the current MVP. The production evolution is either a single-query approach using `count(*) OVER()` or keyset/cursor pagination.

### PostgreSQL ENUMs

`status`, `document_type`, and `country` use PostgreSQL ENUM types instead of CHECK constraints. ENUMs can be extended non-destructively with `ALTER TYPE ... ADD VALUE`, which means adding a new country or status requires a simple migration without altering existing constraints or data.

### Partial Unique Index

The unique constraint on `(document_number, country)` is partial: `WHERE status != 'rejected'`. This prevents duplicate *active* applications per person per country while allowing re-application after rejection — a standard fintech flow.

### Denormalized Application Data

Each credit application stores the applicant's document data (name, document type, document number) directly in the record rather than referencing a normalized `applicants` table. This is intentional: in fintech, each application should capture a snapshot of the applicant's data at the time of application. A normalized `applicants` entity is the natural evolution when authentication is introduced in a later issue.
