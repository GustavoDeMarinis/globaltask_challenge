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
│   ├── country_rules.ex # Country rules behaviour & dispatcher
│   ├── country_rules/   # Country-specific validation modules
│   │   ├── es.ex        # Spain (DNI)
│   │   ├── pt.ex        # Portugal (NIF)
│   │   ├── it.ex        # Italy (Codice Fiscale)
│   │   ├── mx.ex        # Mexico (CURP)
│   │   ├── co.ex        # Colombia (CC)
│   │   └── br.ex        # Brazil (CPF)
│   ├── credit_applications/  # Credit application context
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
| `PUT` | `/api/v1/credit_applications/:id` | Update application fields (not status/country) |
| `PATCH` | `/api/v1/credit_applications/:id/status` | Update application status |

**Query params for `GET /api/v1/credit_applications`:**
`country`, `status`, `date_from`, `date_to`, `page`, `page_size` (max 100)

## Running Tests

```bash
make test
```

Tests use `Ecto.Adapters.SQL.Sandbox` for isolated, concurrent database access. Oban runs in `:inline` mode during tests.

## Assumptions

- **No authentication yet** — all endpoints are public. JWT auth and role-based authorization are planned for a later issue.
- **Global state machine** — status transitions (`created → pending_review → approved/rejected`) are the same for all countries. Country-specific rules validate documents and enforce business thresholds but do not alter the transition graph.
- **Country dictates document type** — each country maps to exactly one required document type (e.g., ES → DNI, BR → CPF). The country field determines which validation rules apply.
- **Denormalized applicant data** — each application stores name, document type, and document number directly rather than referencing a normalized `applicants` table. This captures a snapshot of the applicant's data at application time.
- **No provider integration yet** — `provider_payload` exists in the schema but is populated manually. Bank provider integration is planned for a later issue.
- **Pagination uses count + data queries** — under very high concurrency, the total count and page data may be slightly inconsistent. Acceptable for MVP.

## Data Model

**Table:** `credit_applications`

| Column | Type | Constraints |
|---|---|---|
| `id` | `binary_id` (UUID v4) | PK, auto-generated |
| `country` | `country_code` ENUM | NOT NULL — `ES`, `PT`, `IT`, `MX`, `CO`, `BR` |
| `full_name` | `string` (max 255) | NOT NULL |
| `document_type` | `document_type` ENUM | NOT NULL — `DNI`, `CPF`, `CURP`, `NIF`, `CC`, `CodiceFiscale` |
| `document_number` | `string` (max 50) | NOT NULL |
| `requested_amount` | `decimal(15,2)` | NOT NULL, > 0 |
| `monthly_income` | `decimal(15,2)` | NOT NULL, > 0 |
| `application_date` | `date` | NOT NULL |
| `status` | `credit_application_status` ENUM | NOT NULL, default `created` — `created`, `pending_review`, `approved`, `rejected` |
| `provider_payload` | `jsonb` | Default `{}` |
| `lock_version` | `integer` | Default `0` (optimistic locking) |
| `inserted_at` | `utc_datetime` | Auto |
| `updated_at` | `utc_datetime` | Auto |

**Indexes:**

| Index | Columns | Notes |
|---|---|---|
| Composite | `(country, status, inserted_at DESC)` | Main query index |
| Partial unique | `(document_number, country)` WHERE `status != 'rejected'` | Prevents duplicate active applications |
| Single-column | `country`, `status`, `inserted_at`, `document_number` | Filter/lookup support |

**State transitions:**

```
created → pending_review → approved
    ↘                  ↘
     rejected          rejected
```

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

### Country-Specific Validation Rules

Country rules implement a **strategy pattern** using Elixir behaviours. Each country module lives in `lib/globaltask/country_rules/` and implements the `Globaltask.CountryRules` behaviour:

| Country | Document Type | Document Validation | Business Rule |
|---|---|---|---|
| 🇪🇸 ES | DNI | 8 digits + control letter (mod 23) | Amount > €50,000 → auto `pending_review` |
| 🇵🇹 PT | NIF | 9 digits + weighted check digit (mod 11) | Amount ≤ 4× monthly income |
| 🇮🇹 IT | CodiceFiscale | 16-char alphanumeric regex | Minimum income ≥ €800 |
| 🇲🇽 MX | CURP | 18-char format with gender marker | Amount ≤ 3× monthly income |
| 🇨🇴 CO | CC | 6–10 digits | Pass-through (deferred to Issue #4) |
| 🇧🇷 BR | CPF | 11 digits + two check digits (mod 11) | Amount ≤ 5× monthly income |

**Architecture:**

```
CountryRules (behaviour)           Country Modules
├── resolve/1  (dispatcher)   ──►  ES, PT, IT, MX, CO, BR
├── validate/1 (orchestrator)      Each implements:
│   ├── validate_document_type     ├── required_document_type/0
│   ├── module.validate_document   ├── validate_document/1
│   └── module.validate_business   ├── validate_business_rules/1
└── on_status_change/2 hook        └── on_status_change/2 (overridable)
```

**Adding a new country** requires only:

1. Create `lib/globaltask/country_rules/<code>.ex` implementing the behaviour
2. Add the mapping to `@country_modules` in `lib/globaltask/country_rules.ex`
3. Add the country code to the PostgreSQL `country_code` ENUM via migration
