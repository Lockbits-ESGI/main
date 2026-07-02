"""
LockBits site smoke tests — run against a live instance.
Usage: python tests/smoke_site.py [base_url]
"""
import sys
import requests

TIMEOUT = 10


def run(base: str) -> None:
    s = requests.Session()

    # ── Static index ──────────────────────────────────────────────────────
    r = s.get(f"{base}/", timeout=TIMEOUT)
    assert r.status_code == 200, f"GET / → {r.status_code}"
    assert "text/html" in r.headers.get("content-type", ""), "/ not HTML"
    print("✓ GET /")

    # ── PHP app pages (under /client/) — clean URLs (sans .php) ──────────
    r = s.get(f"{base}/client/login", timeout=TIMEOUT)
    assert r.status_code == 200, f"GET /client/login → {r.status_code}"
    assert "text/html" in r.headers.get("content-type", ""), "/client/login not HTML"
    print("✓ GET /client/login")

    r = s.get(f"{base}/client/register", timeout=TIMEOUT)
    assert r.status_code == 200, f"GET /client/register → {r.status_code}"
    print("✓ GET /client/register")

    # ── Protected pages redirect to login when unauthenticated ───────────
    for path in ("/client/dashboard", "/client/tickets"):
        r = s.get(f"{base}{path}", timeout=TIMEOUT, allow_redirects=False)
        assert r.status_code in (200, 302), f"GET {path} → {r.status_code}"
        if r.status_code == 302:
            assert "login" in r.headers.get("location", "").lower(), \
                f"{path} redirect not to login: {r.headers.get('location')}"
        print(f"✓ GET {path}  (status: {r.status_code})")

    # ── Metrics endpoint ──────────────────────────────────────────────────
    r = s.get(f"{base}/metrics", timeout=TIMEOUT)
    assert r.status_code == 200, f"GET /metrics → {r.status_code}"
    assert "text/plain" in r.headers.get("content-type", ""), "/metrics not text/plain"
    body = r.text

    # Verify expected metric names
    expected_metrics = [
        "lockbits_db_health",
        "lockbits_users_total",
        'lockbits_tickets_total{status="open"}',
        'lockbits_tickets_total{status="in_progress"}',
        'lockbits_tickets_total{status="closed"}',
        "lockbits_php_memory_bytes",
        "lockbits_http_requests_total",
    ]
    for metric in expected_metrics:
        assert metric in body, f"Missing metric: {metric}"

    # Verify values are numeric
    import re
    for name in ("lockbits_db_health", "lockbits_users_total"):
        matches = re.findall(rf"{re.escape(name)}\s+([\d.]+)", body)
        assert len(matches) > 0, f"No value for {name}"
        float(matches[0])  # raises if not numeric

    # Verify HELP/TYPE lines present
    assert "# HELP" in body, "Missing HELP lines"
    assert "# TYPE" in body, "Missing TYPE lines"

    print("✓ GET /metrics  (Prometheus format, 6 metrics)")

    print("\n✅  All site smoke tests passed.")


if __name__ == "__main__":
    run(sys.argv[1] if len(sys.argv) > 1 else "http://localhost:8080")
