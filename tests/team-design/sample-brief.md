# Design Brief: Add Webhook Support to Existing REST API

## Project Description

We have a REST API (Node.js/Express + PostgreSQL) that manages project tasks for a SaaS platform. Clients currently poll the API for updates, which creates unnecessary load and delays. We need to add outgoing webhook support so clients can register callback URLs and receive real-time notifications when task events occur (created, updated, completed, deleted).

The webhook system must be reliable enough for production integrations -- clients will build automation workflows on top of it. Missed or duplicate notifications would break those workflows.

## Requirements

### Functional

1. **Webhook registration:** Clients can register webhook endpoints via REST API, specifying a callback URL and which events to subscribe to. Each client can register multiple endpoints.
2. **Event delivery:** When a subscribed event occurs, the system sends an HTTP POST to each registered callback URL with a JSON payload describing the event. Delivery must include a signature header (HMAC-SHA256) so receivers can verify authenticity.
3. **Retry with backoff:** Failed deliveries (non-2xx response or timeout) must be retried with exponential backoff. After exhausting retries, the webhook is marked as failing and the client is notified via email.
4. **Delivery log:** Every delivery attempt is logged with timestamp, response status, and latency. Clients can query their delivery history via API.

### Non-Functional

1. **Delivery latency:** Webhook payloads should be dispatched within 5 seconds of the triggering event under normal load (< 1000 events/minute).

## Decisions Already Made

1. **Use PostgreSQL for webhook storage.** We already run PostgreSQL and don't want to introduce a separate data store for webhook registrations and delivery logs.
2. **Use the existing Bull/Redis job queue for async delivery.** We already use Bull for background jobs (email sending, report generation). Webhook delivery jobs will use the same infrastructure.

## Open Questions

1. **Should we support webhook filtering beyond event type?** For example, filtering by project ID or task assignee. This adds complexity but reduces noise for clients with many projects.
2. **What is the maximum payload size?** We need to decide whether to send full task objects in the webhook payload or just IDs with a link to fetch details. Full objects are convenient but can be large for tasks with attachments.

## Codebase Context

### Key Files

- `src/routes/tasks.ts` — Express router for task CRUD endpoints. Events are emitted inline after database writes using a simple EventEmitter.
- `src/models/task.ts` — Sequelize model for the tasks table. Defines the schema and associations.
- `src/services/event-bus.ts` — Singleton EventEmitter instance used across the application. Currently used for logging and real-time WebSocket updates.
- `src/jobs/queue.ts` — Bull queue setup, shared Redis connection. Currently processes `email` and `report-generation` job types.
- `src/middleware/auth.ts` — JWT-based authentication middleware. Extracts `clientId` from the token.

### Existing Patterns

- Routes delegate to service modules (e.g., `src/services/task-service.ts`) which handle business logic and database access.
- Background jobs are defined in `src/jobs/processors/` with one file per job type. Each exports a processor function that Bull calls.
- The codebase uses TypeScript with strict mode. Models use Sequelize with typed definitions.
- Tests live in `tests/` mirroring the `src/` structure. Integration tests use a test database.

### Tech Stack

- Node.js 20, TypeScript 5.3, Express 4
- PostgreSQL 16, Sequelize 6
- Bull 4, Redis 7
- Jest for testing

## Constraints

- Two-person backend team, targeting 2-week implementation.
- Must not require downtime for deployment -- rolling deploy compatibility.
- Cannot introduce new infrastructure dependencies beyond what we already run.

## Success Criteria

- Webhook events are delivered within 5 seconds of the triggering action under normal load.
- Failed deliveries are retried without manual intervention.
- Clients can self-serve webhook management (register, list, delete, view delivery logs) entirely via API.
- Zero regressions in existing task API functionality.
