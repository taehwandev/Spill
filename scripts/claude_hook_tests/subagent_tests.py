"""Child transcript discovery and independent incremental progress."""

import os

from .fixtures import HookRegressionCase, record


class SubagentTests(HookRegressionCase):
    def assert_subagent_no_delta(self, session_layout):
        self.f.write([record()])
        self.f.live(scan_subagents=True)
        directory = self.f.source.with_suffix("") if session_layout else self.f.source.parent
        child = directory / "subagents" / "agent-000001.jsonl"
        self.f.write([record(1)], source=child)
        self.f.live(scan_subagents=True)
        self.assertEqual(len(self.f.events), 2)
        self.assertEqual(self.f.events[1][0]["run_id"], "agent-000001")
        self.f.live(scan_subagents=True)
        self.assertEqual(len(self.f.events), 2)

    def test_session_subagent_imports_when_main_has_no_delta(self):
        self.assert_subagent_no_delta(True)

    def test_legacy_subagent_imports_when_main_has_no_delta(self):
        self.assert_subagent_no_delta(False)

    def test_old_subagents_are_not_excluded_by_lookback(self):
        for directory, index in ((self.f.source.with_suffix(""), 1), (self.f.source.parent, 2)):
            child = directory / "subagents" / f"agent-{index:06d}.jsonl"
            self.f.write([record(index, timestamp="2020-01-01T00:00:00Z")], source=child)
            os.utime(child, (1, 1))
        self.f.write([record()])
        self.f.live(scan_subagents=True)
        self.assertEqual(len(self.f.events), 3)
        self.f.live(scan_subagents=True)
        self.assertEqual(len(self.f.events), 3)

    def test_scan_subagents_false_remains_supported(self):
        child = self.f.source.with_suffix("") / "subagents" / "agent-000001.jsonl"
        self.f.write([record(1)], source=child)
        self.f.write([record()])
        self.f.live(scan_subagents=False)
        self.assertEqual(len(self.f.events), 1)
