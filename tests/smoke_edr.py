"""
EDR server smoke tests — run against a live instance.
Usage: python tests/smoke_edr.py [base_url]
"""
import sys
import uuid
import requests

TIMEOUT = 10


def run(base: str) -> None:
    s = requests.Session()
    agent_id = str(uuid.uuid4())

    # ── Health ────────────────────────────────────────────────────────────
    r = s.get(f"{base}/health", timeout=TIMEOUT)
    assert r.status_code == 200, f"/health → {r.status_code}: {r.text}"
    d = r.json()
    assert d["status"] == "ok", f"status not ok: {d}"
    assert d["db_ok"] is True, f"db_ok not true: {d}"
    print("✓ GET /health")

    # ── Heartbeat (agent registration) ───────────────────────────────────
    r = s.post(f"{base}/api/v1/heartbeat", timeout=TIMEOUT, json={
        "agent_id": agent_id,
        "hostname": "ci-runner",
        "platform": "Linux",
        "agent_version": "1.0.0",
    })
    assert r.status_code == 200, f"/heartbeat → {r.status_code}: {r.text}"
    assert r.json()["acknowledged"] is True
    print("✓ POST /api/v1/heartbeat")

    # ── Single event ──────────────────────────────────────────────────────
    event_id = str(uuid.uuid4())
    r = s.post(f"{base}/api/v1/events", timeout=TIMEOUT, json={
        "event_id": event_id,
        "agent_id": agent_id,
        "hostname": "ci-runner",
        "platform": "Linux",
        "event_type": "heartbeat",
        "severity": "low",
        "timestamp": "2026-01-01T00:00:00Z",
        "source": "agent",
        "payload": {"agent_version": "1.0.0", "status": "online", "hostname": "ci-runner"},
        "tags": ["ci-smoke"],
    })
    assert r.status_code == 201, f"/events → {r.status_code}: {r.text}"
    assert r.json()["accepted"] is True
    assert r.json()["event_id"] == event_id
    print("✓ POST /api/v1/events")

    # ── Batch events ──────────────────────────────────────────────────────
    r = s.post(f"{base}/api/v1/events/batch", timeout=TIMEOUT, json={
        "events": [
            {
                "agent_id": agent_id, "hostname": "ci-runner", "platform": "Linux",
                "event_type": "scan", "severity": "low",
                "timestamp": "2026-01-01T00:00:00Z", "source": "agent",
                "payload": {"files_scanned": 10 * (i + 1), "detections": 0}, "tags": [],
            }
            for i in range(3)
        ]
    })
    assert r.status_code == 201, f"/events/batch → {r.status_code}: {r.text}"
    d = r.json()
    assert d["accepted"] == 3, f"expected 3 accepted: {d}"
    assert d["rejected"] == 0, f"expected 0 rejected: {d}"
    print("✓ POST /api/v1/events/batch")

    # ── List events ───────────────────────────────────────────────────────
    r = s.get(f"{base}/api/v1/events", timeout=TIMEOUT)
    assert r.status_code == 200, f"GET /events → {r.status_code}"
    events = r.json()
    assert len(events) >= 1, f"expected ≥1 events, got {len(events)}"
    print(f"✓ GET /api/v1/events  ({len(events)} events)")

    # ── Get event by ID ───────────────────────────────────────────────────
    r = s.get(f"{base}/api/v1/events/{event_id}", timeout=TIMEOUT)
    assert r.status_code == 200, f"GET /events/{{id}} → {r.status_code}"
    assert r.json()["event_id"] == event_id
    print("✓ GET /api/v1/events/{id}")

    # ── 404 on unknown event ──────────────────────────────────────────────
    r = s.get(f"{base}/api/v1/events/does-not-exist", timeout=TIMEOUT)
    assert r.status_code == 404, f"expected 404, got {r.status_code}"
    print("✓ GET /api/v1/events/nonexistent → 404")

    # ── List agents ───────────────────────────────────────────────────────
    r = s.get(f"{base}/api/v1/agents", timeout=TIMEOUT)
    assert r.status_code == 200
    agents = r.json()
    assert any(a["agent_id"] == agent_id for a in agents), "registered agent not found"
    print(f"✓ GET /api/v1/agents  ({len(agents)} agents)")

    # ── Get agent by ID ───────────────────────────────────────────────────
    r = s.get(f"{base}/api/v1/agents/{agent_id}", timeout=TIMEOUT)
    assert r.status_code == 200
    assert r.json()["agent_id"] == agent_id
    print("✓ GET /api/v1/agents/{id}")

    # ── Stats ─────────────────────────────────────────────────────────────
    r = s.get(f"{base}/api/v1/stats", timeout=TIMEOUT)
    assert r.status_code == 200
    d = r.json()
    for key in ("total_events", "total_agents", "events_24h", "vt_alerts"):
        assert key in d, f"missing key '{key}' in stats: {d}"
    assert d["total_events"] >= 4, f"expected ≥4 events in stats: {d}"
    assert d["total_agents"] >= 1, f"expected ≥1 agents in stats: {d}"
    print(f"✓ GET /api/v1/stats  {d}")

    # ── Dashboard HTML ────────────────────────────────────────────────────
    r = s.get(f"{base}/dashboard", timeout=TIMEOUT)
    assert r.status_code == 200, f"/dashboard → {r.status_code}"
    assert "text/html" in r.headers.get("content-type", ""), "not HTML"
    assert "MiniEDR Dashboard" in r.text
    print("✓ GET /dashboard")

    print("\n✅  All EDR smoke tests passed.")


if __name__ == "__main__":
    run(sys.argv[1] if len(sys.argv) > 1 else "http://localhost:8000")
