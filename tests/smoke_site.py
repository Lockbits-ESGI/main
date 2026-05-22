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

    # ── PHP app pages (under /client/) ────────────────────────────────────
    r = s.get(f"{base}/client/login.php", timeout=TIMEOUT)
    assert r.status_code == 200, f"GET /client/login.php → {r.status_code}"
    assert "text/html" in r.headers.get("content-type", ""), "/client/login.php not HTML"
    print("✓ GET /client/login.php")

    r = s.get(f"{base}/client/register.php", timeout=TIMEOUT)
    assert r.status_code == 200, f"GET /client/register.php → {r.status_code}"
    print("✓ GET /client/register.php")

    # ── Protected pages redirect to login when unauthenticated ───────────
    for path in ("/client/dashboard.php", "/client/tickets.php"):
        r = s.get(f"{base}{path}", timeout=TIMEOUT, allow_redirects=False)
        assert r.status_code in (200, 302), f"GET {path} → {r.status_code}"
        if r.status_code == 302:
            assert "login" in r.headers.get("location", "").lower(), \
                f"{path} redirect not to login: {r.headers.get('location')}"
        print(f"✓ GET {path}  (status: {r.status_code})")

    print("\n✅  All site smoke tests passed.")


if __name__ == "__main__":
    run(sys.argv[1] if len(sys.argv) > 1 else "http://localhost:8080")
