# provider/

## Purpose
Download & cache remote CSV.

## Files & Roles
| File         | Responsibility                | Key symbols |
|--------------|-------------------------------|-------------|
| fetch.zig    | HTTP GET                      | fetch       |

## Notes
* All network code must be behind a compile‑time feature flag so the library
  still builds for freestanding targets.
