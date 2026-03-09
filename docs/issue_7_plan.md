# Issue #7 — Bonus: Detailed Audit Trail (Challenge §6.4)

## Technical Objective

Implement a robust, append-only **Audit Trail** for credit application state transitions to satisfy the "Auditoría detallada de cambios" optional requirement of the challenge. This will demonstrate advanced data modeling, proper use of `Ecto.Multi` for guaranteed transactional consistency, and frontend state history visualization.

Concurrently, this issue will formally document the strategic decisions around the remaining optional points (Metrics and Resilience).

---

## The Value Proposition (Why Audit Logs?)
In Fintech, data mutation without historical tracking is dangerous. If an application goes from `rejected` to `approved`, compliance officers must know *when* and *who* changed it. An append-only audit log solves this inherently.

## Implementation Checklist

### 1. Database & Schema
- [ ] Create migration for table `credit_application_audit_logs`.
  - Fields: `credit_application_id` (foreign key), `old_status` (string), `new_status` (string), `actor` (string: "system", "admin_override", "provider_webhook").
- [ ] Create `Globaltask.CreditApplications.AuditLog` Ecto Schema.

### 2. Context Logic (`Ecto.Multi` Refactoring)
- [ ] Modify `Globaltask.CreditApplications.update_status/3` to accept an `actor` parameter.
- [ ] Refactor `update_status` to use an `Ecto.Multi` transaction:
  1. `Multi.update` to change the `status` on the `CreditApplication`.
  2. `Multi.insert` to create the `AuditLog` record linking `old_status` to `new_status`.
- [ ] Update `RiskEvaluationWorker` and `Show` LiveView to pass the correct `actor` string when transitioning states.

### 3. Frontend Visualization (Show View)
- [ ] Preload the audit logs when fetching the application in the Show view.
- [ ] Render a "Timeline / Audit Trail" section in the UI (only visible to Admins) showing who changed the application and when.

### 4. Documentation & Other Options
- [ ] Update `README.md` to document the Audit Trail implementation.
- [ ] Update `README.md` to document why **Metrics & Dashboards** were solved via `Phoenix LiveDashboard` natively.
- [ ] Update `README.md` to document why **Advanced Resilience** is already partially covered by `Oban` exponentially backing off background fetch failures.

---

## Out of Scope
- Prometheus/Grafana external metrics (too infrastructure-heavy for the MVP; Phoenix LiveDashboard is sufficient).
- Complex Erlang Circuit Breakers (Oban retries cover the requirement cleanly).
