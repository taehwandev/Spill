"""Optional paired local processing measurements, with exact output comparison."""

import datetime
import hashlib
import json
import math
import statistics
import time

from .fixtures import Fixture, count_reads, label, record


def benchmark_sample(adapter, events=200, labels=1000):
    fixture = Fixture(adapter)
    try:
        origin = datetime.datetime(2020, 1, 1, tzinfo=datetime.timezone.utc)
        fixture.timeline([
            label((origin + datetime.timedelta(seconds=index)).isoformat(), "2030-01-01T00:00:00Z")
            for index in range(labels)
        ])
        fixture.write([record(index) for index in range(events)])
        with count_reads(fixture) as counts:
            started = time.perf_counter()
            result = fixture.history()
            elapsed_ms = (time.perf_counter() - started) * 1000
        if result["imported_events"] != events or len(fixture.events) != events:
            raise AssertionError("Benchmark fixture did not emit every exact synthetic event")
        digest = hashlib.sha256(json.dumps(fixture.events, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
        return {"elapsed_ms": elapsed_ms, **counts, "event_digest": digest}
    finally:
        fixture.close()


def benchmark(adapters, repeats):
    samples = {name: [] for name, _ in adapters}
    for index in range(repeats):
        # Alternate order to reduce the chance that warming always favors one side.
        ordered = adapters if index % 2 == 0 else list(reversed(adapters))
        for name, adapter in ordered:
            samples[name].append(benchmark_sample(adapter))
    digests = {sample["event_digest"] for rows in samples.values() for sample in rows}
    if len(digests) != 1:
        raise AssertionError("Paired adapters changed event/accounting outputs")
    summary = {"events_per_batch": 200, "label_rows": 1000, "paired_repeats": repeats, "measurement": "local_instrumented_elapsed_ms", "adapters": {}}
    for name, rows in samples.items():
        values = sorted(row["elapsed_ms"] for row in rows)
        summary["adapters"][name] = {
            "median_ms": round(statistics.median(values), 3),
            "p95_ms": round(values[math.ceil(len(values) * .95) - 1], 3),
            "timeline_reads_per_batch": sorted({row["timeline_reads"] for row in rows}),
            "json_loads_per_batch": sorted({row["json_loads"] for row in rows}),
        }
    print(json.dumps(summary, sort_keys=True))
