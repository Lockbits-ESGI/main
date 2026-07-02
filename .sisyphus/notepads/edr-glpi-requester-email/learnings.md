## 2026-05-30 — Email-based GLPI requester resolution

### Changes made
- **`shared/event_schema.py`**: Added `glpi_requester_email: str | None = None` field to `MiniEDREvent`
- **`agent/main.py`**: Reads `MINIEDR_GLPI_REQUESTER_EMAIL` env var in `__init__`, passes it to `create_event()`
- **`server/glpi_client.py`**:
  - Added `_user_email_cache` (dict) + `_user_email_cache_expires_at` (float) for 5-min TTL caching
  - Added `_resolve_requester_by_email(email)` — searches GLPI via `search/User` endpoint (field 9 = email, response field 1 = user ID)
  - Updated `_build_ticket_payload()` — prefers event's `glpi_requester_email`, falls back to `config.requester_id`
- **`.env.example`**: Added `# MINIEDR_GLPI_REQUESTER_EMAIL=client@societe.com` comment

### Key details
- Cache TTL: 300s (5 min)
- GLPI search API: `criteria[0][field]=9` (email), `criteria[0][searchtype]=equals`
- Response user ID is in field `"1"` of the first `data` entry
- Fallback chain: event email → config.requester_id → no requester set
- Branch: `fix/glpi-ticket-requester` (both edr and main)

### Notes
- Pyright complains about `str | None` syntax (pre-existing project-wide style, Python 3.10+)
- Compilation verified with `py_compile` — all clean
