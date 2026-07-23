# example_module state flow — plain English guide

Minimal reference flow for **tier-3 hot state** on Dart — not game logic.

## Event

Client sends `example/state` with `{message, record?}`. Dart bumps `revision` in `ExampleModuleStore` and returns the snapshot.

## Optional record

When `record: true`, Dart best-effort posts to FastAPI service tier for Postgres persistence.

## Related

- [EXAMPLE_MODULE.md](../../../../03_Base/EXAMPLE_MODULE.md)
- [DART_STATE_SYSTEM.md](../../../../03_Base/DART_STATE_SYSTEM.md)
