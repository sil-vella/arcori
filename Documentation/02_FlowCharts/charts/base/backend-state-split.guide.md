# Backend state split — plain English guide

This chart shows **who owns what state** in the arcori backends.

## Dart = hot module state

Realtime updates for a module (see `example_module`) live in **Dart** in-memory stores. WS channel `example/state` returns the current snapshot to the caller.

## FastAPI = history and cache

Optional **durable** writes go to Postgres via `POST /service/example_module/record`. Reads can use Redis read-through cache.

## Flutter

The **example_module** screen shows tier-3 Riverpod state fed by `example/*` WS frames.

## More detail

- [EXAMPLE_MODULE.md](../../../03_Base/EXAMPLE_MODULE.md) — cross-stack reference
- [DART_STATE_SYSTEM.md](../../../03_Base/DART_STATE_SYSTEM.md)
- [PYTHON_STATE_SYSTEM.md](../../../03_Base/PYTHON_STATE_SYSTEM.md)
