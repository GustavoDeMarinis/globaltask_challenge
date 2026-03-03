# Issue #2 — Implement Base Credit Application Domain (persistence + minimal API)

## Technical Objective

Establish the core domain model (`CreditApplication`) including the Ecto schema, migration, domain context, and minimal REST endpoints. This issue is the structural foundation for all subsequent layers.

Do NOT include yet: country-specific rules, provider integrations, async processing, webhooks, realtime updates, authentication, caching, Kubernetes, advanced observability.

---

## Implementation Checklist

### 1. Migration

- [ ] Generate migration file `create_credit_applications`
- [ ] Create PostgreSQL ENUM type `credit_application_status` with values: `created`, `pending_review`, `approved`, `rejected`
- [ ] Create PostgreSQL ENUM type `document_type` with values: `DNI`, `CPF`, `CURP`, `NIF`, `CC`, `CodiceFiscale`
- [ ] Create PostgreSQL ENUM type `country_code` with values: `ES`, `PT`, `IT`, `MX`, `CO`, `BR`
- [ ] Set primary key as `binary_id`
- [ ] Add column `country` — `country_code` ENUM, not null
- [ ] Add column `full_name` — `string`, not null
- [ ] Add column `document_type` — `document_type` ENUM, not null
- [ ] Add column `document_id` — `string`, not null
- [ ] Add column `requested_amount` — `decimal`, precision 15 scale 2, not null
- [ ] Add column `monthly_income` — `decimal`, precision 15 scale 2, not null
- [ ] Add column `application_date` — `date`, not null
- [ ] Add column `status` — `credit_application_status` ENUM, not null, default `"created"`
- [ ] Add column `provider_payload` — `map` (`:jsonb`), default `{}`
- [ ] Add `timestamps(type: :utc_datetime)`
- [ ] Add index on `country`
- [ ] Add index on `status`
- [ ] Add composite index on `(country, status, inserted_at DESC)` — use `execute/1` with raw SQL since Ecto does not support per-column sort direction
- [ ] Add index on `inserted_at` — date range filters
- [ ] Add index on `document_id` — future per-document lookups
- [ ] Add partial unique index on `(document_id, country)` where `status NOT IN ('rejected')` — prevents duplicate active applications per person per country, but allows re-application after rejection
- [ ] Run migration and verify table structure

### 2. Ecto Schema

- [ ] Create module `Globaltask.CreditApplications.CreditApplication`
- [ ] Define `@valid_statuses ~w(created pending_review approved rejected)`
- [ ] Define `@valid_countries ~w(ES PT IT MX CO BR)`
- [ ] Define `@valid_document_types ~w(DNI CPF CURP NIF CC CodiceFiscale)`
- [ ] Define valid state transitions map:
  ```elixir
  @valid_transitions %{
    "created" => ~w(pending_review rejected),
    "pending_review" => ~w(approved rejected),
    "approved" => [],
    "rejected" => []
  }
  ```
- [ ] Define schema fields matching the migration (use `:string` for ENUM columns — Ecto maps PG ENUMs to strings)
- [ ] Set `status` default to `"created"` and `provider_payload` default to `%{}`
- [ ] Implement `create_changeset/2`:
  - [ ] `cast` fields: `country`, `full_name`, `document_type`, `document_id`, `requested_amount`, `monthly_income`, `application_date`, `provider_payload`
  - [ ] Do NOT cast `status` — it defaults to `"created"` and must not be settable by the caller
  - [ ] `validate_required` for: `country`, `full_name`, `document_type`, `document_id`, `requested_amount`, `monthly_income`, `application_date`
  - [ ] `validate_number(:requested_amount, greater_than: 0)`
  - [ ] `validate_number(:monthly_income, greater_than: 0)`
  - [ ] `validate_inclusion(:country, @valid_countries)`
  - [ ] `validate_inclusion(:document_type, @valid_document_types)`
  - [ ] `unique_constraint([:document_id, :country], name: :credit_applications_document_id_country_active_index)` — maps partial unique index to changeset error
- [ ] Implement `update_status_changeset/2`:
  - [ ] `cast` only `status`
  - [ ] `validate_required([:status])`
  - [ ] `validate_inclusion(:status, @valid_statuses)`
  - [ ] Custom validation: check that the transition from `app.status` → `new_status` is in `@valid_transitions`

### 3. Context (`Globaltask.CreditApplications`)

- [ ] Create module `Globaltask.CreditApplications`
- [ ] Implement `create_application(attrs)`:
  - [ ] Build changeset via `CreditApplication.create_changeset(%CreditApplication{}, attrs)`
  - [ ] `Repo.insert(changeset)`
  - [ ] Returns `{:ok, app}` or `{:error, changeset}`
- [ ] Implement `get_application(id)`:
  - [ ] Guard: validate `id` is a valid UUID format, return `{:error, :not_found}` if not
  - [ ] `Repo.get(CreditApplication, id)`
  - [ ] Return `{:ok, app}` or `{:error, :not_found}`
- [ ] Implement private `filter_by_country(query, filters)` — no-op if key absent
- [ ] Implement private `filter_by_status(query, filters)` — no-op if key absent
- [ ] Implement private `filter_by_date_range(query, filters)` — filters on `inserted_at` using `date_from` / `date_to`, no-op if keys absent
- [ ] Implement `list_applications(filters \\ %{})`:
  - [ ] Parse `page` (default 1) and `page_size` (default 20, max capped at 100)
  - [ ] Apply filters via private functions
  - [ ] Order by `inserted_at DESC`
  - [ ] Execute count query for `total`
  - [ ] Execute data query with `limit` and `offset`
  - [ ] Return `%{data: [...], page: integer, page_size: integer, total: integer}`
  - [ ] Note: count and data are two separate queries — under very high concurrency they may be slightly inconsistent. Acceptable for MVP; document in README
- [ ] Implement `update_status(app, new_status)`:
  - [ ] Build changeset via `CreditApplication.update_status_changeset(app, %{status: new_status})`
  - [ ] `Repo.update(changeset)`
  - [ ] Returns `{:ok, updated_app}` or `{:error, changeset}`

### 4. FallbackController

- [ ] Create `GlobaltaskWeb.FallbackController`
- [ ] Handle `{:error, :not_found}` — render 404 with body `%{errors: %{detail: "Not found"}}`
- [ ] Handle `{:error, %Ecto.Changeset{}}` — render 422 with body `%{errors: %{field => [messages]}}`

### 5. REST Controller (`GlobaltaskWeb.API.V1.CreditApplicationController`)

- [ ] Create `GlobaltaskWeb.API.V1.CreditApplicationController`
- [ ] Declare `action_fallback GlobaltaskWeb.FallbackController`
- [ ] Implement `create/2`:
  - [ ] Call `CreditApplications.create_application(params)`
  - [ ] Render 201 on success
- [ ] Implement `show/2`:
  - [ ] Call `CreditApplications.get_application(id)`
  - [ ] Render 200 on success
- [ ] Implement `index/2`:
  - [ ] Parse and cast `page`, `page_size`, `country`, `status`, `date_from`, `date_to` from query string
  - [ ] Pass as filters to `CreditApplications.list_applications/1`
  - [ ] Render paginated response with `meta`
- [ ] Implement `update_status/2`:
  - [ ] Call `CreditApplications.get_application(id)` to fetch the application
  - [ ] Call `CreditApplications.update_status(app, params["status"])` on success
  - [ ] Render 200 on success

### 6. JSON Serialization (`GlobaltaskWeb.API.V1.CreditApplicationJSON`)

- [ ] Create `GlobaltaskWeb.API.V1.CreditApplicationJSON`
- [ ] Implement `index/1` — returns `%{data: [...], meta: %{page, page_size, total}}`
- [ ] Implement `show/1` — returns `%{data: data(app)}`
- [ ] Implement `data/1`:
  - [ ] Map struct to plain map with: `id`, `country`, `full_name`, `document_type`, `document_id`, `requested_amount`, `monthly_income`, `application_date`, `status`, `inserted_at`, `updated_at`
  - [ ] **Exclude** `provider_payload` — contains potentially sensitive bank data (§4.2). Sanitized subset to be exposed in a future issue when needed

### 7. Router

- [ ] Add versioned API scope in `router.ex`:
  ```elixir
  scope "/api/v1", GlobaltaskWeb.API.V1 do
    pipe_through :api
    resources "/credit_applications", CreditApplicationController, only: [:create, :show, :index]
    patch "/credit_applications/:id/status", CreditApplicationController, :update_status
  end
  ```

### 8. Context Unit Tests (`test/globaltask/credit_applications_test.exs`)

- [ ] `create_application/1` with valid attrs returns `{:ok, app}` with status `"created"`
- [ ] `create_application/1` with missing required field returns `{:error, changeset}`
- [ ] `create_application/1` with `requested_amount <= 0` returns `{:error, changeset}`
- [ ] `create_application/1` with invalid `document_type` returns `{:error, changeset}`
- [ ] `create_application/1` with invalid `country` returns `{:error, changeset}`
- [ ] `create_application/1` ignores caller-supplied `status` (always defaults to `"created"`)
- [ ] `create_application/1` with duplicate active `document_id + country` returns `{:error, changeset}`
- [ ] `create_application/1` with duplicate `document_id + country` where prior is `rejected` succeeds
- [ ] `get_application/1` with valid id returns `{:ok, app}`
- [ ] `get_application/1` with unknown id returns `{:error, :not_found}`
- [ ] `get_application/1` with invalid UUID format returns `{:error, :not_found}`
- [ ] `list_applications/1` with no filters returns all records with pagination metadata
- [ ] `list_applications/1` with `country` filter returns only matching records
- [ ] `list_applications/1` with `status` filter returns only matching records
- [ ] `list_applications/1` with `date_from` and `date_to` returns only matching records
- [ ] `list_applications/1` with `page` and `page_size` returns correct slice and `total`
- [ ] `list_applications/1` with `page_size` over 100 is capped at 100
- [ ] `update_status/2` with valid transition (`created → pending_review`) returns `{:ok, updated_app}`
- [ ] `update_status/2` with invalid transition (`approved → created`) returns `{:error, changeset}`
- [ ] `update_status/2` with invalid status value returns `{:error, changeset}`

### 9. Controller Integration Tests (`test/globaltask_web/controllers/api/v1/credit_application_controller_test.exs`)

- [ ] `POST /api/v1/credit_applications` with valid body returns `201` with JSON data
- [ ] `POST /api/v1/credit_applications` with invalid body returns `422` with error details
- [ ] `POST /api/v1/credit_applications` with caller-supplied status is ignored
- [ ] `POST /api/v1/credit_applications` with duplicate active `document_id + country` returns `422`
- [ ] `GET /api/v1/credit_applications/:id` for existing record returns `200` with data
- [ ] `GET /api/v1/credit_applications/:id` for unknown id returns `404`
- [ ] `GET /api/v1/credit_applications` with no filters returns list with `meta`
- [ ] `GET /api/v1/credit_applications?country=ES` returns filtered list
- [ ] `GET /api/v1/credit_applications?page=2&page_size=5` returns correct page
- [ ] `PATCH /api/v1/credit_applications/:id/status` with valid transition returns `200`
- [ ] `PATCH /api/v1/credit_applications/:id/status` with invalid transition returns `422`
- [ ] Response body never contains `provider_payload` key

### 10. README Notes

- [ ] Add note: `application_date` is an explicit date field representing when the applicant submitted their request, distinct from `inserted_at` which tracks DB persistence time
- [ ] Add note: pagination count/data queries are separate and may be slightly inconsistent under high concurrency — acceptable for MVP, keyset pagination is the production evolution

---

## Acceptance Criteria

- [ ] Application can be created via API at `/api/v1/credit_applications`
- [ ] Status defaults to `"created"` — cannot be set by the caller
- [ ] State transitions validated: only valid transitions are allowed
- [ ] Duplicate active `document_id + country` returns `422` — but re-application after `rejected` is allowed
- [ ] Application can be retrieved by ID; invalid UUIDs return `404` without exceptions
- [ ] Applications can be listed with pagination (max 100), filters: `country`, `status`, `date_from`, `date_to`
- [ ] `provider_payload` is excluded from all JSON responses
- [ ] `FallbackController` handles all error cases uniformly
- [ ] PostgreSQL ENUM types used for `status` and `document_type` (extensible via `ALTER TYPE ... ADD VALUE`)
- [ ] Country validated against `~w(ES PT IT MX CO BR)`
- [ ] Context unit tests and controller integration tests pass
- [ ] No country-specific business logic exists in the codebase

---

## Architectural Notes

**PostgreSQL ENUM vs CHECK constraint:** ENUM types are used for `status`, `document_type`, and `country`. Unlike CHECK constraints, ENUMs can be extended with `ALTER TYPE ... ADD VALUE` without recreating the constraint — a non-destructive migration. This supports §3.4 and §4.1: adding new states or countries without disruptive changes.

**Separate changesets per operation:** `create_changeset` casts domain fields but not `status` (it defaults to `"created"`). `update_status_changeset` casts only `status` and validates state transitions. This prevents a caller from modifying `full_name` via the status endpoint or setting `"approved"` on creation.

**Partial unique index:** `(document_id, country) WHERE status != 'rejected'` prevents concurrent active applications for the same person in the same country while allowing re-application after rejection — a standard fintech flow.

**Indexes and scalability:** The composite index `(country, status, inserted_at DESC)` covers the most common paginated list query. At millions of records, the natural evolution is range partitioning on `inserted_at` or list partitioning on `country` — the current schema supports this without changes.

**Offset pagination tradeoff:** `OFFSET N` degrades beyond ~100k records per filter partition. Bounded at 100 per page for MVP. Production evolution: keyset/cursor pagination over `(inserted_at, id)`.

**Count/data consistency:** The two separate queries for count and data may yield slightly inconsistent results under high concurrency. Acceptable for MVP. A single-query approach using `count(*) OVER()` would solve this but adds complexity to Ecto query composition.

**`provider_payload` excluded from serialization:** Raw bank provider data is stored in `provider_payload` (JSONB) but excluded from API responses per §4.2 (avoid exposing sensitive bank data). A sanitized subset will be exposed in a future issue when needed.

---

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
- Sanitized `provider_payload` in API responses (deferred)
