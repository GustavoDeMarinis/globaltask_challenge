# Issue #6 — Real-time Frontend & UI (Phoenix LiveView) (Challenge §3.10 & §5)

## Technical Objective

Implement the complete user interface natively within the Elixir ecosystem using Phoenix LiveView. The UI must provide real-time (WebSocket-driven) updates to the DOM when applications are processed asynchronously by the backend, eliminating the need for an external SPA (React/Vue).

Do NOT include yet: Complex user authentication (tables/sessions), Kubernetes manifests, or external charting libraries.

---

## Implementation Checklist

### 1. Backend PubSub Integration

- [ ] Ensure `Phoenix.PubSub` is running in `application.ex` (already configured as `Globaltask.PubSub`)
- [ ] Inject `PubSub.broadcast` into `Globaltask.CreditApplications.create_application/1` (`{:new_application, app}`)
- [ ] Inject `PubSub.broadcast` into `Globaltask.CreditApplications.update_provider_payload_and_enqueue_risk/2` (`{:application_updated, app}`) — **Intermediate step so the UI shows bank data instantly before Risk Eval finishes.**
- [ ] Inject `PubSub.broadcast` into `Globaltask.CreditApplications.update_status/2` (`{:application_updated, app}`)

### 2. LiveView Dashboard (List View — `GET /`)

- [ ] Create `GlobaltaskWeb.CreditApplicationLive.Index` module and HTML template
- [ ] Implement `mount/3`: Subscribe to the global `"credit_applications"` PubSub topic
- [ ] Implement `mount/3`: Fetch the initial list of applications (limit 50 for MVP UI)
- [ ] Implement `handle_info/2` for `{:new_application, app}`: Dynamically prepend the new row via LiveView streams using `limit: 50` parameter for `O(1)` memory protection on both Client DOM and Server ETS.
- [ ] Implement `handle_info/2` for `{:application_updated, app}`: Target the specific row payload to dynamically update the row's status pill.
- [ ] Add basic UI filters (country/status) via forms triggering `push_patch`. Update the `handle_info` broadcasts to **ignore locally** applications that don't match active filters instead of juggling complex dynamic PubSub topics.

### 3. LiveView Form (Creation — `GET /applications/new`)

- [ ] Create `GlobaltaskWeb.CreditApplicationLive.FormComponent`
- [ ] Implement a form matching the `CreditApplication` schema (Full Name, Document, Amount, etc.)
- [ ] Implement `phx-debounce="300"` on `<.input>` tags to avoid overwhelming WebSocket roundtrips on Regex-heavy validations (DNI, Codice Fiscale).
- [ ] Implement `handle_event("validate", ...)` for real-time form validation
- [ ] Implement `handle_event("save", ...)` to call the backend `CreditApplications.create_application/1`
- [ ] Redirect to the Dashboard or Show page upon successful creation

### 4. LiveView Details (Show View — `GET /applications/:id`)

- [ ] Create `GlobaltaskWeb.CreditApplicationLive.Show` module and HTML template
- [ ] Implement `mount/3`: Subscribe explicitly to `"credit_application:{id}"`
- [ ] Render all application details including the `provider_payload` JSON
- [ ] Implement `handle_info/2` for `{:application_updated, app}` to reactively update the screen when async workers dump data or approve/reject the application
- [ ] Provide "Approve" and "Reject" manual buttons for Admin workflows (fulfilling "Actualizar estado" §5)

### 5. UI Security (Admin Impersonation lifecycle)

- [ ] Add an endpoint/param (e.g. `GET /auth/impersonate?role=admin`) to set a signed session cookie.
- [ ] Implement `Phoenix.LiveView.on_mount/1` hook to read the role from the HTTP session boundary and assign it into `socket.assigns.current_role` during the WebSocket handshake.
- [ ] Hide the `provider_payload` block in `Show` if the current UI session is not Admin
- [ ] Disable/Hide the manual "Approve/Reject" buttons if not Admin

### 6. Styling

- [ ] Use Phoenix `core_components.ex` for forms, tables, buttons, and modals
- [ ] Style the status badges (e.g., `approved` = Green, `created` = Gray, `rejected` = Red) using Tailwind utility classes

### 7. Documentation

- [ ] Update `README.md` with UI Access Instructions
- [ ] Document the tradeoff choice of LiveView over React for this MVP

---

## Acceptance Criteria

- [ ] User can create a Credit Application through the Web UI.
- [ ] User can see a list of applications on the home page.
- [ ] User can click an application to view its detailed data.
- [ ] When a background worker evaluates risk and changes the application status, all connected browsers viewing that application or the list instantly reflect the new status without a manual refresh.
- [ ] Admin Users can manually override and transition application statuses from the `Show` view.
- [ ] Sensitive `provider_payload` data is hidden from the UI unless the user is operating via the Admin `on_mount` lifecycle.

---

## Architectural Notes

**Phoenix LiveView vs External SPA (React/Vue/Angular):** For an idiomatic Elixir MVP, separating the frontend into a different repository adds network latency, duplicative type definitions, CORS overhead, and complex deployment pipelines. Phoenix LiveView natively establishes WebSockets and leverages the Erlang VM to push minimal DOM diffs directly to the client. This fulfills the "Realtime" requirement natively and elegantly, signaling Senior-level mastery of the Elixir stack.

**Memory Protection via LiveView Streams:** To handle incoming webhook/PubSub payloads without crashing server memory, LiveView `streams` will be utilized on the Index page. Appending using `stream_insert(..., limit: 50)` keeps the server-side memory footprint and the Client's JS rendering effort strictly `O(1)` regardless of how many rows are broadcasted concurrently.

**Lifecycle WebSocket Boundaries (`on_mount`):** Security in Phoenix requires explicitly mapping standard Plug authorization boundaries into WebSocket lifecycle steps. Relying on simple routing pipelines is insecure once the WS handshake completes. Utilizing a `live_session` with an `on_mount` hook guarantees true identity delegation.

**esbuild via Elixir instead of Native JS Imports:** While it's possible to copy ES Modules and load them raw to maintain a strict "zero bundler" environment, doing so sacrifices the ability to cleanly import internal modules like `Phoenix` and `PhoenixLiveView` via bare module specifiers. It also exposes the application to network waterfalls and cache invalidation issues. Therefore, the official `esbuild` Elixir package was added. This preserves the "No Node.js / NPM" requirement, as it relies on a standalone Go binary to execute fast compilation.

---

## Explicitly Out of Scope

- Setting up NPM/Webpack/Vite or Tailwind compilations (using standalone Tailwind and Elixir's esbuild instead).
- Advanced infinite-scroll pagination on the UI (List is limited to Top 50 recent apps for MVP).
- True cryptographic User Sessions on the Web UI (using a simple HTTP cookie hook toggle instead).
- Granular Web UI charts or data visualization dashboards.
