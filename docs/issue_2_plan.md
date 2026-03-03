# Issue #2 — Implement Base Credit Application Domain (persistence + minimal API)

## Technical Objective

Establish the core domain model (`CreditApplication`) including the Ecto schema, migration, domain context, and minimal REST endpoints. This issue is the structural foundation for all subsequent layers.

Do NOT include yet: country-specific rules, provider integrations, async processing, webhooks, realtime updates, authentication, caching, Kubernetes, advanced observability.

## Implementation Checklist

### Migration

- [ ] Generate migration file `create_credit_applications`
- [ ] Set primary key as `binary_id`
- [ ] Add column `country` — `string`, not null
- [ ] Add column `full_name` — `string`, not null
- [ ] Add column `document_type` — `string`, not null (DNI / CPF / CURP / NIF / CC / CodiceFiscale)
- [ ] Add column `document_id` — `string`, not null
- [ ] Add column `requested_amount` — `decimal`, precision 15 scale 2, not null
- [ ] Add column `monthly_income` — `decimal`, precision 15 scale 2, not null
- [ ] Add column `status` — `string`, not null, default `"created"`
- [ ] Add column `provider_payload` — `map` (`:jsonb`), default `{}`
- [ ] Add `timestamps(type: :utc_datetime)`
- [ ] Add DB-level CHECK constraint on `status`: `status IN ('created', 'pending_review', 'approved', 'rejected')`
- [ ] Add index on `country`
- [ ] Add index on `status`
- [ ] Add composite index on `(country, status, inserted_at DESC)` — must use `execute/1` in migration with raw SQL since Ecto's `index/2` macro does not support per-column sort direction: `CREATE INDEX ... ON credit_applications (country, status, inserted_at DESC)`
- [ ] Add index on `inserted_at` — date range filters
- [ ] Add index on `document_id` — future per-document lookups
- [ ] Add unique index on `(document_id, country)` — prevents duplicate applications per person per country
- [ ] Run migration and verify table structure

### Ecto Schema

- [ ] Create module `Globaltask.CreditApplications.CreditApplication`
- [ ] Define `@valid_statuses ~w(created pending_review approved rejected)`
- [ ] Define `@valid_document_types ~w(DNI CPF CURP NIF CC CodiceFiscale)`
- [ ] Define schema fields matching the migration
- [ ] Set `status` default to `"created"` and `provider_payload` default to `%{}`
- [ ] Implement `changeset/2`:
  - [ ] `cast` all fields except `inserted_at` / `updated_at`
  - [ ] `validate_required` for `country`, `full_name`, `document_type`, `document_id`, `requested_amount`, `monthly_income`, `status`
  - [ ] `validate_number(:requested_amount, greater_than: 0)`
  - [ ] `validate_number(:monthly_income, greater_than: 0)`
  - [ ] `validate_inclusion(:status, @valid_statuses)`
  - [ ] `validate_inclusion(:document_type, @valid_document_types)`
  - [ ] `unique_constraint([:document_id, :country])` — maps DB error to changeset error

### Context

- [ ] Create module `Globaltask.CreditApplications`
- [ ] Implement `create_application(attrs)` — returns `{:ok, app}` or `{:error, changeset}`
- [ ] Implement `get_application(id)` — returns `{:ok, app}` or `{:error, :not_found}` (non-bang)
- [ ] Implement private `filter_by_country(query, filters)`
- [ ] Implement private `filter_by_status(query, filters)`
- [ ] Implement private `filter_by_date_range(query, filters)` — filters on `inserted_at` using `date_from` and `date_to`
- [ ] Implement `list_applications(filters \\ %{})`:
  - [ ] Parse `page` (default 1) and `page_size` (default 20, max capped at 100)
  - [ ] Apply filters via private functions
  - [ ] Order by `inserted_at DESC`
  - [ ] Execute count query for `total`
  - [ ] Execute data query with `limit` and `offset`
  - [ ] Return `%{data: [...], page: integer, page_size: integer, total: integer}`
- [ ] Implement `update_status(app, new_status)` — returns `{:ok, app}` or `{:error, changeset}`

### FallbackController

- [ ] Create `GlobaltaskWeb.FallbackController`
- [ ] Handle `{:error, :not_found}` — render 404 with body `%{errors: %{detail: "Not found"}}`
- [ ] Handle `{:error, %Ecto.Changeset{}}` — render 422 with body `%{errors: %{field => [messages]}}` — consistent format across all endpoints

### REST Controller

- [ ] Create `GlobaltaskWeb.CreditApplicationController`
- [ ] Declare `action_fallback GlobaltaskWeb.FallbackController`
- [ ] Implement `create/2` — calls `create_application/1`, renders 201 on success
- [ ] Implement `show/2` — calls `get_application/1`, renders 200 on success
- [ ] Implement `index/2`:
  - [ ] Parse and cast `page` and `page_size` from query string params (string to integer)
  - [ ] Pass all parsed params as filters to `list_applications/1`
  - [ ] Render paginated response including `meta`
- [ ] Implement `update_status/2` — fetches application, calls `update_status/2` on context, renders 200 on success

### JSON Serialization

- [ ] Create `GlobaltaskWeb.CreditApplicationJSON`
- [ ] Implement `index/1` — returns `%{data: [...], meta: %{page, page_size, total}}`
- [ ] Implement `show/1` — returns `%{data: data(app)}`
- [ ] Implement `data/1` — maps struct to plain map, includes all functional fields, excludes `__meta__`

### Router

- [ ] Add API scope in `router.ex` with `:api` pipeline
- [ ] Add `resources "/credit_applications", CreditApplicationController, only: [:create, :show, :index]`
- [ ] Add `patch "/credit_applications/:id/status", CreditApplicationController, :update_status`

### Context Unit Tests (`test/globaltask/credit_applications_test.exs`)

- [ ] `create_application/1` with valid attrs returns `{:ok, app}`
- [ ] `create_application/1` with missing required field returns `{:error, changeset}`
- [ ] `create_application/1` with `requested_amount <= 0` returns `{:error, changeset}`
- [ ] `create_application/1` with invalid `document_type` returns `{:error, changeset}`
- [ ] `create_application/1` with invalid `status` returns `{:error, changeset}`
- [ ] `create_application/1` with duplicate `document_id + country` returns `{:error, changeset}`
- [ ] `get_application/1` with valid id returns `{:ok, app}`
- [ ] `get_application/1` with unknown id returns `{:error, :not_found}`
- [ ] `list_applications/1` with `country` filter returns only matching records
- [ ] `list_applications/1` with `status` filter returns only matching records
- [ ] `list_applications/1` with `page` and `page_size` returns correct slice and `total`
- [ ] `list_applications/1` with `page_size` over 100 is capped at 100
- [ ] `update_status/2` with valid status returns `{:ok, updated_app}`
- [ ] `update_status/2` with invalid status returns `{:error, changeset}`

### Controller Integration Tests (`test/globaltask_web/controllers/credit_application_controller_test.exs`)

- [ ] `POST /api/credit_applications` with valid body returns `201` with JSON data
- [ ] `POST /api/credit_applications` with invalid body returns `422` with error details
- [ ] `POST /api/credit_applications` with duplicate `document_id + country` returns `422`
- [ ] `GET /api/credit_applications/:id` for existing record returns `200` with data
- [ ] `GET /api/credit_applications/:id` for unknown id returns `404`
- [ ] `GET /api/credit_applications?country=ES` returns filtered list with `meta` field
- [ ] `GET /api/credit_applications?page=2&page_size=5` returns correct page
- [ ] `PATCH /api/credit_applications/:id/status` with valid status returns `200`
- [ ] `PATCH /api/credit_applications/:id/status` with invalid status returns `422`

## Acceptance Criteria

- [ ] Application can be created via API
- [ ] Duplicate `document_id + country` returns `422` enforced at both changeset and DB constraint level
- [ ] Application can be retrieved by ID via tagged tuple with no exceptions in normal flow
- [ ] Applications can be listed with pagination bounded at 100 records and filters for `country`, `status`, and date range on `inserted_at`
- [ ] Status updates validated at changeset level and backed by a DB CHECK constraint
- [ ] `CreditApplicationJSON` handles all serialization, no raw Ecto structs in responses
- [ ] `FallbackController` handles all error cases uniformly across actions
- [ ] Context unit tests and controller integration tests pass
- [ ] No country-specific logic exists in the codebase

## Architectural Notes

**Indexes and scalability:** The composite index `(country, status, inserted_at DESC)` covers the most common paginated list query without multi-index merge. The unique index on `(document_id, country)` enforces data integrity at the DB level. At millions of records, the natural evolution is range partitioning on `inserted_at` or list partitioning on `country` — the current schema supports this transition without changes.

**`inserted_at` as the single temporal reference:** `inserted_at` is the canonical creation timestamp set by Ecto at insert time. No redundant timestamp field. Date range filters and ordering operate directly on `inserted_at`.

**Offset pagination tradeoff:** `OFFSET N` in PostgreSQL performs a full scan of the N skipped rows, which degrades significantly beyond ~100k records per filter partition. For this MVP, offset pagination bounded at 100 records per page is acceptable. The production evolution is keyset/cursor pagination over `(inserted_at, id)`, which scans only the requested page regardless of depth.

**GIN index on `provider_payload`:** Not created in this issue. To be added when the first query filtering inside the JSONB field is introduced.

## Explicitly Out of Scope

- Country-specific rules and document format validation
- Bank provider integrations
- Oban jobs and PostgreSQL triggers
- Webhooks
- JWT authentication
- Realtime updates and LiveView channels
- Tailwind and esbuild (deferred to frontend issue)
- GIN index on `provider_payload` (deferred until first JSONB query)
- Table partitioning (designed for, not implemented, to be documented in README)
- Caching, Kubernetes, advanced observability
