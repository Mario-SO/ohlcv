# parse/

## Purpose
Convert raw CSV bytes into typed `Row` structs as fast as possible.

## Files & Roles
| File            | Responsibility                          | Key symbols       |
|-----------------|-----------------------------------------|-------------------|
| `state.zig`     | Byte‑level DFA for CSV fields           | `State`, `Machine`|
| `entry.zig`     | Public API: `parseAll()` & iterator stub| `parseAll`        |
| `float_fast.zig`| SIMD fast‑path for f64 parsing          | `parseFloatFast`  |

## Notes
* The DFA never allocates; it mutates `Machine` in place.
* Keep `float_fast.zig` header‑only so callers can `@compileTime` choose f32/f64.