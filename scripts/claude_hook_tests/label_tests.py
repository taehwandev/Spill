"""Safe label window semantics and per-invocation snapshot reuse."""

from .fixtures import HookRegressionCase, TIMESTAMP, at, count_reads, encoded, label, record


class LabelTimelineTests(HookRegressionCase):
    def test_timeline_unsorted_overlap_ties_and_inclusive_expiry(self):
        self.f.timeline([
            label(at(20), at(30), "debugging", "implement"),
            label(at(0), at(40), "analysis", "classify"),
            label(at(20), at(32), "code_review", "verify"),
            label(at(10), at(35), "testing", "verify"),
        ])
        expected = {
            at(0): "analysis", at(10): "testing", at(20): "debugging",
            at(30): "debugging", at(30, 1): "code_review", at(32): "code_review",
            at(32, 1): "testing", at(35): "testing", at(35, 1): "analysis",
            at(40): "analysis",
        }
        for timestamp, task in expected.items():
            with self.subTest(timestamp=timestamp):
                self.assertEqual(self.f.hook._label_timeline_for_timestamp(timestamp)["task_type"], task)
        self.assertEqual(self.f.hook._label_timeline_for_timestamp(at(40, 1)), {})
        self.assertEqual(self.f.hook._label_timeline_for_timestamp("2025-12-31T23:59:59Z"), {})
        self.assertEqual(self.f.hook._label_timeline_for_timestamp("invalid"), {})

    def test_timeline_invalid_rows_are_ignored(self):
        self.f.timeline([
            [], None, 17,
            label(at(0), at(40), "analysis", "classify"),
            label(at(20), at(30), ai_tool="codex"),
            label(at(20), at(30), task="unsafe label", stage="unsafe stage"),
            label("invalid", at(30)), label(at(20), "invalid"),
            label(at(30), at(20)),
            label(at(20), at(30), task=17, stage=18, project_id=19),
        ])
        with self.f.hook.LABEL_TIMELINE_FILE.open("a") as stream:
            stream.write("{\n\n")
        self.assertEqual(self.f.hook._label_timeline_for_timestamp(TIMESTAMP), {
            "task_type": "analysis", "stage": "classify", "project_id": "project_global",
        })

    def test_timeline_partial_safe_labels_do_not_import_invalid_values(self):
        self.f.timeline([label(at(20), at(30), task="unsafe label", stage="verify", project_id="..")])
        self.f.write([record()])
        self.f.history()
        event, _ = self.f.events[0]
        self.assertEqual((event["task_type"], event["stage"], event["project_id"]), ("uncategorized", "verify", "project_global"))
        self.assert_event(self.f.events[0])

    def prepare_label_batch(self):
        self.f.timeline([label(at(0), at(40)) for _ in range(10)])
        self.f.write([record(index) for index in range(5)])

    def test_history_batch_loads_timeline_once(self):
        self.prepare_label_batch()
        with count_reads(self.f) as counts:
            self.assertEqual(self.f.history()["imported_events"], 5)
        self.assertEqual(counts["timeline_reads"], 1)
        self.assertEqual(len(self.f.events), 5)

    def test_live_batch_loads_timeline_once(self):
        self.prepare_label_batch()
        with count_reads(self.f) as counts:
            self.f.live()
        self.assertEqual(counts["timeline_reads"], 1)
        self.assertEqual(len(self.f.events), 5)

    def test_scan_batch_loads_timeline_once_across_sources(self):
        self.prepare_label_batch()
        other = self.f.root / "00000000-0000-4000-8000-000000000002.jsonl"
        self.f.write([record(index + 5) for index in range(5)], source=other)
        with count_reads(self.f) as counts:
            result = self.f.hook.scan_main(str(self.f.root), since_hours=None)
        self.assertEqual(result["imported_events"], 10)
        self.assertEqual(counts["timeline_reads"], 1)

    def test_live_and_subagents_share_one_label_snapshot(self):
        self.f.timeline([label(at(0), at(40))])
        self.f.write([record()])
        for directory, index in ((self.f.source.with_suffix(""), 1), (self.f.source.parent, 2)):
            child = directory / "subagents" / f"agent-{index:06d}.jsonl"
            self.f.write([record(index)], source=child)
        with count_reads(self.f) as counts:
            self.f.live(scan_subagents=True)
        self.assertEqual(len(self.f.events), 3)
        self.assertEqual(counts["timeline_reads"], 1)

    def test_new_invocation_refreshes_label_snapshot(self):
        self.prepare_label_batch()
        self.f.live()
        self.f.timeline([label(at(20), at(30), task="code_review", stage="verify")])
        self.f.append(encoded(record(5)) + b"\n")
        with count_reads(self.f) as counts:
            self.f.live()
        self.assertEqual(counts["timeline_reads"], 1)
        self.assertEqual(self.f.events[-1][0]["task_type"], "code_review")
