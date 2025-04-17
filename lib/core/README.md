# core/

## Purpose
Domain data types and other pure, allocation‑free helpers that have **no dependency on I/O or CSV parsing logic**.  Code here should work on in‑memory values only so it can be reused by any higher‑level module.

## Files & Roles
| File        | Brief responsibility                                     | Key public symbols |
|-------------|----------------------------------------------------------|--------------------|
| `row.zig`   | Immutable structure representing one OHLCV full csv row. | `Row`              |
| `bar.zig`   | Immutable structure representing one OHLC bar.           | `Bar`              |


## Notes
* Keep this directory free of disk or network I/O; that lives in `io/` or `parse/`.
* Add numerical helpers (e.g. moving average, VWAP) here **only** when they operate purely on `Row` slices and require no allocator.

