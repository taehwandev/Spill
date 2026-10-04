"""Transcript cursor, exact identity and real CLI queue regressions."""

import builtins
import hashlib
import pathlib
from unittest import mock

from .fixtures import HookRegressionCase, MODEL, SESSION, TIMESTAMP, at, encoded, record


class TranscriptTailTests(HookRegressionCase):
    def assert_partial_resumes(self, raw, split):
        self.f.source.write_bytes(raw[:split])
        result = self.f.hook._read_transcript_turns(str(self.f.source), 0)
        self.assertEqual(len(result), 4)
        self.assertEqual(result, ([], 0, 0, 0))
        self.f.live()
        self.assertEqual(self.f.events, [])
        self.f.append(raw[split:] + b"\n")
        self.assertEqual(self.f.live(), self.f.hook._SCAN_IMPORTED)
        self.assertEqual(len(self.f.events), 1)
        self.assert_event(self.f.events[0])
        self.assertEqual(self.f.state()["byte_offset"], len(raw) + 1)
        self.assertEqual(self.f.state()["next_turn_index"], 1)
        self.f.live()
        self.assertEqual(len(self.f.events), 1)

    def test_partial_json_tail_resumes_without_loss(self):
        raw = encoded(record())
        self.assert_partial_resumes(raw, len(raw) - 9)

    def test_partial_utf8_tail_resumes_without_loss(self):
        value = record()
        value["\u00e9"] = 0  # synthetic numeric metadata exercises a split UTF-8 codepoint
        raw = encoded(value)
        self.assert_partial_resumes(raw, raw.index(b"\xc3") + 1)

    def test_partial_tail_after_valid_record_keeps_committed_cursor(self):
        first = encoded(record()) + b"\n"
        second = encoded(record(1))
        split = len(second) - 8
        self.f.source.write_bytes(first + second[:split])
        self.assertEqual(self.f.live(), self.f.hook._SCAN_IMPORTED)
        self.assertEqual(self.f.state()["byte_offset"], len(first))
        self.assertEqual(self.f.state()["next_turn_index"], 1)
        self.f.append(second[split:] + b"\n")
        self.f.live()
        self.assertEqual(len(self.f.events), 2)
        self.assert_event(self.f.events[1], 1)
        self.assertEqual(self.f.state()["next_turn_index"], 2)

    def test_history_partial_tail_resumes_without_loss(self):
        raw = encoded(record())
        self.f.source.write_bytes(raw[:-7])
        self.f.history()
        self.assertEqual(self.f.events, [])
        self.f.append(raw[-7:] + b"\n")
        self.assertEqual(self.f.history()["imported_events"], 1)
        self.assert_event(self.f.events[0])
        self.assertEqual(self.f.history()["imported_events"], 0)

    def test_complete_unterminated_json_is_consumed_once(self):
        self.f.write([record()], final_newline=False)
        self.assertEqual(self.f.live(), self.f.hook._SCAN_IMPORTED)
        self.assertEqual(self.f.state()["byte_offset"], self.f.source.stat().st_size)
        self.f.live()
        self.assertEqual(len(self.f.events), 1)
        self.f.append(b"\n" + encoded(record(1)) + b"\n")
        self.f.live()
        self.assertEqual(len(self.f.events), 2)
        self.assert_event(self.f.events[1], 1)

    def test_malformed_terminated_row_skips_then_valid_row_imports(self):
        self.f.source.write_bytes(b"{\n" + encoded(record()) + b"\n")
        self.assertEqual(self.f.live(), self.f.hook._SCAN_IMPORTED)
        self.assertEqual(len(self.f.events), 1)
        self.assert_event(self.f.events[0])
        self.assertEqual(self.f.state()["byte_offset"], self.f.source.stat().st_size)


class TranscriptIdentityTests(HookRegressionCase):
    def test_reader_keeps_four_fields_and_persistent_turn_indices(self):
        self.f.write([record(0, False), record(1, False)])
        turns, offset, start, next_index = self.f.hook._read_transcript_turns(str(self.f.source), 0, 37)
        self.assertEqual([turn["turn_index"] for turn in turns], [37, 38])
        self.assertEqual((offset, start, next_index), (self.f.source.stat().st_size, 0, 39))
        self.f.write([record(0, False)])
        self.f.live()
        self.f.append(encoded(record(1, False)) + b"\n")
        self.f.live()
        self.assertEqual(self.f.state()["next_turn_index"], 2)
        for index, (event, _) in enumerate(self.f.events):
            source = f"{SESSION}:{MODEL}::{index}:{TIMESTAMP}:18:17"
            self.assertEqual(event["span_id"], "span-" + hashlib.sha256(source.encode()).hexdigest()[:12])

    def test_unchanged_eof_does_not_open_transcript(self):
        self.f.write([record()])
        self.f.live()
        source_opens = []
        builtin_open = builtins.open
        path_open = pathlib.Path.open

        def open_file(path, *args, **kwargs):
            if pathlib.Path(path) == self.f.source:
                source_opens.append(1)
            return builtin_open(path, *args, **kwargs)

        def open_path(path, *args, **kwargs):
            if path == self.f.source:
                source_opens.append(1)
            return path_open(path, *args, **kwargs)

        with mock.patch.object(builtins, "open", open_file), mock.patch.object(pathlib.Path, "open", open_path):
            self.f.live()
            self.f.history()
        self.assertEqual(source_opens, [])
        self.assertEqual(len(self.f.events), 1)

    def test_request_id_duplicate_is_not_reemitted(self):
        self.f.write([record(), record()])
        self.f.live()
        self.assertEqual(len(self.f.events), 1)
        self.f.append(encoded(record(timestamp=at(26))) + b"\n" + encoded(record(1)) + b"\n")
        self.f.live()
        self.assertEqual(len(self.f.events), 2)
        self.assert_event(self.f.events[0])
        self.assert_event(self.f.events[1], 1)
        self.f.live()
        self.assertEqual(len(self.f.events), 2)

    def test_history_and_live_preserve_exact_events_and_accounting(self):
        self.f.write([record(), record(1)])
        self.assertEqual(self.f.history()["imported_events"], 2)
        for index, pair in enumerate(self.f.events):
            self.assert_event(pair, index)
        self.f.live()
        self.assertEqual(len(self.f.events), 2)


class QueueEmissionTests(HookRegressionCase):
    def test_real_cli_partial_record_enqueues_once_with_accounting(self):
        raw = encoded(record())
        self.f.source.write_bytes(raw[:-9])
        self.run_real_cli()
        self.assertEqual(self.queued_records(), [])
        self.f.append(raw[-9:] + b"\n")
        self.run_real_cli()
        rows = self.queued_records()
        self.assertEqual(len(rows), 1)
        suffix, event, account = rows[0]
        self.assertEqual(suffix, ".json")
        self.assert_event((event, account))
        self.assertEqual(len(list(self.f.hook.INBOX_DIR.iterdir())), 2)
        self.run_real_cli()
        self.assertEqual(self.queued_records(), rows)

    def test_real_cli_subagent_only_delta_enqueues_jsonl_once(self):
        self.f.write([record()])
        self.run_real_cli()
        main_rows = self.queued_records()
        self.assertEqual(len(main_rows), 1)
        self.assertEqual(main_rows[0][0], ".json")
        self.assert_event(main_rows[0][1:])
        child = self.f.source.with_suffix("") / "subagents" / "agent-000001.jsonl"
        self.f.write([record(1)], source=child)
        self.run_real_cli()
        rows = self.queued_records()
        self.assertEqual(len(rows), 2)
        child_rows = [row for row in rows if row[1]["run_id"] == "agent-000001"]
        self.assertEqual(len(child_rows), 1)
        self.assertEqual(child_rows[0][0], ".jsonl")
        self.assert_event(child_rows[0][1:], 1, run_id="agent-000001")
        self.assertEqual(tuple(sum(event[key] for _, event, _ in rows) for key in ("input_tokens", "output_tokens", "total_tokens")), (62, 34, 96))
        self.assertEqual(len(list(self.f.hook.INBOX_DIR.iterdir())), 4)
        self.run_real_cli()
        self.assertEqual(self.queued_records(), rows)
